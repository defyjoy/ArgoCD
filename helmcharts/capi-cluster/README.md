# capi-cluster

Generic Cluster API definition for a real (not virtual) Talos cluster on Proxmox VE,
1 control-plane + 1 worker, provisioned entirely through `hub`'s Argo CD via
`helmcharts/cluster-api`'s management plane. No Terraform, no `defyjoy/proxmox-talos` repo
involvement, no manual `clusterctl`/`talosctl` commands at steady state.

Originally built single-purpose as `wion-hub-cluster`. Generalized 2026-10-05 to serve every
CAPI-provisioned cluster in this homelab (`wion-hub`, `wion-trade`, `stayozo-hub`, `stayozo`)
from one chart: `values.yaml` holds everything shared (Kubernetes/Talos version, Proxmox
template/disk/network device defaults, machine sizing, `MachineHealthCheck` thresholds), and
`values/<clusterName>.yaml` holds everything that must differ per cluster -- `clusterName`,
`namespace`, `controlPlaneEndpoint.host` (VIP), the Proxmox `sourceNode` for each role, the
`network.ipv4Addresses` pool, and the per-cluster `credentialsRef.secretName`. One
`ApplicationSet` (`helmcharts/argocd-apps/templates/applicationsets/capi-clusters-as.yaml`)
drives all four via a `matrix` generator: the usual `hub`-cluster-secret gate combined with a
`list` generator of `clusterName`s, so adding a fifth cluster is one new `values/<name>.yaml`
file plus one new `list` element, not a new chart.

All four clusters share the same Proxmox credential (`credentialsRef.externalSecrets.vaultPath`
stays in the base `values.yaml`, historically named `wion-hub/...` but not actually specific to
that cluster) -- pve01/pve03/pve04 are one Proxmox cluster/API endpoint, confirmed live; only
`sourceNode` (which physical host a given role's VM lands on) varies, spread across the three
hosts per cluster so no single Proxmox node carries every control-plane or every worker.

## Why this exists

Replaces the vcluster-hosted nested-ArgoCD approach removed earlier (see git history):
vcluster's generic CRD sync (needed to get an `HTTPRoute` from inside the virtual cluster onto
the host Gateway) required a Pro license this org doesn't have. A real cluster has its own
real Gateway, so that problem doesn't exist here at all -- each of these clusters just needs its
own `cilium`/`cilium-gateway`/etc. rollout once it exists, the same way `dev` gets its component
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
| Proxmox template VM | `templateIDs: {pve01: 9000, pve03: 9003, pve04: 9004}` | `values.yaml` `proxmox` -- built 2026-10-04/05, see below |

### The Talos template VM -- one per Proxmox node, not one shared ID

Proxmox templates are node-local (even though pve01/pve03/pve04 share one API endpoint):
a `ProxmoxMachineTemplate` with `sourceNode: pve03` cloning `templateID: 9000` fails outright
if `9000` only exists on `pve01`. Since every cluster here spreads its control-plane and
worker across different `sourceNode`s (see Topology above), a single global `templateID`
broke the moment any pool's `sourceNode` wasn't `pve01`. `proxmox.templateIDs` is a map keyed
by node name; `templates/control-plane.yaml` and `templates/workers.yaml` each look up
`index .Values.proxmox.templateIDs .Values.<role>.sourceNode` instead of a flat value -- add
a new cluster/pool on a node not yet in the map and the lookup fails loudly rather than
cloning the wrong OS image.

Built once by hand on `pve01`, then full-cloned and migrated (not re-downloaded) to `pve03`/
`pve04` so all three stay byte-identical:

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

# pve01 and pve03/pve04 don't share storage, so `qm migrate` alone would move (not copy) the
# template -- clone first, migrate the clone, then re-flag it as a template on the target node:
qm clone 9000 9003 --full --name talos-template --storage local-lvm
qm migrate 9003 pve03 --with-local-disks
ssh pve03 qm template 9003
# repeat with 9004 / pve04
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
(`kubectl delete machine -n wion-hub --all`) -- MachineDeployment/KCP don't always notice a
template swap on their own and will keep re-reconciling the old, now-orphaned Machines
otherwise.

