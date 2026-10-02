# Longhorn (Helm)

Wrapper chart around [Longhorn](https://longhorn.io/) (`longhorn` from `https://charts.longhorn.io`). Dependency values live under the `longhorn:` key in `values.yaml`.

## Prerequisites

- Kubernetes **1.25+** (chart constraint).
- Nodes: **open-iscsi**, **NFS client** (for RWX), and sufficient disk under the default data path (see upstream docs).
- For **Argo CD**: label the cluster secret with **`longhorn=true`** (see `helmcharts/argocd-apps/templates/applicationsets/longhorn-as.yaml`).

## Install (Helm)

```bash
cd helmcharts/longhorn
helm dependency update
helm upgrade --install longhorn . -n longhorn-system --create-namespace -f values.yaml
```

## Configuration

- Defaults: `defaultClass: true`, **2** replicas on the StorageClass (`defaultClassReplicaCount`); tune in `values.yaml` for 3+ nodes.
- If **OpenEBS** (or another provisioner) must remain the default StorageClass, set `longhorn.persistence.defaultClass: false`.
- **HTTPRoute**: keep `longhorn.httproute.enabled: false` (upstream chart’s minimal `backendRefs` cause Argo CD drift). Enable the wrapper with root `httproute.enabled: true` — this chart renders `templates/longhorn-httproute.yaml` with explicit `backendRefs`. Targets the shared Envoy Gateway listener in `envoy-gateway-system`. Adjust `httproute.hostnames` and `defaultSettings.managerUrl` to your domain.

## References

- [Longhorn documentation](https://longhorn.io/docs/)
- `helm show values longhorn/longhorn --version 1.11.1`

---

## This deployment's configuration

### HTTPRoute is rendered by the wrapper

```yaml
httproute:
  # explicit backendRefs -- see templates/
```

Wrapper-chart values only; **not** passed to the `longhorn` dependency (keep dependency values
under `longhorn:`). Phase 2 batch 3 (infra tools) of the Envoy Gateway → Istio Gateway
migration; `longhorn.home.arpa` was already in the stepca cert's SAN list, so no reissuance was
needed.

> 🚫 The **upstream** chart also ships an HTTPRoute, with minimal `backendRefs` that cause Argo
> CD drift. It stays disabled — use the root `httproute` above.

### The `pre-upgrade` hook must stay disabled

> 🚨 **Argo CD maps the chart's `pre-upgrade` hook straight to `PreSync` on every sync,
> including first install** — unlike `helm upgrade`, which only fires it on actual upgrades.
>
> On a fresh install the job's `longhorn-manager pre-upgrade` crashes because Longhorn CRDs
> don't exist yet (they are applied later, during the normal Sync phase). The PreSync hook
> therefore never succeeds, and **nothing else in the Application syncs behind it**.

### StorageClass

```yaml
longhorn:
  # Installs the Longhorn StorageClass; can be marked default.
```

Disable the default-class flag if another default StorageClass (e.g. OpenEBS) should win.

> 📎 Upstream reference: `helm show values longhorn/longhorn --version 1.11.1`. If you enable
> `networkPolicies`, set its `type` to match the distro (`k3s` | `rke2` | `rke1`).
