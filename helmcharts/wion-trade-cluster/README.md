# wion-trade cluster

Cluster API definition for `wion-trade`: a real (not virtual) Talos cluster on Proxmox VE,
1 control-plane + 1 worker, provisioned entirely through `hub`'s Argo CD via
`helmcharts/cluster-api`'s management plane. No Terraform, no `defyjoy/proxmox-talos` repo
involvement, no manual `clusterctl`/`talosctl` commands at steady state.

## Why this exists

Replaces the vcluster-hosted nested-ArgoCD approach removed earlier (see git history):
vcluster's generic CRD sync (needed to get an `HTTPRoute` from inside the virtual cluster onto
the host Gateway) required a Pro license this org doesn't have. A real cluster has its own
real Gateway, so that problem doesn't exist here at all -- `wion-trade` just needs its own
`cilium`/`cilium-gateway`/etc. rollout once it exists, the same way `dev` gets its component
rollout after `docs/runbooks/register-dev-cluster.md` finishes.

## One manual step: the Proxmox API token

Everything here is declarative except the Proxmox credential itself -- see
`helmcharts/cluster-api/README.md` for how to create the token in the Proxmox UI and the exact
`vault kv put` command. Both this chart's `credentialsRef` Secret (per-cluster, used by
`ProxmoxCluster`) and `helmcharts/cluster-api`'s provider-level Secret read the **same** Vault
path, just mapped to different key names -- see this chart's
`templates/proxmox-credentials-external-secret.yaml` for why.

## Topology

| Field | Value | Where |
|---|---|---|
| Control-plane endpoint | `192.168.9.10:6443` | `values.yaml` `controlPlaneEndpoint` -- single static IP, no kube-vip, since there's only one CP replica |
| Worker IP | `192.168.9.11` | `values.yaml` `worker.ip` |
| Proxmox template VM | `templateID: 9000` on node `pve` | `values.yaml` `proxmox` -- **must already exist**; this chart doesn't build the Talos template VM itself (see image-builder note below) |

These IPs/node names are placeholders -- fill in real values for your Proxmox host/network
before this chart can actually provision anything.

### Building the Talos template VM

CAPMOX clones an existing Proxmox VM template, it doesn't build one. You need a Talos
qemu-guest-agent-enabled disk image imported as a Proxmox VM template (ID `9000` by
convention here) before this chart can provision anything -- see
[Image Factory](https://factory.talos.dev) for a Proxmox-ready Talos image, or
[Sidero's image-builder](https://github.com/siderolabs/image-factory). This one-time template
creation is intentionally **not** part of this chart (it's an immutable OS image shared across
every VM this chart creates, not per-cluster config) -- do it by hand once on the Proxmox host,
same category of manual step as the API token above.

## Known-unverified pieces

Same caveat as `helmcharts/cluster-api/README.md`: `ProxmoxMachineTemplate.spec.template.spec`
field names (`sourceNode`, `templateID`, `numSockets`/`numCores`/`memoryMiB`, `disks`,
`network`) are a best-effort read of upstream CAPMOX docs, not yet checked against the live
CRD. Run `kubectl explain proxmoxmachinetemplate.spec.template.spec --recursive` once
`helmcharts/cluster-api`'s `InfrastructureProvider` is `Ready`, and fix field names in
`templates/control-plane.yaml`/`templates/workers.yaml` before trusting the first real sync.

The registration Job (`templates/argocd-cluster-registration-job.yaml`) assumes `yq` is
present in `registrationJob.kubectlImage` (`docker.io/alpine/k8s:1.31.13`) -- confirm before
relying on it; swap the image if not.

## Verification

```bash
export KUBECONFIG=~/.kube/talos-hub.yaml
kubectl get coreprovider,infrastructureprovider,bootstrapprovider,controlplaneprovider -A
kubectl get cluster,machine -n wion-trade
kubectl get secret -n argocd wion-trade-cluster -o jsonpath='{.metadata.labels}'; echo
```