## Verification

```bash
export KUBECONFIG=~/.kube/talos-hub.yaml
kubectl get coreprovider,infrastructureprovider,bootstrapprovider,controlplaneprovider -A
kubectl get cluster,machine -n wion-hub
kubectl get secret -n argocd capi-cluster -o jsonpath='{.metadata.labels}'; echo
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

A third, later OutOfSync on `TalosControlPlane` turned out to be neither: `spec.
infrastructureTemplate` is a single atomic struct fully owned by `argocd-controller`
(`metadata.managedFields` confirmed this -- not split per-subfield, and no other manager
touches it), and the CRD schema has no `default:` on `infrastructureTemplate.namespace`
either (checked directly via `kubectl get crd ... -o json`). The actual source is a mutating
admission webhook belonging to the Talos control-plane provider that defaults a cross-namespace
reference's `namespace` to the CR's own namespace whenever the submitted manifest omits it --
old-style CAPI convenience default, applied before storage, so it lands inside *our own*
managedFields entry rather than a separate manager's. Fixed the same way as the schema-default
case above: declared `namespace` explicitly on `infrastructureTemplate` so git matches what the
webhook was already producing live.

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

The documented `kubectl delete machine -n wion-hub --all` cleanup step (above) is only safe
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
applies it into `wion-hub` itself. `ClusterResourceSet.spec.clusterSelector` matches on the
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
The shared Vault `url` property (`wion-hub/hub/cluster-api/proxmox-credentials`) is
deliberately the bare `https://<host>:8006` -- CAPMOX's own provider wants no suffix (see
`helmcharts/cluster-api/README.md`). The CCM's client instead expects the full
`https://<host>:8006/api2/json` form (matches its own `docs/config.md` example) and otherwise
builds a path that doesn't exist on the bare host. Append `/api2/json` only inside this chart's
own CCM config template, not the shared Vault value -- the two providers want genuinely
different URL shapes from the same credential.

## `MachineHealthCheck`: nothing remediated the stuck-`Provisioning` failure mode above on its own

Confirmed live 2026-10-04: a control-plane `Machine` (template rev 8, pre-`providerID` fix above)
went network-dead mid-rollout -- `talosctl`/apid port 50000 and ICMP both timing out, Node never
registered -- and just sat in `Phase: Provisioned` indefinitely. `TalosControlPlane`'s own
scale-down logic requires `ControlPlaneComponentsHealthy`/`EtcdClusterHealthy` across *every*
current `Machine` before it will delete the surplus one, so an unreachable old `Machine` wedges
the rollout forever with no automatic recovery -- etcd itself had already dropped the dead
member and was healthy on just the surviving node, but the stale `Machine` object never got
cleaned up. There was no `MachineHealthCheck` for this cluster at all to catch it.

```yaml
machineHealthCheck:
  nodeStartupTimeoutSeconds: 600
  unhealthyConditionTimeoutSeconds: 300
```

`templates/machinehealthcheck.yaml` selects every `Machine` in the cluster via the
`cluster.x-k8s.io/cluster-name` label CAPI already sets on all of them (control-plane and
worker alike) -- one `MachineHealthCheck`, not a pair, since both roles should get the same
unreachable-node treatment. `nodeStartupTimeoutSeconds` (CAPI default: 10 minutes) covers the
"`Machine` never got a Node at all" case from the `providerID` section above; the `Ready`
`Unknown`/`False` `unhealthyNodeConditions` at 5 minutes cover a `Machine` that joined fine and
then went dark later, like this one did. No `remediation.templateRef` is set, so the controller
marks `OwnerRemediated` on the unhealthy `Machine` and lets `TalosControlPlane`/`MachineDeployment`
delete-and-replace it themselves -- the same path a healthy rolling update already uses.
