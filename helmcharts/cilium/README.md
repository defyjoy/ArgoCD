# cilium

Wrapper around the Cilium subchart, serving as the cluster CNI, the kube-proxy replacement, and
the sole LoadBalancer implementation (LB-IPAM + L2 announcement).

- Toggled by `enabled` (`Chart.yaml` `condition: enabled`)
- The ApplicationSet is itself label-gated (`cilium: "true"`), so this stays effectively off on
  any cluster whose Secret doesn't carry the label
- Per-cluster LoadBalancer address lists live in `values/<environment>.yaml`
- Per-distro values (Kubernetes API reachability, node NIC name) live in
  `values/distro/<talos|k3s>.yaml`, selected per-cluster by a static `values.distro` param on
  the ApplicationSet's `clusters` generator — see "Per-distro overlays" below. This chart
  targets both distros; `hub` runs k3s as of 2026-09-01 (migrated off Talos), `dev` is undecided.

Full context: alarmify-docs `docs/cilium/cilium-migration-plan.md` (executable runbook) and
`docs/infrastructure/adr-009-cilium-cni-loadbalancer-migration.md` (decision).

---

## Configuration

### kube-proxy replacement

```yaml
cilium:
  kubeProxyReplacement: true
```

kube-proxy is disabled at the distro level on every cluster this chart targets. With no
kube-proxy, Cilium must reach the API server directly through a local, node-resident load
balancer — which endpoint that is depends on the distro, so `k8sServiceHost`/`k8sServicePort`
live in the per-distro overlay, not here. See "Per-distro overlays" below.

### IPAM — pod CIDR must not change

```yaml
cilium:
  ipam:
    mode: kubernetes
```

Reuses the per-node podCIDRs Talos already allocates from the cluster CIDR (`10.244.0.0/16`).

> 🚫 **Keeps the pod CIDR unchanged deliberately.** Re-IPing would break the Istio ambient
> multi-network mesh (ADR-006) and every running pod.

### cgroup / capabilities

```yaml
cilium:
  cgroup:
    autoMount:
      enabled: false
    hostRoot: /sys/fs/cgroup
  securityContext:
    capabilities:
      ciliumAgent:
        - CHOWN, KILL, NET_ADMIN, NET_RAW, IPC_LOCK, SYS_ADMIN
        - SYS_RESOURCE, DAC_OVERRIDE, FOWNER, SETGID, SETUID
      cleanCiliumState:
        - NET_ADMIN, SYS_ADMIN, SYS_RESOURCE
```

Originally set because Talos has a **read-only rootfs and mounts cgroup v2 itself**, so Cilium
must not auto-mount it and needs an explicit capability set (both lists are Talos-documented).
In practice both hold equally well on plain Ubuntu/k3s nodes with systemd-managed cgroup v2, so
this stays in the shared `values.yaml` rather than a per-distro overlay — verify this assumption
if a future distro doesn't pre-mount cgroup v2 the same way.

*(Capabilities shown comma-joined for brevity; they are one item per line in `values.yaml`.)*

### Gateway API

```yaml
cilium:
  gatewayAPI:
    enabled: true
```

Auto-creates the `GatewayClass` named `cilium`, which `helmcharts/cilium-gateway` targets.

### Istio ambient coexistence — highest-risk setting

```yaml
cilium:
  cni:
    exclusive: false
  socketLB:
    hostNamespaceOnly: true
```

`istio-cni` and `ztunnel` already run here. Cilium **must not be the exclusive CNI**, so
istio-cni can chain its config, and its socket-level load balancer must stay in the host
namespace so it does not short-circuit ztunnel's in-pod traffic redirection.

> ⚠️ This is the highest-risk part of the migration — validate on dev (plan Phase 4) before
> touching management.

### LoadBalancer via L2/ARP

```yaml
cilium:
  l2announcements:
    enabled: true
  externalIPs:
    enabled: true
  k8sClientRateLimit:
    qps: 50
    burst: 100
```

L2/ARP announcement, because there is no BGP router on this LAN.

The raised client rate limit is **required, not tuning**: L2 announcements plus kube-proxy
replacement increase apiserver usage through leader-election leases, and at the default limit
announcements get throttled (per Cilium docs).

### Footprint

```yaml
cilium:
  operator:
    replicas: 1
    rollOutPods: true
    skipCRDCreation: true
  hubble:
    enabled: false
```

Single operator replica (small clusters). Hubble UI/relay off for now given this cluster's known
CPU pressure — enable post-migration if central observability is wanted.

> 📌 **`skipCRDCreation` history.** This was set because the wrapper previously vendored all
> Cilium CRDs in `crds/`, and letting the operator also manage them made ArgoCD and the operator
> fight over CRD ownership. `crds/` was **removed on 2026-07-23** — the operator now registers
> CRDs at runtime, and the CR templates carry sync-wave `"3"` plus
> `SkipDryRunOnMissingResource=true` so ArgoCD applies them only after the operator is up.

---

## This chart's own LoadBalancer CRs

