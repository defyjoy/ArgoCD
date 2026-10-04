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
| Control-plane endpoint | `192.168.9.10:6443` | `values.yaml` `controlPlaneEndpoint` -- a Talos-native floating VIP, not a real machine address (see below) |
| Worker IP | whatever the shared `ipv4Config` pool assigns | no longer pinned -- nothing external needs a worker's address known in advance |
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

## Why the control-plane endpoint is a Talos VIP, not a real machine address

CAPMOX assumes an HA shape: each machine gets its own real address from IPAM (the shared
`ipv4Config` pool on `ProxmoxCluster`), and `controlPlaneEndpoint` is meant to be a floating
VIP shared across however many CP replicas exist -- its webhook explicitly **rejects** putting
the endpoint IP inside `ipv4Config.addresses`. Two things confirmed live while getting a single
CP working with a fixed, known-in-advance endpoint:

- `defaultIPv4` on each `networkDevice` **must** be `true` -- a mutating webhook
  (`internal/webhook/proxmoxmachine_webhook.go`) force-sets it back to `true` on whichever
  device is `infrav1.DefaultNetworkDevice` if no device has it, so trying to turn it off to
  avoid the cluster-pool claim is a no-op.
- `Machine.status.addresses` (what CABPT/CACPPT use to connect for bootstrap/health checks)
  is **always** derived from that forced cluster-pool claim (`getClusterAPIMachineAddresses`
  only reads the `"default"` NetName bucket) -- a separate `ipPoolRef` pinned to a one-address
  pool still gets created as an *extra*, unused claim; it never becomes the reported address.
  Fighting this with a second pool just produces two `IPAddressClaim`s per device and the
  wrong one still wins.

So rather than fight IPAM for the primary address: each machine's real IP now comes from
whatever the shared `ipv4Config` pool assigns (matches `status.addresses` natively, no
mismatch possible), and the **control plane only** gets a Talos-native floating VIP
(`machine.network.interfaces[].vip.ip`, no kube-vip pod needed) added via `strategicPatches`
on top of that real address -- exactly Talos's supported mechanism for a stable endpoint
address that outlives any one CP replica. The worker needs no `strategicPatches` at all now;
its address is whatever IPAM gives it, and nothing outside the cluster needs to know it in
advance.

## `checks.skipQemuGuestAgent: true` -- Talos has no QEMU guest agent

Confirmed live: CAPMOX's reconcile loop got stuck forever on `error waiting for agent: the
operation has timed out`, blocking cloud-init injection entirely (`VirtualMachineProvisioned:
WaitingForCloudInit`, never progressing). It waits for a QEMU guest agent response before
proceeding, and Talos doesn't implement one (confirmed earlier via `qm guest cmd ... network
-get-interfaces` -> `"QEMU guest agent is not running"`). `checks.skipQemuGuestAgent: true` on
both `ProxmoxMachineTemplate`s skips that wait.

## Permanent OutOfSync on `Cluster`/`MachineDeployment`: `apiVersion` vs `apiGroup`

Confirmed live 2026-10-04: `Cluster.spec.{controlPlaneRef,infrastructureRef}` and
`MachineDeployment.spec.template.spec.{bootstrap.configRef,infrastructureRef}` now use CAPI
v1beta2's `ContractVersionedObjectReference` (`apiGroup` + `kind` + `name` -- no `apiVersion`,
no `namespace`), not the older `apiVersion`+`kind`+`name` shape. Submitting the old shape still
applies fine (the apiserver silently converts it), but every subsequent ArgoCD diff then
compares git's `apiVersion` field against live's `apiGroup` field forever -- permanent
OutOfSync with no real drift. Switched `Cluster`/`MachineDeployment` to `apiVersion:
cluster.x-k8s.io/v1beta2` and `apiGroup` refs to match what's actually served
(`kubectl api-resources --api-group=cluster.x-k8s.io` confirmed `v1beta2` is current).
`TalosControlPlane.spec.infrastructureTemplate` is a Talos-provider field, not core CAPI --
it's unaffected and still correctly uses the older `apiVersion`+`namespace` shape.

Two other entries (`TalosControlPlane`, `ExternalSecret`) looked similar but had a different,
actually-fixable cause: these aren't write-time ownership conflicts (no field manager owns
`init`/`hostname`/`conversionStrategy`/etc. -- checked `metadata.managedFields` directly, it's
empty for those paths), they're pure OpenAPI *schema defaults* the apiserver fills in on read
whenever our submitted manifest omits an optional field. Since the default values are fixed
and known (`init: {generateType: "", hostname: {}}`, `controlplane.hostname: {}`,
`rolloutStrategy: {type: RollingUpdate, rollingUpdate: {maxSurge: 1}}` on `TalosControlPlane`;
`conversionStrategy: Default`/`decodingStrategy: None`/`metadataPolicy: None` on every
`ExternalSecret` `remoteRef`), declaring them explicitly in git removes the diff entirely --
no `ignoreDifferences` needed, git just matches what's actually live.
