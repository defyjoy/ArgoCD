# Cluster API

Installs the Cluster API **management plane** on `hub`: the upstream
[`cluster-api-operator`](https://github.com/kubernetes-sigs/cluster-api-operator) chart, plus
the provider CRs it watches (`CoreProvider`, `InfrastructureProvider`, `BootstrapProvider`,
`ControlPlaneProvider`). This chart installs the *engine* only — no actual workload cluster is
defined here; see `helmcharts/wion-trade-cluster` for the first (and so far only) consumer.

Replaces the vcluster-based virtualization approach removed from this repo in 2026-10: instead
of a fake API server syncing select objects to the host (which hit vCluster Pro's licensing
wall on generic CRD sync), this provisions **real** clusters on Proxmox — each with its own real
Gateway, no syncer process to crash, and nothing license-gated.

## Why Proxmox (CAPMOX) + Talos

Every node in this org already runs Talos Linux, so the Talos bootstrap/control-plane
providers (`siderolabs/cluster-api-bootstrap-provider-talos`) give the same
`talosctl`/machine-config mental model as `hub` itself -- no cloud-init/kubeadm path at all.
CAPMOX (`ionos-cloud/cluster-api-provider-proxmox`) is the actively-maintained CAPI
infrastructure provider for Proxmox VE.

## Proxmox credentials

The `InfrastructureProvider`'s `configSecret` (`templates/proxmox-credentials-external-secret.yaml`)
expects **environment-variable-shaped keys** -- `PROXMOX_URL`/`PROXMOX_TOKEN`/`PROXMOX_SECRET` --
because the operator injects this Secret verbatim into the capmox controller-manager's
environment. Create the underlying Vault entry once, by hand (same category as the `dev`
cluster's manual bootstrap step in `docs/runbooks/register-dev-cluster.md` -- credentials never
live in values files, and this one has no automatable precursor):

```bash
vault kv put kv/wion-trade/hub/cluster-api/proxmox-credentials \
  url="https://<proxmox-host-ip>:8006" \
  token_id="<user>@pve!<tokenid>" \
  token_secret="<secret-uuid>"
```

Create the Proxmox API token in the Proxmox web UI first: Datacenter -> Permissions -> API
Tokens -> Add, for a user with enough privilege to create/delete VMs (`PVEVMAdmin` or similar)
on the target node/pool. `token_id` is `<user>@<realm>!<token-name>` (e.g.
`capi@pve!cluster-api`); `token_secret` is the UUID Proxmox shows you exactly once.

Two gotchas confirmed from a live `CrashLoopBackOff` (2026-10-04): `url` must **not** include
`/api2/json` -- CAPMOX appends that path itself, so including it produces a doubled,
404-ing URL (`.../api2/json/api2/json/version`). And it must be an **IP, not a `.home.arpa`
hostname** -- `kube-system/coredns`'s `home.arpa` zone (`helmcharts/argocd/templates/kube-system/core-dns-cofigmap.yaml`)
only serves the handful of hostnames explicitly listed in its `hosts` block and has no
`forward` fallback for anything else, so an unlisted hostname SERVFAILs instead of resolving.

## Known-unverified pieces

These manifests were written from upstream docs, not validated against a live cluster yet --
double check against the installed CRDs (`kubectl explain infrastructureprovider.spec` etc.)
before trusting them blind on first apply:

- Provider versions (`values.yaml`'s `providers.*.version`) are each confirmed against that
  provider's own GitHub releases as of 2026-10-04 -- the bootstrap and control-plane Talos
  providers are **separate repos with independent version numbers** (`v0.6.8` vs `v0.5.14`);
  don't assume they match. Bump as needed, `cluster-api-operator` will reconcile the change.
- CAPMOX's per-cluster `credentialsRef` Secret (consumed by `helmcharts/wion-trade-cluster`, not
  this chart) uses different key names (`url`/`token`/`secret`, lowercase) than this chart's
  env-var-shaped provider-level Secret -- don't conflate the two when debugging auth failures.
