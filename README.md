# gitops-demo-manifest

ArgoCD가 감시하는 K8s 매니페스트 레포. **이 레포의 main 브랜치가 곧 클러스터 상태입니다.**

## 구조

```
base/          공통 K8s 리소스 (Deployment, Service, Ingress, ConfigMap)
overlays/
  dev/         gitops-dev namespace, replicas=1, 자동 sync
  qa/          gitops-qa namespace, replicas=2, 자동 sync
  prod/        gitops-prod namespace, replicas=3, 수동 sync + PDB
argocd/        ArgoCD Application, AppProject, RBAC
scripts/
  setup-argocd.sh       ArgoCD 설치 + Application 일괄 적용
  setup-protection.sh   GitHub Branch Protection 자동 설정
```

## 설치 (최초 1회)

```bash
# [HUMAN] centerkimdudu, kimtaejung 교체 후 실행
sed -i 's/centerkimdudu/<your-github-id>/g' argocd/*.yaml
sed -i 's/kimtaejung/<your-dockerhub-id>/g' overlays/*/kustomization.yaml
git add . && git commit -m "config: replace placeholders" && git push

# ArgoCD 설치
bash scripts/setup-argocd.sh https://github.com/<your-id>/gitops-manifest.git

# Branch Protection 설정
bash scripts/setup-protection.sh \
  <your-id>/gitops-app \
  <your-id>/gitops-manifest \
  <approver-github-id>
```

## Ingress 호스트 등록 (minikube)

```bash
echo "$(minikube ip) dev.gitops-demo.local" | sudo tee -a /etc/hosts
echo "$(minikube ip) qa.gitops-demo.local"  | sudo tee -a /etc/hosts
echo "$(minikube ip) gitops-demo.local"     | sudo tee -a /etc/hosts
```

## 배포 흐름

- **dev/qa**: manifest PR merge → ArgoCD 자동 sync (3분 이내)
- **prod**: `promote-to-prod` 워크플로우 → Approver 승인 → PR merge → ArgoCD 수동 Sync
