#!/usr/bin/env bash
# setup-protection.sh — GitHub Branch Protection + Environment 보호 규칙 설정
# 필요: gh CLI 로그인 완료 (gh auth login)
# 사용법: bash scripts/setup-protection.sh <app-repo> <manifest-repo> <approver-github-id>
# 예시:   bash scripts/setup-protection.sh my-id/gitops-app my-id/gitops-manifest approver-user
set -euo pipefail

APP_REPO="${1:?사용법: $0 <app-repo> <manifest-repo> <approver-id>}"
MANIFEST_REPO="${2:?}"
centerkimdudu="${3:?}"

echo ""
echo "========================================"
echo "  GitHub 보호 규칙 설정 스크립트"
echo "========================================"
echo "  App repo:      ${APP_REPO}"
echo "  Manifest repo: ${MANIFEST_REPO}"
echo "  Approver:      @${centerkimdudu}"
echo ""

# ── 0. gh CLI 확인 ────────────────────────────
command -v gh >/dev/null || { echo "❌ gh CLI가 필요합니다. https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "❌ gh auth login을 먼저 실행하세요."; exit 1; }
echo "[0/4] gh CLI 인증 확인 ✅"

# ── 1. gitops-app main 브랜치 보호 ───────────
echo ""
echo "[1/4] gitops-app main 브랜치 보호 규칙 설정..."
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${APP_REPO}/branches/main/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
echo "  ✅ gitops-app/main: PR 필수, CI 통과 필수, CODEOWNERS 리뷰 필수"

# ── 2. gitops-manifest main 브랜치 보호 ──────
echo ""
echo "[2/4] gitops-manifest main 브랜치 보호 규칙 설정..."
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${MANIFEST_REPO}/branches/main/protection" \
  --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
echo "  ✅ gitops-manifest/main: PR 필수, CODEOWNERS 리뷰 필수"

# ── 3. GitHub Environment "production" 생성 ──
echo ""
echo "[3/4] GitHub Environment 'production' 생성 (gitops-app)..."
# Environment 생성
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${APP_REPO}/environments/production" \
  --input - <<EOF
{
  "wait_timer": 0,
  "reviewers": [
    {
      "type": "User",
      "id": $(gh api "/users/${centerkimdudu}" --jq '.id')
    }
  ],
  "deployment_branch_policy": null
}
EOF
echo "  ✅ Environment 'production': @${centerkimdudu} 승인 필수"

# ── 4. 결과 요약 ─────────────────────────────
echo ""
echo "========================================"
echo "  설정 완료 요약"
echo "========================================"
echo "  ✅ gitops-app/main         → PR + CI(Test) + CODEOWNERS 리뷰 필수"
echo "  ✅ gitops-manifest/main    → PR + CODEOWNERS 리뷰 필수"
echo "  ✅ Environment 'production' → @${centerkimdudu} 승인 없이 prod 배포 불가"
echo ""
echo "  다음 단계:"
echo "  1. CODEOWNERS 파일에서 @centerkimdudu, @centerkimdudu 교체"
echo "  2. ArgoCD 설치: bash scripts/setup-argocd.sh <manifest-repo-url>"
echo "========================================"
