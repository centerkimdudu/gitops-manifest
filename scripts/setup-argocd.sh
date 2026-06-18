#!/usr/bin/env bash
# setup-argocd.sh — ArgoCD 설치 + GitOps Application 일괄 적용
# 사용법: bash scripts/setup-argocd.sh <manifest-repo-url>
# 예시:   bash scripts/setup-argocd.sh https://github.com/my-id/gitops-manifest.git
set -euo pipefail

ARGOCD_VERSION="v2.10.0"
MANIFEST_REPO_URL="${1:?사용법: $0 <manifest-repo-url>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_DIR="${SCRIPT_DIR}/../argocd"

echo ""
echo "========================================"
echo "  GitOps Demo — ArgoCD 설치 스크립트"
echo "========================================"
echo "  Manifest repo: ${MANIFEST_REPO_URL}"
echo "  ArgoCD 버전:   ${ARGOCD_VERSION}"
echo ""

# ── 1. 사전 확인 ─────────────────────────────
echo "[1/7] 사전 확인..."
command -v kubectl >/dev/null || { echo "❌ kubectl이 필요합니다."; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "❌ K8s 클러스터에 연결되지 않았습니다."; exit 1; }
echo "  ✅ kubectl 연결 확인"

# ── 2. Namespace 생성 ─────────────────────────
echo "[2/7] Namespace 생성..."
kubectl apply -f "${ARGOCD_DIR}/rbac-namespaces.yaml"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo "  ✅ gitops-dev / gitops-qa / gitops-prod / argocd"

# ── 3. ArgoCD 설치 ────────────────────────────
echo "[3/7] ArgoCD ${ARGOCD_VERSION} 설치..."
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
echo "  ⏳ ArgoCD 준비 대기 (최대 5분)..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
echo "  ✅ ArgoCD 설치 완료"

# ── 4. RBAC 설정 적용 ─────────────────────────
echo "[4/7] ArgoCD RBAC 설정 적용..."
kubectl apply -f "${ARGOCD_DIR}/argocd-rbac-cm.yaml"
echo "  ✅ argocd-rbac-cm 적용"

# ── 5. AppProject + Application 적용 ──────────
echo "[5/7] AppProject 생성..."
# repoURL 플레이스홀더가 남아있으면 경고
if grep -q "centerkimdudu" "${ARGOCD_DIR}/project.yaml"; then
  echo "  ⚠️  project.yaml에 centerkimdudu 플레이스홀더가 있습니다."
  echo "     파일을 수정한 후 다시 실행하세요."
  exit 1
fi
kubectl apply -f "${ARGOCD_DIR}/project.yaml"

echo "[6/7] Application 3개 생성 (dev / qa / prod)..."
kubectl apply -f "${ARGOCD_DIR}/app-dev.yaml"
kubectl apply -f "${ARGOCD_DIR}/app-qa.yaml"
kubectl apply -f "${ARGOCD_DIR}/app-prod.yaml"
echo "  ✅ gitops-demo-dev (auto sync)"
echo "  ✅ gitops-demo-qa  (auto sync)"
echo "  ✅ gitops-demo-prod (manual sync only)"

# ── 6. 초기 비밀번호 출력 ─────────────────────
echo "[7/7] ArgoCD 초기 접속 정보..."
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(비밀번호 조회 실패 — 잠시 후 재시도)")
echo ""
echo "========================================"
echo "  ArgoCD 접속 정보"
echo "========================================"
echo "  ID:       admin"
echo "  Password: ${ARGOCD_PWD}"
echo ""
echo "  포트포워딩 (새 터미널에서):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  → https://localhost:8080"
echo ""
echo "  ⚠️  초기 비밀번호는 반드시 변경하세요:"
echo "  argocd login localhost:8080 --insecure"
echo "  argocd account update-password"
echo "========================================"
