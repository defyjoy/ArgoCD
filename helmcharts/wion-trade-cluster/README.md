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
| Proxmox template VM | `templateID: 9000` on node `pve01` | `values.yaml` `proxmox` -- built 2026-10-04, see below |

### The Talos template VM

CAPMOX clones an existing Proxmox VM template, it doesn't build one. Built once by hand on
`pve01` (same category of manual step as the API token above -- it's an immutable OS image
shared across every VM this chart creates, not per-cluster config):

```bash
SCHEMATIC=$(curl -s -X POST --data-binary '{"customization":{}}' https://factory.talos.dev/schematics | jq -r .id)
curl -LO "https://factory.talos.dev/image/${SCHEMATIC}/v1.14.2/nocloud-amd64.raw.xz"
xz -d nocloud-amd64.raw.xz

qm create 9000 --name talos-template --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --ostype l26
qm importdisk 9000 nocloud-amd64.raw local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot order=scsi0
qm set 9000 --agent enabled=1
qm set 9000 --serial0 socket
qm template 9000
```

`values.yaml`'s `talosVersion` must match the Factory image version used here -- both are
`v1.14.2` (the real `v1.9.2` placeholder this chart started with doesn't exist as a Talos
release at all, confirmed via the Factory API 404ing it).

## Field names, verified against the live CRD (2026-10-04)

`ProxmoxMachineTemplate.spec.template.spec.network` is **not** `{default: {bridge, model}}` --
that was a guess and it failed sync outright (`field not declared in schema`). The real shape
is `networkDevices: [{bridge, model, defaultIPv4, ...}]`, a list, confirmed via `kubectl
explain proxmoxmachinetemplate.spec.template.spec --recursive`. `ProxmoxCluster.spec.dnsServers`
is also required at the top level (separate from `credentialsRef`/`controlPlaneEndpoint`) --
missing it fails validation the same way. If CAPMOX's schema changes again on a version bump,
re-run that `kubectl explain` before trusting any new field names.

The registration Job (`templates/argocd-cluster-registration-job.yaml`) assumes `yq` is
present in `registrationJob.kubectlImage` (`docker.io/alpine/k8s:1.31.13`) -- confirm before
relying on it; swap the image if not.

## `ProxmoxMachineTemplate`/`TalosConfigTemplate` are immutable -- bump `templateRevision`

Confirmed live, twice: changing anything under `proxmox.*`/`controlPlane.*`/`worker.*`/
`network.*` and re-syncing gets rejected outright -- `admission webhook ... denied the
request: ... is invalid: spec: Forbidden: ProxmoxMachineTemplate is immutable` and
separately `TalosConfigTemplate.Spec is immutable` for the worker's bootstrap template (the
`network.*` fix needed both -- it touches machine-level network devices *and* the Talos
config patch that sets the in-guest IP/gateway). This is deliberate CAPI design: you don't
edit a template in place, you create a new one and repoint whatever references it by name
(`TalosControlPlane.spec.infrastructureTemplate`, `MachineDeployment...infrastructureRef`,
`MachineDeployment...bootstrap.configRef`), which rolls out new Machines.
`TalosControlPlane.spec.controlPlaneConfig` is **not** immutable -- it updates in place and
drives its own rollout, no suffix needed there.

`values.yaml`'s `templateRevision` is suffixed onto `ProxmoxMachineTemplate` (both roles) and
`TalosConfigTemplate` (worker) names for exactly this -- bump it any time you change a
machine-level or network value, and ArgoCD's `prune: true` cleans up the orphaned old
template automatically. After bumping it, also delete the stale `Machine` objects
(`kubectl delete machine -n wion-trade --all`) -- MachineDeployment/KCP don't always notice a
template swap on their own and will keep re-reconciling the old, now-orphaned Machines
otherwise.

## Verification

```bash
export KUBECONFIG=~/.kube/talos-hub.yaml
kubectl get coreprovider,infrastructureprovider,bootstrapprovider,controlplaneprovider -A
kubectl get cluster,machine -n wion-trade
kubectl get secret -n argocd wion-trade-cluster -o jsonpath='{.metadata.labels}'; echo
```