```yaml
loadBalancer:
  enabled: true
  poolName: default-pool
  addresses: []
```

`templates/cilium-*.yaml` render a `CiliumLoadBalancerIPPool` and a
`CiliumL2AnnouncementPolicy`. `interface` (a regex of node interfaces to announce on) is not set
here — it's distro-specific and lives in `values/distro/<talos|k3s>.yaml` (see below), since the
NIC name depends on the hypervisor/OS, not the cluster.

`addresses` is empty in the shared file; each cluster supplies its own disjoint `/32` list in
its overlay. **When empty the templates render nothing**, so a cluster can sync before its pool
is decided.

`loadBalancer.enabled: true` is the steady-state default. Cilium is now the only thing answering
ARP for these `/32`s; if a second L2 responder is ever introduced on this LAN, both would ARP for
the same addresses, so keep any such component's pool disjoint from these lists.

**IP pinning:** existing gateway Services already request their specific IP via
`Gateway.spec.addresses` → `Service.spec.loadBalancerIP`, which Cilium LB-IPAM honours. A pool
that merely *contains* the in-use `/32`s therefore preserves each Service's current IP
(verified in plan Phase 4).

---

## Per-distro overlays

Selected by the Cilium ApplicationSet itself
(`helmcharts/argocd-apps/templates/applicationsets/cilium-as.yaml`) — deliberately **not** a
cluster Secret label. The `clusters` generator carries a static `values: {distro: k3s}` param,
and the template's `values/distro/{{values.distro}}.yaml` entry substitutes accordingly. This
layers *before* the per-cluster overlay.

Both `dev` and `hub` currently share the one generator/selector, so both get `distro: k3s`. If
`dev` ends up on a different distro, split it into its own `clusters` generator entry with its
own `values.distro`.

These two keys have no default in the shared `values.yaml` on purpose — a cluster reached
through a code path that doesn't supply the distro overlay should fail loud (`k8sServiceHost`
unset → Cilium can't reach the apiserver) rather than silently inherit whichever distro happened
to be the default.

The bootstrap script (`scripts/cluster/install-cilium.sh`, driven by `taskfiles/argocd.yaml`)
installs Cilium via a raw `helm upgrade`, not through this ApplicationSet, so it can't read
`values.distro` off a generator. It gets the same overlay through its own `CILIUM_DISTRO_VALUES`
Taskfile var (default `values/distro/k3s.yaml`), layered the same way — before `CILIUM_VALUES`.
Override it for a Talos cluster: `task install-cilium CILIUM_DISTRO_VALUES=values/distro/talos.yaml`.

### `values/distro/talos.yaml`

```yaml
cilium:
  k8sServiceHost: localhost
  k8sServicePort: 7445
loadBalancer:
  interface: ens18
```

kube-proxy is removed at the Talos level (`cluster.proxy.disabled: true`). Talos **KubePrism**
exposes a load-balanced apiserver endpoint on `localhost:7445` on every node — that's what
`kubeProxyReplacement` talks to. `ens18` is the Talos-on-Proxmox virtio NIC name.

### `values/distro/k3s.yaml`

```yaml
cilium:
  k8sServiceHost: localhost
  k8sServicePort: 6444
loadBalancer:
  interface: eth0
```

k3s is run here with kube-proxy disabled too. k3s ships its own local client load balancer to
the apiserver on every node (server *and* agent roles) at `127.0.0.1:6444` — confirmed by
`nc -zv 127.0.0.1 6444` succeeding on both a `k3s-server-*` and a `k3s-agent-*` node — which is
the direct equivalent of Talos KubePrism. `eth0` is the real host NIC name on these Ubuntu
24.04 nodes (cross-checked against `kube-vip`'s own `vip_interface: eth0`).

> ⚠️ If a future k3s cluster is started with `--disable-agent-lb`, this port won't be listening
> and this overlay needs revisiting.

---

## Per-cluster overlays

Lists must stay **disjoint** — both clusters share the `192.168.0.0/16` LAN.

### dev — `values/dev.yaml`

The migration canary (plan Phases 2–5).

```yaml
loadBalancer:
  addresses:
    - 192.168.5.11/32    # istio-gateway (dev)
    - 192.168.5.12/32    # istio-eastwest (dev)
```

### management — `values/hub.yaml`

**Preserve every IP exactly** — each is already claimed by a live Service.

```yaml
loadBalancer:
  addresses:
    - 192.168.3.10/32    # istio-gateway (north-south)
    - 192.168.3.11/32    # coredns-lan (kube-system)
    - 192.168.3.12/32    # istio-eastwest
```

> ⏳ **Gating note, possibly stale.** This overlay was written with the instruction *"do not
> enable Cilium here until the dev canary is fully validated (plan Phases 6–9), and only on
> Cilium 1.20.0 GA, not the RC pinned in `Chart.yaml`."* Confirm the current cluster state
> before relying on that: `Chart.yaml` still pins an RC, so if management is already running
> Cilium, this constraint has been consciously overridden and should be re-recorded.
