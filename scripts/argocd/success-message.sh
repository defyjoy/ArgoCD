#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"

cat <<EOF

╔═══════════════════════════════════════════════════════════════╗
║           ArgoCD Bootstrap Complete! 🎉                       ║
╚═══════════════════════════════════════════════════════════════╝

Next Steps:

1. Access ArgoCD UI:
   task port-forward
   URL: https://localhost:${PORT}

2. Login with admin credentials (shown above)

3. Install ArgoCD CLI (optional):
   brew install argocd  # macOS
   # or: https://github.com/argoproj/argo-cd/releases

4. Login via CLI:
   argocd login localhost:${PORT} --username admin --insecure

5. Change admin password:
   argocd account update-password

6. Check Applications:
   task status
   # or
   argocd app list

7. Enable components for ApplicationSets:
   Never 'kubectl label' the cluster Secret directly -- selfHeal reverts it on the next
   reconcile. Add the label declaratively instead:
   - management (hub): helmcharts/argocd/templates/cluster/hub-cluster-secret.yaml
   - dev: helmcharts/argocd/templates/cluster/dev-cluster-secret.yaml
   ...then commit and push; the self-managed argocd Application applies it.

Documentation: helmcharts/argocd/README.md

EOF
