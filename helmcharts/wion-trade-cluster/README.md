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

## Machines stuck forever `Provisioning`/`Ready: Unknown`: missing `providerID`

Confirmed live: both `Machine`s sat indefinitely with `NodeHealthy: Waiting for a Node with
spec.providerID proxmox://<uuid> to exist` -- CAPI's `Machine` controller links a `Machine` to
its Kubernetes `Node` by matching `spec.providerID`, and nothing was ever setting it
(`kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'` on the workload cluster came
back empty on both nodes; there's no cloud-controller-manager running). `metadataSettings.
providerIDInjection: true` (confirmed via CAPMOX source, `pkg/cloudinit/metadata.go`) makes the
cloud-init metadata include `provider-id: proxmox://<instanceID>`, which Talos's `nocloud`
platform picks up and sets on the kubelet -- without it, CAPMOX's own default is `false`, and
every Machine blocks here forever regardless of how healthy the actual node is.

Confirmed live this alone is still not sufficient: `talosctl get platformmetadata` showed the
correct `providerId: proxmox://<uuid>` even with injection on, but `talosctl -n <ip> processes`
showed the running `kubelet` with **no `--provider-id` flag at all**, and `talosctl get
kubeletconfig` showed `cloudProviderExternal: false`. Talos only wires the platform metadata's
provider ID into the kubelet's `--provider-id` flag when the machine config has `cluster.
externalCloudProvider.enabled: true` -- without it, the metadata is correct but nothing ever
reads it. Added as a `strategicPatches` entry to both the `TalosControlPlane.controlPlaneConfig`
(updates in place) and the worker `TalosConfigTemplate` (immutable, needed the `templateRevision`
bump to `"9"`).

## Deleting the sole control-plane `Machine` destroys etcd -- don't bulk-delete on a single-CP cluster

The documented `kubectl delete machine -n wion-trade --all` cleanup step (above) is only safe
for a true HA control plane where other etcd members survive the delete. On this 1-CP cluster it
isn't: deleting the one control-plane `Machine` deletes its VM (and etcd's data dir on that VM)
without CAPI ever getting a chance to run `talosctl etcd remove-member` first. The replacement
`Machine` comes up with an empty etcd data dir and nothing to join -- `talosctl service etcd`
sits in `Preparing`/`Running pre state` forever, and `TalosControlPlane.status.bootstrapped`
is already `true` from the original revision, so the control-plane provider never re-triggers
`talosctl bootstrap` for it. Confirmed live via `talosctl --talosconfig <kcp-secret> -n <cp-ip>
get etcdmember` returning zero rows.

Recovery (manual, since nothing in CAPI will do this automatically once `bootstrapped` is
already `true`): extract the `<cluster>-talosconfig` Secret and run `talosctl --talosconfig
... -n <new-cp-ip> bootstrap` directly against the orphaned node. Avoid needing this at all by
preferring a rolling replacement (scale up, let the new Machine join, then delete the old one)
over bulk-deleting the only control-plane Machine, whenever this cluster stays single-CP.

## `cloud-provider=external` alone never sets `providerID` -- needs an actual CCM

Confirmed live: with `cluster.externalCloudProvider.enabled: true`, kubelet gets
`--cloud-provider=external` (`talosctl ... processes` showed the flag), but that flag's whole
contract is that kubelet does **not** set `spec.providerID` or clear the
`node.cloudprovider.kubernetes.io/uninitialized` taint itself -- it waits for a real
cloud-controller-manager to do both. `talosctl get kubeletspec` confirmed no `--provider-id`
arg ever gets added by Talos regardless of this setting; CAPMOX's own docs
(`docs/migration-v0.8-v1alpha2.md`) only document a `kubeadm`-style fix
(`kubeletExtraArgs.provider-id: "proxmox://'{{ ds.meta_data.instance_id }}'"`, templated by
cloud-init's own Jinja engine at boot) which has no Talos equivalent -- Talos's bootstrap
provider can't bake a per-VM dynamic UUID into a static `strategicPatches` string at git-render
time, since the UUID doesn't exist until Proxmox creates the VM.

Fixed by actually deploying `sergelogvinov/proxmox-cloud-controller-manager`, which has
first-class CAPMOX support (`config.features.provider: capmox` -> matches providerID in the
exact `proxmox://<SystemUUID>` form `metadataSettings.providerIDInjection` produces) and runs
the standard Kubernetes `cloud-node` controller, which looks up each new Node's matching
Proxmox VM and sets `providerID`/clears the taint itself -- no kubelet-side involvement needed
at all. Delivered via `templates/ccm-resourceset.yaml`: an `ExternalSecret` templates the whole
manifest bundle (RBAC, Deployment, and a `Secret` with the real Vault-sourced Proxmox API
token) into one Secret of type `addons.cluster.x-k8s.io/resource-set`, and a
`ClusterResourceSet` (core CAPI, already installed by `cluster-api-operator`'s `CoreProvider`
-- no extra provider needed, confirmed via `kubectl api-resources --api-group=addons.cluster.x-k8s.io`)
applies it into `wion-trade` itself. `ClusterResourceSet.spec.clusterSelector` matches on the
`Cluster` object's own labels, which don't get a `cluster.x-k8s.io/cluster-name` label by
default -- added explicitly in `templates/cluster.yaml`.

Only enable the `cloud-node` controller (not just `cloud-node-lifecycle`, which is all the
project's own static Talos example manifest enables, `docs/deploy/cloud-controller-manager-talos.yml`
-- that example assumes something else sets `providerID`, which doesn't apply to a CAPMOX-managed
cluster): `cloud-node` is specifically the controller that sets `providerID` on a brand new
Node, confirmed via `docs/install.md`'s own description of step 3 of the join sequence.

Confirmed live the CCM pod itself also needs `insecure: true` against this Proxmox endpoint --
first attempt failed every reconcile with `GET /cluster/resources: ... x509: certificate signed
by unknown authority` (CCM pod logs). Proxmox here uses its default self-signed cert, same as
every other self-signed endpoint in this homelab (OpenBao, etc.) -- CAPMOX's own core/infra
provider doesn't expose an `insecure` toggle at all in this chart and apparently tolerates it
some other way, but the CCM's Go client does TLS verification and needs telling explicitly.

Second, separate error after that: `proxmox API error 500: 500 no such file '/cluster/resources'`.
The shared Vault `url` property (`wion-trade/hub/cluster-api/proxmox-credentials`) is
deliberately the bare `https://<host>:8006` -- CAPMOX's own provider wants no suffix (see
`helmcharts/cluster-api/README.md`). The CCM's client instead expects the full
`https://<host>:8006/api2/json` form (matches its own `docs/config.md` example) and otherwise
builds a path that doesn't exist on the bare host. Append `/api2/json` only inside this chart's
own CCM config template, not the shared Vault value -- the two providers want genuinely
different URL shapes from the same credential.
