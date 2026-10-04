# vCluster Helm Chart

This Helm chart deploys vCluster (Virtual Kubernetes Clusters) using the official Loft vCluster Helm chart.

## Features

- **Virtual Kubernetes Clusters**: Create lightweight, isolated Kubernetes clusters within your existing cluster
- **Resource Syncing**: Sync nodes, storage classes, persistent volumes, and more from host cluster
- **Multi-Tenancy**: Enable namespace isolation and multi-tenancy
- **Security**: Pod security contexts and RBAC configuration
- **Persistence**: Persistent storage for etcd data

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.0+
- ArgoCD (for GitOps deployment)
- Persistent volume provisioner support

## Installation

### Via ArgoCD (Recommended)

This chart is designed to be deployed via ArgoCD using GitOps principles. The ApplicationSet is located at:

```
helmcharts/argocd-apps/templates/applicationsets/vcluster-as.yaml
```

It uses a `matrix` generator: a `clusters` generator gated on the `vcluster: "true"` label
(set declaratively in `helmcharts/argocd/templates/cluster/hub-cluster-secret.yaml` — never
`kubectl label` a live cluster Secret, selfHeal reverts it) crossed with a `list` generator
enumerating the actual named instances. Each `(cluster, instance)` pair produces one
`Application` — on hub today that's:

| Instance | Application | Namespace | StatefulSet |
|---|---|---|---|
| `stayozo-hub` | `local-stayozo-hub-vcluster` | `vcluster-stayozo-hub` | `local-stayozo-hub-vcluster-0` |
| `wion-hub` | `local-wion-hub-vcluster` | `vcluster-wion-hub` | `local-wion-hub-vcluster-0` |

Add a new vcluster by adding a `list` element to `vcluster-as.yaml`, not by creating a new
chart or Application by hand. The host cluster is always whatever the `clusters` generator
matches — currently only `hub` — so these StatefulSets run as ordinary pods **on hub**, not
on some separate "vcluster root" cluster. There's no mechanism that would ever point this
ApplicationSet at a vcluster's own API server (that would require giving a vcluster's own
cluster Secret the `vcluster: "true"` label, which nothing here does and shouldn't).

### Manual Installation

Only for local testing against this chart's own `values.yaml` — the GitOps path above is
what actually names and namespaces `stayozo-hub`/`wion-hub` on hub:

```bash
helm dependency update helmcharts/vcluster
helm install stayozo-hub-test helmcharts/vcluster \
  --namespace vcluster-stayozo-hub-test \
  --create-namespace \
  -f helmcharts/vcluster/values.yaml
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vcluster.name` | Name of the vcluster instance | `vcluster` |
| `vcluster.sync.nodes.enabled` | Sync nodes from host cluster | `true` |
| `vcluster.sync.storageClasses.enabled` | Sync storage classes | `true` |
| `vcluster.persistence.enabled` | Enable persistent storage | `true` |
| `vcluster.persistence.size` | Size of persistent volume | `20Gi` |
| `vcluster.persistence.storageClass` | Storage class for persistence | `longhorn` |

### Sync Configuration

vCluster can sync various resources from the host cluster:

- **Nodes**: Sync all nodes from the host cluster
- **Storage Classes**: Sync storage classes for dynamic provisioning
- **Persistent Volumes**: Sync persistent volumes
- **Ingress Classes**: Sync ingress classes
- **Network Policies**: Sync network policies
- **Priority Classes**: Sync priority classes

### Security Configuration

The chart includes security contexts:
- Pod security context with non-root user
- Container security context with dropped capabilities
- RBAC integration
- Service account configuration

## Usage

### Accessing vCluster

The Helm release name — which ArgoCD sets to the Application name — is the vcluster name
`vcluster connect` needs, and the destination namespace is the one from the table above:

```bash
export KUBECONFIG=~/.kube/talos-hub.yaml
vcluster connect local-stayozo-hub-vcluster -n vcluster-stayozo-hub
```

This does two things worth knowing before you run it:

1. **It port-forwards and blocks the terminal.** The vcluster's API server isn't reachable
   any other way by default (no Ingress/Gateway in front of it), so this process has to keep
   running — `Ctrl+C` to stop it and fall back out of the vcluster.
2. **It mutates whatever kubeconfig `KUBECONFIG` pointed at**, adding a new context named
   `vcluster_<release>_<namespace>_admin@hub` and switching `current-context` to it — it does
   **not** write a separate file. If you ran it with `KUBECONFIG=~/.kube/talos-hub.yaml`, that
   file's active context is now the vcluster, not hub, until you `Ctrl+C` (which restores the
   previous context) or `kubectl config use-context` back manually.

To avoid losing track of which cluster a given terminal is pointed at, write each vcluster's
kubeconfig to its own file instead of touching `talos-hub.yaml`:

```bash
vcluster connect local-stayozo-hub-vcluster -n vcluster-stayozo-hub --kube-config ./stayozo-hub.yaml &
export KUBECONFIG=./stayozo-hub.yaml   # this terminal now talks to stayozo-hub only
```

Verify you're actually inside the vcluster, not hub — it only has the four default namespaces:

```bash
kubectl get ns   # default, kube-system, kube-public, kube-node-lease -- nothing else
```

### Deploying Applications

Once connected, you can deploy applications to the vcluster as if it were a regular Kubernetes cluster:

```bash
kubectl apply -f my-app.yaml
```

## Troubleshooting

### Common Issues

1. **Pods Not Starting**: Check resource limits and storage class availability
2. **Sync Issues**: Verify sync configuration matches your requirements
3. **Storage Issues**: Ensure storage class exists and has sufficient capacity

### Logs

```bash
kubectl logs -n vcluster-stayozo-hub local-stayozo-hub-vcluster-0
```

## Upgrading

### Via ArgoCD

Update the chart version in `Chart.yaml` and commit the changes. ArgoCD will automatically sync the changes.

### Manual Upgrade

```bash
helm upgrade local-stayozo-hub-vcluster helmcharts/vcluster \
  --namespace vcluster-stayozo-hub \
  -f helmcharts/vcluster/values.yaml
```

## Uninstalling

### Via ArgoCD

Remove the instance's `list` element from `vcluster-as.yaml` and push — ArgoCD prunes the
Application (and, since `preserveResourcesOnDeletion: false`, the namespace with it). Don't
delete the generated `Application` by hand; the ApplicationSet controller just recreates it
on the next reconcile as long as the `list` element is still there.

### Manual Uninstall

```bash
helm uninstall local-stayozo-hub-vcluster -n vcluster-stayozo-hub
```

## References

- [vCluster Documentation](https://www.vcluster.com/docs)
- [Loft Helm Charts](https://charts.loft.sh)
- [ArgoCD ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)

---

## This deployment's configuration

Wraps the official Loft vcluster chart; all values nest under the dependency key.

### Sync configuration

The `sync` block controls what is mirrored between the host and virtual clusters, in both
directions:

- **virtual → host** — resources the vcluster creates that must materialise on the host
- **host → virtual** — host resources made visible inside the vcluster

### HTTPRoute sync — Gateway API from inside the vcluster

Cilium (CNI + the Gateway API dataplane) only runs on the host cluster — a vcluster has no
nodes of its own, so there's no way to run a second Cilium Gateway controller inside it. But
`sync.toHost.pods`/`services` already make vcluster workloads real pods/Services on hub with
real Cilium networking, so the only missing piece is the `HTTPRoute` object itself:

```yaml
customResources:
  httproutes.gateway.networking.k8s.io:
    enabled: true
    patches:
      - path: spec.rules[*].backendRefs[*].name
        reference:
          apiVersion: v1
          kind: Service
```

This generic CRD sync copies any `HTTPRoute` created against the vcluster's own API server up
to the host namespace, where the single shared `cilium-gateway` Gateway
(`helmcharts/cilium-gateway`) reconciles it — same "one Gateway per cluster, every `HTTPRoute`
attaches via `parentRefs`" pattern every other chart uses (see
`helmcharts/airflow/templates/httproute.yaml`). The `reference` patch is required because
vcluster renames synced Services (e.g. `<svc>-x-<ns>-x-wion-hub`); without it `backendRefs.name`
would still hold the tenant's unprefixed name and dangle. `parentRefs` is deliberately **not**
patched — it already names the real host `cilium-gateway`/`cilium-gateway` Gateway, which exists
only on the host, not inside the vcluster.

No per-instance cloudflared or external-dns is needed: both already run once on hub and watch
Gateway API objects cluster-wide, so a tenant HTTPRoute picks up DNS/tunnel exposure for free
once it's synced and accepted.

### Control-plane persistence

Persistence for the vcluster control plane is configured separately from workload storage.

### Registering an instance as its own ArgoCD cluster

`values/wion-hub.yaml` sets `clusterRegistration.enabled: true`, which renders
`templates/argocd-cluster-registration-job.yaml`: a one-shot Job, in the vcluster's own
namespace, that copies the `client-certificate`/`client-key`/`certificate-authority` out of
vcluster's **auto-generated** admin Secret (`vc-<release>`, created by the vcluster chart
itself — not something this repo creates) into a new ArgoCD cluster-registration Secret
(`<release>-cluster`) in the `argocd` namespace, using client-cert `tlsClientConfig` auth
(the same client cert `vcluster connect` uses — this Secret's `token` key is left empty
unless `exportKubeConfig`'s ServiceAccount-token feature is explicitly enabled, which this
chart doesn't do). That's what lets the hub ArgoCD target
`https://<release>.<namespace>.svc.cluster.local` as a destination. The created Secret also
carries `nested-argocd: "true"` — that's what
[`helmcharts/argocd-apps/templates/applicationsets/remote-argocd-as.yaml`](../argocd-apps/templates/applicationsets/remote-argocd-as.yaml)'s
`clusters` generator matches on to actually install a nested ArgoCD there, using
`helmcharts/argocd/values-nested.yaml` as the overlay (disables `devCluster`,
`corednsKubeSystem`, `hubClusterSecret`, and the Gateway HTTPRoute — none of those apply
inside a vcluster). No new file needed per instance; just this one label.

This is deliberately the vcluster's **own** cluster-admin-equivalent client cert, reused
as-is — not a narrower, purpose-minted ServiceAccount token. Same blast radius as running
`vcluster connect`. Only turn this on for an instance that genuinely needs the host ArgoCD
managing workloads inside it.

The Job can't register a vcluster before the vcluster itself has started (the `vc-<release>`
Secret doesn't exist until the syncer comes up), so it polls for up to 5 minutes before
failing — normal on first install, nothing to act on unless it's still failing after that.
