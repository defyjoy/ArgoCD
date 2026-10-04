# 🚀 ArgoCD GitOps Repository

<div align="center">

![ArgoCD](https://img.shields.io/badge/ArgoCD-v3.2.0-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.22+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-3.x-0F1689?style=for-the-badge&logo=helm&logoColor=white)
![GitOps](https://img.shields.io/badge/GitOps-Enabled-00A8CC?style=for-the-badge)

</div>

<div align="center">

> **🎯 Complete Kubernetes Platform**: This repository contains Helm charts, Kubernetes manifests, and ArgoCD configurations for deploying and managing a complete Kubernetes platform using the GitOps approach.

</div>

## 📁 Repository Structure

<div align="center">

### 🏗️ **Complete Repository Architecture** 🏗️

</div>

This repository follows a **GitOps** approach using **ArgoCD** for continuous delivery. The structure is organized to support Helm chart management, application deployment, and comprehensive documentation.

### 📊 Quick Overview

<div align="center">

| Directory | Purpose | Count |
|-----------|---------|-------|
| **helmcharts/** | Helm chart packages | 51 charts |
| **docs/** | Cluster runbooks & architecture notes | 1 runbook + 2 notes |
| **manifests/** | Raw Kubernetes manifests | 5 directories |

</div>

### 📂 Directory Structure

```
ArgoCD/
├── Taskfile.yml                   # ArgoCD bootstrap & cluster helper tasks (run from repo root)
├── scripts/                       # Shell scripts used by Taskfile.yml, one folder per domain
│   ├── argocd/                   # install/uninstall, admin password, app-of-apps, wait-ready
│   ├── cluster/                  # prerequisites, Cilium, Gateway API + Prometheus Operator CRDs
│   ├── vault/                    # init/unseal/status/health + secret seeding
│   ├── helm/                     # repo hygiene: values-comment lint, chart dep cleanup
│   └── git-hooks/                # versioned hooks, symlinked by `task hooks:install`
├── helmcharts/                    # 51 custom Helm charts
│   ├── argocd/                   # GitOps platform
│   ├── argocd-apps/              # App-of-Apps (4 apps, 131 ApplicationSets)
│   ├── istio/                    # Ambient mesh + istio-gateway (9 subcharts)
│   ├── cilium/                   # CNI, kube-proxy replacement, LoadBalancer
│   ├── longhorn/                 # Distributed block storage (CSI)
│   ├── vault/                    # Secrets management
│   ├── cloudflared/              # Cloudflare Tunnel
│   └── [44 more charts...]
├── docs/                          # Cluster runbooks & architecture notes
│   ├── runbooks/                 # register-dev-cluster.md
│   └── istio-cross-cluster-postgresql-architecture.md
├── manifests/                     # Raw Kubernetes manifests
│   ├── awx/                      # AWX instance
│   ├── awx-operator/             # AWX operator
│   ├── cloudnative-pg/           # PostgreSQL cluster examples
│   ├── external-secrets/         # External Secrets configs
│   └── rabbitmq-operator/        # RabbitMQ operator
└── README.md                      # This file
```

### 📚 Detailed Documentation

For comprehensive repository structure details, see:

- **[📁 Complete Repository Structure](https://github.com/Alarmify/alarmify-docs/blob/main/docs/repository/README.md)** - Detailed directory structure, file descriptions, and organization
- **[📦 Helm Charts Documentation](https://github.com/Alarmify/alarmify-docs/blob/main/docs/helm-charts/README.md)** - Complete Helm charts reference with versions, dependencies, and configuration

### 🔑 Key Highlights

- **51 Helm Charts**: Custom charts wrapping official upstream charts
- **4 Applications**: Bootstrap applications for self-management
- **131 ApplicationSets**: Multi-cluster application deployment templates
- **Chart-level docs**: Each chart carries its own `README.md`; platform docs live in [`Alarmify/alarmify-docs`](https://github.com/Alarmify/alarmify-docs)

## 🎯 Getting Started - Complete Cluster Setup from Scratch

<div align="center">

### 🌟 **Complete Cluster Bootstrap Guide** 🌟

</div>

This guide walks you through setting up the entire cluster from scratch, including ArgoCD, Vault, Cloudflared, and all dependencies.

### 📋 Prerequisites

<div align="center">

#### ⚠️ **Required Tools & Access** ⚠️

</div>

<div align="center">

| 🛠️ Tool | 📝 Description | 🔗 Installation |
|---------|---------------|-----------------|
| **☸️ Kubernetes** | Cluster (v1.22+) | [Kubernetes Docs](https://kubernetes.io/docs/setup/) |
| **🔧 kubectl** | Kubernetes CLI | [kubectl Install](https://kubernetes.io/docs/tasks/tools/) |
| **⚓ Helm** | Package manager (3.x+) | [Helm Install](https://helm.sh/docs/intro/install/) |
| **📦 Task** | Task runner (recommended) | [Taskfile.dev](https://taskfile.dev/) |
| **🔐 jq** | JSON processor | `brew install jq` or `apt-get install jq` |
| **🌐 cloudflared** | Cloudflare Tunnel CLI | [Cloudflare Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/) |
| **🔑 htpasswd** | Password hashing | `apache2-utils` or `httpd-tools` |

</div>

<div align="center">

#### 🔐 **Required Accounts & Credentials** 🔐

</div>

<div align="center">

| 🎯 Requirement | 📝 Description | ✅ Status |
|---------------|---------------|-----------|
| **☁️ Cloudflare Account** | Admin access required | ⚠️ Required |
| **🌍 Domain** | Managed by Cloudflare (e.g., `workquark.org`) | ⚠️ Required |
| **🔐 Credential Storage** | Password manager recommended | ⚠️ Recommended |

</div>

<div align="center">

#### ⚙️ **Cluster Requirements** ⚙️

</div>

<div align="center">

| 🎯 Requirement | 📝 Description | 💾 Minimum |
|---------------|---------------|------------|
| **💾 Storage Class** | For Vault persistent volumes | ✅ Required |
| **🔒 Network Policies** | If using network policies | ⚠️ Optional |
| **💻 Resources** | CPU and Memory | 4+ CPU, 8GB+ RAM |

</div>

### 📦 Step 1: Install Prerequisites

<div align="center">

#### 🛠️ **Install Task Runner** 🛠️

</div>

```bash
# macOS
brew install go-task

# Linux
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin

# Windows (PowerShell as Administrator)
choco install go-task
```

#### Install Additional Tools

```bash
# macOS
brew install jq cloudflared httpd  # httpd provides htpasswd

# Linux (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install -y jq cloudflared apache2-utils

# Linux (RHEL/CentOS)
sudo yum install -y jq cloudflared httpd-tools
```

#### Verify Prerequisites

```bash
# Check all tools are installed
kubectl version --client
helm version
task --version
jq --version
cloudflared --version
htpasswd -h 2>&1 | head -1
```

### 🖥️ Step 1.5: Provision the Cluster (Talos + Terraform)

<div align="center">

#### 🌐 **Talos Cluster on Proxmox** 🌐

</div>

> **ℹ️ Expect `NotReady` nodes when this step finishes.** The Talos machine config ships with
> `cni: none` and `proxy.disabled: true`, so a freshly provisioned cluster has **no CNI and no
> kube-proxy** — every node stays `NotReady` and nothing can schedule. **Cilium** is that CNI (and
> also replaces kube-proxy and provides LoadBalancer IPs via LB-IPAM + L2 announcement), and it is
> installed by `task bootstrap` in **Step 2** — the very first thing you run against the new
> cluster. See ADR-009 and the migration plan in the
> [`alarmify-docs`](https://github.com/Alarmify/alarmify-docs) repo
> (`docs/cilium/cilium-migration-plan.md`, `docs/infrastructure/adr-009-cilium-cni-loadbalancer-migration.md`).

The cluster VMs and Talos machine config are **not** managed in this repo — they live in the
sibling **[`defyjoy/proxmox-talos`](https://github.com/defyjoy/proxmox-talos)** repo (local path
`../proxmox-talos`), driven by its own `Taskfile.yml`. Run these from **that** repo:

```bash
cd ../proxmox-talos

# Provision (or update) the management cluster — terraform/envs/management.
# ACTION defaults to `plan`; set ACTION=apply to actually create/update the cluster.
ACTION=apply task management

# Write the management cluster kubeconfig to ~/.kube/talos-management.yaml
task kubeconfig-management
```

**📝 Notes:**
- This Getting Started guide bootstraps the **`management`** cluster. The **`dev`** cluster is not bootstrapped here — it is registered as a *remote* Argo CD target managed by `management`. See **[`docs/runbooks/register-dev-cluster.md`](docs/runbooks/register-dev-cluster.md)**.
- `task --list-all` in `proxmox-talos` shows every available task (`talosconfig`, `talos-schematic`, etc.).

### 🚀 Step 2: Bootstrap the Cluster (Cilium CNI + ArgoCD)

<div align="center">

#### ✅ **Option A: Using Task (Recommended)** ✅

</div>

> **🥇 This is the first thing you run against a freshly provisioned cluster.** `task bootstrap`
> installs **Cilium first** and waits for the nodes to go `Ready` before it touches ArgoCD — there
> is no separate Cilium step to run by hand.

```bash
# Target the management cluster kubeconfig written by proxmox-talos in Step 1.5
export KUBECONFIG=~/.kube/talos-management.yaml

# From repository root (see Taskfile.yml)
# Installs Cilium CNI, then ArgoCD, and configures self-management
task bootstrap
```

This will:
1. ✅ Check prerequisites (kubectl, helm, cluster access)
2. ✅ Install Cilium CNI (Helm, from `helmcharts/cilium` with `values/hub.yaml`) and wait for nodes Ready — **skipped if `daemonset/cilium` is already fully Ready**
3. ✅ Install the prerequisite CRDs — Gateway API + prometheus-operator (`task install-crds`, see Step 3.5)
4. ✅ Install Argo CD via Helm (Git SSH repo from Taskfile vars)
5. ✅ Wait for Argo CD core workloads to be ready (including application controller)
6. ✅ Display admin credentials
7. ✅ Configure Argo CD self-management
8. ✅ Configure App-of-Apps pattern

**Save the admin credentials** displayed at the end — you'll need them to access the ArgoCD UI in
Step 3. If you lose them, `task get-initial-admin-password` reprints them (see Step 3 for the
caveats).

**✅ Verify the Cilium datapath is healthy before continuing:**

```bash
# Nodes should have flipped NotReady → Ready once the Cilium agents came up
kubectl get nodes

# Cilium agent + operator pods Running in kube-system
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get pods -n kube-system -l io.cilium/app=operator

# Full status (install the cilium CLI: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
cilium status --wait

# LoadBalancer IP pool + L2 announcement policy the chart ships (values/<env>.yaml addresses)
kubectl get ciliumloadbalancerippool
kubectl get ciliuml2announcementpolicy
```

> **🔁 Handover to GitOps:** The Cilium Helm release `task bootstrap` creates is the **one-time
> bootstrap** — once ArgoCD is up and the target cluster Secret carries the `cilium: "true"` label,
> the `cilium` ApplicationSet reconciles the same chart continuously. Cilium is the cluster's
> **only** source of LoadBalancer IPs — see §4.2 for configuring the address pool.
>
> **After that handover, Helm must not touch Cilium again.** ArgoCD owns the DaemonSet's fields, so
> a `helm upgrade` loses a server-side-apply conflict against the `argocd-controller` field manager:
>
> ```
> Upgrade "cilium" failed: conflict occurred while applying object kube-system/cilium
> apps/v1, Kind=DaemonSet: Apply failed with 3 conflicts: conflicts with "argocd-controller"
> ```
>
> That leaves the release `failed` and aborts bootstrap at its *first* step — on a cluster whose
> datapath was perfectly healthy. `task install-cilium` therefore **skips the Helm install whenever
> `daemonset/cilium` is already fully Ready**, which makes `task bootstrap` safe to re-run. A
> `failed` release record sitting on a healthy DaemonSet is expected post-handover and is inert;
> ArgoCD is the reconciler. Override with `CILIUM_FORCE_INSTALL=true` for a genuine
> ArgoCD-down recovery.

<div align="center">

#### 🔧 **Option B: Manual Installation** 🔧

</div>

```bash
# Cilium first — nodes stay NotReady and nothing schedules until the CNI is up.
# The Cilium subchart is vendored in charts/, so no `helm dependency update` is needed.
# management cluster → values/hub.yaml (environment: hub).
# For the dev cluster, follow docs/runbooks/register-dev-cluster.md (uses values/dev.yaml).
cd helmcharts/cilium

helm upgrade --install cilium . \
  --namespace kube-system \
  --create-namespace \
  --values values.yaml \
  --values values/hub.yaml \
  --wait \
  --timeout 15m

# Nodes should flip NotReady → Ready before continuing
kubectl get nodes
```

```bash
# Navigate to ArgoCD chart directory
cd ../argocd

# Update Helm dependencies
helm dependency update

# Install ArgoCD.
#
#   -f values-bootstrap.yaml  → FIRST INSTALL ONLY. Disables the three resources plain Helm
#                               cannot create on a brand-new cluster (see the warning below).
#                               Drop this flag on every later upgrade.
#   --set-file / --set        → wires the Git SSH deploy key + repo URL into
#                               argo-cd.configs.repositories, so ArgoCD can pull this private
#                               repo. Without it, self-management and app-of-apps below will
#                               sync-fail with a repository authentication error.
helm upgrade --install argocd . -n argocd --create-namespace \
  -f values-bootstrap.yaml \
  --set-file "argo-cd.configs.repositories.defyjoy-argocd.sshPrivateKey=$HOME/.ssh/github" \
  --set "argo-cd.configs.repositories.defyjoy-argocd.url=git@github.com:defyjoy/ArgoCD.git"

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-applicationset-controller -n argocd
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Configure self-management
kubectl apply -f ../argocd-apps/templates/applications/argocd.yaml

# Configure app-of-apps pattern
kubectl apply -f ../argocd-apps/templates/applications/argocd-apps.yaml
```

> **⚠️ `values-bootstrap.yaml` is first-install-only.** On a fresh cluster the full `values.yaml`
> renders three resources plain Helm cannot create, and the install fails without this overlay:
>
> | Resource | Why it fails on a fresh cluster |
> |---|---|
> | dev-cluster `ExternalSecret` (`devCluster.enabled`) | External Secrets CRDs not installed yet |
> | `argocd-server` `HTTPRoute` (`argo-cd.server.httproute.enabled`) | Gateway API CRDs not installed yet |
> | `kube-system/coredns` ConfigMap (`corednsKubeSystem.enabled`) | Already exists (Talos-created) — Helm refuses to adopt it |
>
> The app-of-apps command above installs `external-secrets-operator`; ArgoCD then self-heals the
> ExternalSecret from git and **adopts** the existing coredns ConfigMap — the adoption Helm refused
> (see *ArgoCD is not `helm upgrade`* in `CLAUDE.md`). The HTTPRoute needs the Gateway API CRDs from
> **Step 3.5**, which the manual path does not install for you.
> **Drop the `-f values-bootstrap.yaml` flag on every subsequent upgrade**, or you will silently
> disable those three resources again.

### 🌐 Step 3: Access ArgoCD UI

<div align="center">

#### 🎨 **Access the ArgoCD Web Interface** 🎨

</div>

**Retrieve the admin password 🔑**

`task bootstrap` already printed this at the end of Step 2. To print it again at any time:

```bash
# Using Task (from repository root)
task get-initial-admin-password

# Or manually
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

> **⚠️ This reads `argocd-initial-admin-secret`, which is only meaningful right after install.**
> Two ways it stops being the real password:
>
> - **It's gone.** `argocd account update-password` (the CLI path below) deletes the secret, and it
>   is never recreated. The task then exits non-zero — the original plaintext is unrecoverable.
> - **It's stale — the dangerous one.** `task change-admin-password` and `task reset-admin-password`
>   patch `argocd-secret` directly and leave `argocd-initial-admin-secret` untouched, so this task
>   keeps happily printing the **old** password long after it stopped working.
>
> Either way, set a known password with `task reset-admin-password` (prints a generated one, or pass
> `NEW_PASSWORD=...`) or `task change-admin-password` (prompts interactively) rather than trusting
> this output on a cluster that has been up for a while.

**Open the UI 🎨**

```bash
# Using Task (from repository root)
task port-forward

# Or manually
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Access at: http://localhost:8080
# Username: admin
# Password: from `task get-initial-admin-password` above
```

**Change Admin Password (Recommended):**

```bash
# Using Task (from repository root)
task change-admin-password

# Or via ArgoCD CLI
argocd login localhost:8080 --username admin --insecure
argocd account update-password
```

### 🧩 Step 3.5: Install Prerequisite CRDs

<div align="center">

#### 🧬 **Gateway API + prometheus-operator CRDs** 🧬

</div>

`task bootstrap` already ran this (Step 2, item 3). Run it standalone on a cluster that was
bootstrapped before this step existed, or any time an Application fails with a "could not find
&lt;kind&gt;" error:

```bash
task install-crds
```

Both halves are idempotent server-side applies, so re-running on a live cluster is safe.

**Why these can't be left to a chart 🔍**

Argo CD fails an entire Application when a manifest references a kind the API server does not serve
yet — the symptom is a `SyncFailed` like:

```
The Kubernetes API could not find gateway.networking.k8s.io/HTTPRoute for requested resource
vault/vault. Make sure the "HTTPRoute" CRD is installed on the destination cluster.
```

| CRD group | Supplied by | Why it is installed here instead |
|---|---|---|
| `gateway.networking.k8s.io` | *nothing in this repo* | `istio-base` ships only Istio's own CRDs; Istio expects Gateway API out of band. **18 charts** template an `HTTPRoute` and **4** a `TCPRoute`. |
| `monitoring.coreos.com` | `kube-prometheus-stack` | That chart's own templates carry ExternalSecrets resolving against **Vault (wave 3)** and **external-secrets (wave 4)**, so it cannot be moved first — and below `cilium` its pods cannot schedule at all. |

> **⚠️ The Gateway API install uses the `experimental` channel deliberately.** The `standard`
> channel has **no `TCPRoute`**, which `cloudnative-pg`, `victoria-metrics`, `nats` and `tempo` all
> template. Pinned in `Taskfile.yml` as `GATEWAY_API_VERSION` / `GATEWAY_API_CHANNEL`.

> **⚠️ Both installs must be server-side applies (`kubectl apply --server-side`).** A client-side
> apply stores the whole manifest in the `last-applied-configuration` annotation, which the API
> server caps at **262144 bytes**. The `httproutes` CRD is ~533 KB, and six of the ten
> prometheus-operator CRDs are 590–815 KB — a plain `kubectl apply -f` fails outright with
> `metadata.annotations: Too long`. The scripts already do this; it matters if you apply by hand.

The prometheus-operator CRDs are read from the **vendored** chart
(`helmcharts/kube-prometheus-stack/charts/kube-prometheus-stack-*.tgz`), not fetched from the
network, so the version installed is by construction the one Argo CD is about to deploy.

**✅ Verify:**

```bash
kubectl get crd | grep gateway.networking.k8s.io   # expect 10
kubectl get crd | grep monitoring.coreos.com       # expect 10
```

### 🏗️ Step 4: Deploy Core Infrastructure (Phase 1)

This step deploys the foundational infrastructure components that form the base layer of your cluster. These components must be deployed **before** Vault and Cloudflared because they provide essential services that those components depend on.

**Install order (this guide):** the **Istio ambient stack first** (`istio-base` → `istiod` → `istio-cni` → `ztunnel` → `istio-gateway`, sync waves 10–14), then **Longhorn** and the rest. LoadBalancer IPs come from **Cilium LB-IPAM**, which is installed by the bootstrap in **Step 2** — the `istio-gateway-istio` `LoadBalancer` Service gets its **`EXTERNAL-IP`** as soon as the cluster's address pool contains a free address (**§4.2**).

> **Note:** Envoy Gateway was the ingress here until **2026-07-12** and has been fully removed. `istio-gateway` (namespace `istio-system`, Service `istio-gateway-istio`) now terminates all north-south traffic.

#### Overview: Why These Components Are Needed

<div align="center">

#### 📊 **Architecture Dependency Chain** 📊

</div>

```
┌─────────────────────────────────────────┐
│  🕸️ Istio ambient + istio-gateway       │
│  Gateway API — install first (see 4.1)  │
│  Waves 10-14, all in istio-system       │
│  Service: istio-gateway-istio           │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  ⚖️ Cilium LB-IPAM (from Step 2)        │
│  LoadBalancer IP for istio-gateway &c.  │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────---┐
│  🐂 Longhorn                               │
│  Persistent storage for stateful workloads │
└────────────────────────────────────────--─-┘
              │
              ▼
┌─────────────────────────────────────────----┐
│  🔒 Cert-Manager                            │
│  TLS certificates (optional but recommended)│
└────────────────────────────────────────----─┘
              │
              ▼
┌─────────────────────────────────────────-┐
│  🗄️ Vault                                │
│  Secrets management (requires storage)   │
└─────────────────────────────────────────-┘
              │
              ▼
┌─────────────────────────────────────────┐
│  🔐 External Secrets                    │
│  Secret sync (requires Vault)           │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────-------------┐
│  🌐 Cloudflared                                      │
│  Tunnel (requires istio-gateway + External Secrets)  │
└────────────────────────────────────────-------------─┘
```

<div align="center">

#### 🎯 **Component Breakdown** 🎯

</div>

<div align="center">

| # | 📦 Component | 🎯 Purpose | 🔗 Dependencies | 👥 Used By |
|---|------------|-----------|----------------|-----------|
| **1️⃣** | **🕸️ Istio (ambient) + istio-gateway** | Ambient mesh data plane and the Gateway API ingress — CRDs, control plane, `Gateway` / `HTTPRoute` | Kubernetes cluster + Cilium; a **Cilium LB-IPAM address** for the gateway `EXTERNAL-IP` | Cloudflared, all apps (via HTTPRoute) |
| **2️⃣** | **⚖️ Cilium LB-IPAM** | LoadBalancer IPs on bare metal (address pool for `istio-gateway-istio`) | Cilium, installed by the bootstrap in **Step 2** | istio-gateway Service, other `LoadBalancer` Services |
| **3️⃣** | **🐂 Longhorn** | Dynamic persistent volume provisioning (CSI) | None (can run parallel with Istio) | Vault, databases, stateful apps |
| **4️⃣** | **🔒 Cert-Manager** | Automatic TLS certificate provisioning | None (optional) | Applications requiring TLS |

</div>

<div align="center">

#### 📝 **Detailed Component Descriptions** 📝

</div>

**1️⃣ Istio ambient mesh + istio-gateway (Gateway API)**
- **🎯 What it does**: `istio-base` installs the CRDs and cluster RBAC, `istiod` the ambient-profile control plane, `istio-cni` the node agent, `ztunnel` the per-node L4 data-plane proxy, and `istio-gateway` the Gateway API ingress. All five land in **`istio-system`** (charts under **`helmcharts/istio/`**).
- **⚠️ Why it's first in this quickstart**: The control plane and Gateway API objects can come up at any time; the gateway's `LoadBalancer` Service stays **`Pending`** until the Cilium address pool has a free address for it (**§4.2**).
- **🔗 Dependency**: Cilium (Step 2); a free address in the **Cilium LB-IPAM pool** for the gateway's external IP
- **👥 Used by**: Cloudflared (routes tunnel traffic here), all applications (via HTTPRoute/TCPRoute resources)

**2️⃣ Cilium LB-IPAM (Load Balancer)**
- **🎯 What it does**: Assigns external IPs to `LoadBalancer` Services on bare metal (cloud clusters usually do not need it), and announces them on the LAN over L2/ARP
- **⚠️ Why it's already there**: Cilium is installed by `task bootstrap` in **Step 2** — before ArgoCD in the same task — because it is also the CNI. The LoadBalancer role comes with it — there is no separate load-balancer component to install here, only a pool to configure (**§4.2**).
- **✅ Dependency**: Cilium (Step 2)
- **👥 Used by**: `istio-gateway-istio` Service, other services that need external IPs

**3️⃣ Longhorn (Distributed Block Storage)**
- **🎯 What it does**: Provides dynamic persistent volume provisioning (CSI) for stateful applications
- **⚠️ Why it's needed**: Vault requires persistent storage (PersistentVolumes) to store its encrypted data, audit logs, and Raft consensus data. Without storage, Vault cannot function properly
- **✅ Dependency**: None (can deploy in parallel once Istio is in place)
- **👥 Used by**: Vault (for data persistence), databases, and any stateful application

**4️⃣ Cert-Manager (TLS Certificates)**
- **🎯 What it does**: Automatically provisions and manages TLS certificates from Let's Encrypt or other certificate authorities
- **⚠️ Why it's needed**: 
     - Enables HTTPS/TLS termination at the Gateway level
     - Automatically renews certificates before expiration
     - Required for production-grade security
   - **Dependency**: None (optional, but recommended)
   - **Used by**: istio-gateway (for TLS termination), applications requiring HTTPS

**Why This Order Matters:**

1. **Istio first, in wave order**: `istio-base` (10) installs the CRDs every later chart references, `istiod` (11) the control plane, `istio-cni` (12) and `ztunnel` (13) the ambient data plane, `istio-gateway` (14) the ingress. Skipping ahead fails on missing CRDs. The gateway `LoadBalancer` may wait for a free pool address; in-cluster routing and Cloudflared can still use the Service DNS name.

2. **Cilium LB-IPAM pool (§4.2)**: Supplies an **`EXTERNAL-IP`** for `istio-gateway-istio` (and other Services) once the address pool includes an address for it.

3. **Longhorn → Vault**: Vault needs storage classes before it can bind PersistentVolumes.

4. **istio-gateway → Cloudflared**: Cloudflared needs a Gateway-backed endpoint to send traffic to.

5. **Cert-Manager → TLS**: Optional; provision early if you want TLS on listeners.

**What Happens If You Skip or Deploy Out of Order:**

- **Skip the LB address pool** (on bare metal): `istio-gateway-istio` stays **`Pending`** until Cilium has a free address to assign (or you change Service type).
- **Skip Longhorn**: Vault pods will fail to start due to missing PersistentVolumes
- **Skip istio-gateway**: Cloudflared will have no backend service to route to, tunnel will connect but traffic won't reach applications
- **Deploy Vault before Longhorn**: Vault StatefulSet will fail to create PersistentVolumes, pods won't start
- **Deploy Cloudflared before istio-gateway**: Cloudflared will start but won't be able to route traffic anywhere

**Deployment Strategy:**

- **Argo CD (the only supported path)**: label the cluster and let the sync waves order things — Istio (**§4.1**, waves 10–14) → Cilium LB address pool (**§4.2**) → Longhorn (**§4.3**); **Cert-Manager** (**§4.4**) when needed. Cilium already carries the `cilium: "true"` label from the Step 2 bootstrap, so the pool reconciles on wave `-5`, well ahead of the gateway; the Service picks up its IP as soon as the pool covers it.

Now proceed with the individual deployment steps:

<div align="center">

#### 1️⃣ **4.1: Deploy Istio (ambient mesh + Gateway API ingress)** 1️⃣

</div>

Five ApplicationSets, applied in sync-wave order. Each gate is a separate cluster label — this preserves the phased rollout, so label them in order and let each become Healthy before adding the next:

```bash
# Wave 10 — CRDs & cluster RBAC
kubectl label secret -n argocd cluster-local istio-base=true

# Wave 11 — control plane (ambient profile)
kubectl label secret -n argocd cluster-local istiod=true

# Wave 12 — CNI node agent
kubectl label secret -n argocd cluster-local istio-cni=true

# Wave 13 — ambient per-node L4 proxy
kubectl label secret -n argocd cluster-local ztunnel=true

# Wave 14 — Gateway API ingress
kubectl label secret -n argocd cluster-local istio-gateway=true
```

> **⚠️ The Istio ApplicationSets also gate on `environment in (dev, hub)`.** A cluster without an `environment` label generates no Application at all, no matter how many component labels it carries.

```bash
# Everything lands in istio-system
kubectl wait --for=condition=ready --timeout=300s -n istio-system --all pods

# Verify the Gateway resource is created
kubectl get gateway -n istio-system

# Gateway Service (EXTERNAL-IP appears once the Cilium LB pool covers it — §4.2)
kubectl get svc -n istio-system istio-gateway-istio
```

The Service name is stable — **`istio-gateway-istio.istio-system.svc.cluster.local:80`**. You will need it for Cloudflared in **§7.5**.

For the full mesh rollout (including the multi-cluster east-west and cacerts phases, which are *not* part of this quickstart), see the [Istio deployment runbook](https://github.com/Alarmify/alarmify-docs/blob/main/docs/istio/istio-deployment-runbook.md).

<div align="center">

#### 2️⃣ **4.2: Configure the Cilium LoadBalancer IP pool** 2️⃣

</div>

On bare metal, **Cilium LB-IPAM** assigns IPs to `LoadBalancer` Services (including `istio-gateway-istio`) and announces them on the LAN over L2/ARP. Cilium itself is already running from the **Step 2** bootstrap — there is nothing extra to install, only an address pool to declare.

```bash
# Cilium is already up from the Step 2 bootstrap — confirm the LB machinery is present
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get ciliumloadbalancerippool
kubectl get ciliuml2announcementpolicy
```

**Add an address for the gateway:**

The pool is GitOps-managed, per cluster, in the `cilium` chart's overlay — **not** applied by hand. Edit the overlay for the target cluster (`helmcharts/cilium/values/hub.yaml` for management, `values/dev.yaml` for dev), add a free `/32`, then commit and push:

```yaml
loadBalancer:
  addresses:
    - 192.168.3.10/32    # istio-gateway (north-south)
    - 192.168.3.11/32    # coredns-lan (kube-system)
    - 192.168.3.14/32    # <-- e.g. a new LoadBalancer Service
```

> **⚠️ Addresses must be disjoint across clusters** — dev and management share the `192.168.0.0/16` LAN. Confirm a candidate is genuinely free against live `LoadBalancer` Services on **both** clusters *and* `proxmox-talos`'s Terraform static-host inventory before using it; a collision surfaces as `can't change sharing key ... address also in use by ...` at sync time.

Once the `cilium` Application syncs, verify the allocation:

```bash
kubectl get ciliumloadbalancerippool -o wide

# Should show an EXTERNAL-IP assigned by Cilium LB-IPAM
kubectl get svc -n istio-system istio-gateway-istio
```

A Service can pin a specific address with `spec.loadBalancerIP` (or, for Gateway API, `Gateway.spec.addresses`, which propagates to it) as long as the pool contains that `/32`.

<div align="center">

#### 3️⃣ **4.3: Deploy Longhorn (Storage)** 3️⃣

</div>

```bash
# Label cluster for Longhorn
kubectl label secret -n argocd cluster-local longhorn=true

# Wait for the CSI stack to come up
kubectl wait --for=condition=ready --timeout=600s -n longhorn-system --all pods

# Verify the storage class is created
kubectl get storageclass | grep longhorn
```

<div align="center">

#### 4️⃣ **4.4: Deploy Cert-Manager (TLS Certificates - Optional)** 4️⃣

</div>

Cert-Manager is optional but recommended for TLS certificate management:

```bash
# Label cluster for Cert-Manager
kubectl label secret -n argocd cluster-local cert-manager=true

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready --timeout=300s \
  -n cert-manager --all pods
```

**Note:** TLS termination is handled at the Gateway level. TLS certificates are managed by cert-manager and referenced via Gateway TLS secrets in the `istio-system` namespace.

### 🔐 Step 5: Deploy and Configure HashiCorp Vault

<div align="center">

#### 🗄️ **Secrets Management Setup** 🗄️

</div>

Vault is critical for secret management and is required before External Secrets and Cloudflared.

#### 5.1: Deploy Vault

```bash
# Label cluster for Vault
kubectl label secret -n argocd cluster-local hashicorp-vault=true

# Wait for Vault StatefulSet to be ready
kubectl wait --for=condition=ready --timeout=300s \
  statefulset/local-vault -n vault
```

#### 5.2: Initialize and Unseal Vault

**Using Task (Recommended):**

```bash
# From repository root — run complete Vault management workflow
task hashicorp-vault
```

This will:
1. ✅ Check cluster connectivity
2. ✅ Check Vault StatefulSet status
3. ✅ Initialize Vault (if not already initialized)
4. ✅ Unseal all Vault pods
5. ✅ Display root token and unseal keys

**⚠️ CRITICAL: Save the displayed credentials securely!**
- Root token: `hvs.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- 5 Unseal keys (need 3 to unseal)
- File saved: `hashicorp-vault-init.json` (in bootstrap directory)

**Manual Initialization (Alternative):**

```bash
# Initialize Vault (first pod only)
kubectl exec -n vault local-vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > hashicorp-vault-init.json

# Extract unseal keys and root token
cat hashicorp-vault-init.json | jq -r '.unseal_keys_b64[]'
cat hashicorp-vault-init.json | jq -r '.root_token'

# Unseal vault-0 (need 3 keys)
kubectl exec -n vault local-vault-0 -- vault operator unseal <key1>
kubectl exec -n vault local-vault-0 -- vault operator unseal <key2>
kubectl exec -n vault local-vault-0 -- vault operator unseal <key3>

# Unseal vault-1
kubectl exec -n vault local-vault-1 -- vault operator unseal <key1>
kubectl exec -n vault local-vault-1 -- vault operator unseal <key2>
kubectl exec -n vault local-vault-1 -- vault operator unseal <key3>

# Unseal vault-2
kubectl exec -n vault local-vault-2 -- vault operator unseal <key1>
kubectl exec -n vault local-vault-2 -- vault operator unseal <key2>
kubectl exec -n vault local-vault-2 -- vault operator unseal <key3>

# Verify all pods are unsealed
kubectl exec -n vault local-vault-0 -- vault status
kubectl exec -n vault local-vault-1 -- vault status
kubectl exec -n vault local-vault-2 -- vault status
```

#### 5.3: Create Vault Token Secret for External Secrets

```bash
# Using Task (from repository root)
task hashicorp-vault-create-secret

# Or manually
ROOT_TOKEN=$(cat hashicorp-vault-init.json | jq -r '.root_token')
kubectl create secret generic vault-token \
  --from-literal=token="$ROOT_TOKEN" \
  --namespace=external-secrets
```

#### 5.4: Verify Vault Access

```bash
# Port forward to Vault UI
kubectl port-forward -n vault svc/vault 8200:8200

# Access at: https://localhost:8200
# Login with root token from Step 5.2

# Or test via CLI
kubectl exec -n vault local-vault-0 -- vault status
kubectl exec -n vault local-vault-0 -- vault kv list secret/
```

### 🔐 Step 6: Deploy External Secrets Operator

External Secrets Operator syncs secrets from Vault to Kubernetes.

#### 6.1: Deploy External Secrets

```bash
# Label cluster for External Secrets
kubectl label secret -n argocd cluster-local external-secrets-operator=true

# Wait for External Secrets to be ready
kubectl wait --for=condition=ready --timeout=300s \
  -n external-secrets --all pods
```

#### 6.2: Deploy Vault SecretStore

```bash
# Deploy the Vault SecretStore (connects External Secrets to Vault)
kubectl apply -f helmcharts/external-secrets/templates/vault-secretstore.yaml

# Verify SecretStore is ready
kubectl get clustersecretstore vault-secretstore
kubectl describe clustersecretstore vault-secretstore
```

#### 6.3: Verify External Secrets Integration

```bash
# Test by creating a test secret in Vault
kubectl exec -n vault local-vault-0 -- vault kv put secret/test \
  username="testuser" \
  password="testpass"

# Create ExternalSecret to sync it
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-secretstore
    kind: ClusterSecretStore
  target:
    name: test-kubernetes-secret
  data:
    - secretKey: username
      remoteRef:
        key: test
        property: username
    - secretKey: password
      remoteRef:
        key: test
        property: password
EOF

# Verify secret was created
kubectl get secret test-kubernetes-secret -n default
kubectl describe externalsecret test-secret -n default
```

### 🌐 Step 7: Setup Cloudflare Tunnel (Cloudflared) 🌐

Cloudflared provides secure connectivity to your cluster via Cloudflare's network without exposing public IPs.

#### 7.1: Create Cloudflare API Token 🔑

1. 🌐 **Login** to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 👤 **Navigate** to "My Profile" → "API Tokens"
3. ➕ **Click** "Create Token"
4. ⚙️ **Use** "Edit zone DNS" template or create custom token with:
   - **Zone Permissions**: `Zone:Read`, `DNS:Edit`
   - **Account Permissions**: `Zone:Read`
   - **Zone Resources**: Include your domain (e.g., `workquark.org`)
5. 📋 **Copy** the token immediately (you won't see it again)
6. 🔒 **Store** securely in your password manager

**📚 For detailed instructions, see:** [`https://github.com/Alarmify/alarmify-docs/blob/main/docs/cloudflare/CLOUDFLARE-API-TOKEN-GUIDE.md`](https://github.com/Alarmify/alarmify-docs/blob/main/docs/cloudflare/CLOUDFLARE-API-TOKEN-GUIDE.md)

#### 7.2: Store Cloudflare API Token in Vault 🗄️

Put the token in `.env` at the repo root — gitignored, and the template is `.env.example`:

```bash
cp .env.example .env
# then edit .env:
#   CLOUDFLARE_API_TOKEN=your-cloudflare-api-token-here
```

`task provision-vault-secrets` (step 7.4) reads it from there and writes it to
`kv/alarmify/<env>/cloudflared/token`, verifying it against the Cloudflare API first.
Nothing else needs to be done here — do not run `vault kv put` by hand.

#### 7.3: Generate Cloudflare Tunnel Credentials 🔐

```bash
# Login to Cloudflare (opens browser for authentication)
cloudflared tunnel login

# Create a new tunnel (replace 'proxmox-rke2' with your tunnel name)
cloudflared tunnel create proxmox-rke2

# This generates two files in ~/.cloudflared/:
# - <tunnel-id>.json (credentials file)
# - cert.pem (certificate file)

# List your tunnels
cloudflared tunnel list
```

**📁 Generated Files:**
- 📄 `~/.cloudflared/<tunnel-id>.json` - Tunnel credentials (JSON format)
- 🔒 `~/.cloudflared/cert.pem` - Certificate file (PEM format)

#### 7.4: Seed the Vault Secrets 🗄️

One task writes both the tunnel credentials (from `~/.cloudflared`) and the Cloudflare API
token (from `.env`, step 7.2):

```bash
task provision-vault-secrets                # management cluster -> kv/alarmify/hub/cloudflared/*
task provision-vault-secrets VAULT_ENV=dev  # dev cluster        -> kv/alarmify/dev/cloudflared/*
```

It runs `vault kv put` **inside** the Vault pod over `kubectl exec`, which is what makes it
usable at this point in the bootstrap: cloudflared cannot serve `vault.workquark.org` until it
has the very credentials being seeded, so the public Vault endpoint is unreachable exactly when
it is needed. Secrets are streamed over the exec stdin — never written to the pod filesystem,
never passed as command arguments.

It also refuses to write credentials whose `TunnelID` belongs to the other cluster. Seeding one
cluster's credentials under the other's path puts both clusters on one tunnel, and Cloudflare
then answers hostnames from the wrong cluster with empty-body 404s while every pod looks healthy.

**✅ Verification:** the task reads both paths back and prints the version and field sizes it
wrote. If it does not, treat the seed as failed.

#### 7.5: Configure Cloudflared Values ⚙️

**Step 1: Confirm the gateway Service 🔍**

```bash
kubectl get svc -n istio-system istio-gateway-istio
# Origin for every tunnel route:
#   http://istio-gateway-istio.istio-system.svc.cluster.local:80
```

**Step 2: Update Cloudflared Values 📝**

Per-hostname routes live in the environment overlay, not the base values — edit `helmcharts/cloudflared/values/hub.yaml` (management) or `values/dev.yaml` (dev). The base `helmcharts/cloudflared/values.yaml` intentionally ships only the `http_status:404` catch-all.

```yaml
cloudflared:
  ingress:
    - hostname: "vault.workquark.org"
      service: http://istio-gateway-istio.istio-system.svc.cluster.local:80
    - service: http_status:404
```

The tunnel name lives in `values.yaml` under `cloudflared.tunnelConfig.name`.

**⚠️ Important:** `tunnelConfig.name` is cosmetic — cloudflared reads the tunnel **ID from `credentials.json`**, which comes from Vault via ExternalSecret (`externalSecrets.vaultPath`). Two clusters pointed at the same Vault path will both connect to the same tunnel and race for every hostname. Keep dev and management on separate Vault paths and separate tunnels.

#### 7.6: Deploy Cloudflared 🚀

```bash
# Label cluster for Cloudflared
kubectl label secret -n argocd cluster-local cloudflared=true

# Wait for Cloudflared to be ready
kubectl wait --for=condition=ready --timeout=300s \
  -n cloudflared --all pods

# Verify ExternalSecret created the credentials secret
kubectl get secret cloudflared-credentials -n cloudflared
kubectl get externalsecret cloudflared-credentials -n cloudflared

# Check Cloudflared logs
kubectl logs -n cloudflared -l app.kubernetes.io/name=cloudflared --tail=50
```

**✅ Verification Checklist:**
- ✅ Cloudflared pods are running
- ✅ `cloudflared-credentials` secret exists
- ✅ ExternalSecret status shows "Synced"
- ✅ Logs show successful tunnel connection

#### 7.7: Configure DNS Records (Optional) 🌍

If you want to route specific domains through the tunnel:

```bash
# Route DNS to your tunnel (wildcard)
cloudflared tunnel route dns proxmox-rke2 *.workquark.org

# Or route specific subdomains
cloudflared tunnel route dns proxmox-rke2 argocd.workquark.org
cloudflared tunnel route dns proxmox-rke2 vault.workquark.org
```

**📋 DNS Routing Options:**
- 🌐 **Wildcard**: `*.workquark.org` - Routes all subdomains
- 🎯 **Specific**: `argocd.workquark.org` - Routes only specific subdomain
- 🔄 **Multiple**: Route multiple subdomains individually

### 🌍 Step 8: Deploy External DNS (Optional but Recommended)

External DNS automatically manages DNS records in Cloudflare.

#### 8.1: Create ExternalSecret for Cloudflare API Token

The ExternalSecret should already be configured. Verify it exists:

```bash
# Check ExternalSecret
kubectl get externalsecret cloudflare-api-token -n external-dns

# If it doesn't exist, create it:
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api-token
  namespace: external-dns
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-secretstore
    kind: ClusterSecretStore
  target:
    name: cloudflare-api-token
  data:
    - secretKey: api-token
      remoteRef:
        key: cloudflare/api-token
        property: token
EOF
```

#### 8.2: Deploy External DNS

```bash
# Label cluster for External DNS
kubectl label secret -n argocd cluster-local external-dns=true

# Wait for External DNS to be ready
kubectl wait --for=condition=ready --timeout=300s \
  -n external-dns --all pods

# Verify secret was created
kubectl get secret cloudflare-api-token -n external-dns

# Check External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50
```

### 📊 Step 9: Deploy Monitoring Stack (Optional)

```bash
# Label cluster for Prometheus Stack
kubectl label secret -n argocd cluster-local kube-prometheus-stack=true

# Wait for Prometheus to be ready
kubectl wait --for=condition=ready --timeout=300s \
  -n monitoring --all pods

# Access Grafana (if ingress configured)
# Or port-forward:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Default credentials: admin / prom-operator
```

### ✅ Step 10: Verify Complete Setup

#### Check All Applications

```bash
# Using Task (from repository root)
task status

# Or manually
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
```

#### Verify Core Services

```bash
# Check ArgoCD
kubectl get pods -n argocd

# Check Istio (control plane, ambient data plane, and the gateway)
kubectl get pods -n istio-system
kubectl get gateway -n istio-system
kubectl get svc -n istio-system istio-gateway-istio

# Check Cilium (CNI + LoadBalancer)
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get ciliumloadbalancerippool

# Check Vault
kubectl get pods -n vault
kubectl exec -n vault local-vault-0 -- vault status

# Check External Secrets
kubectl get pods -n external-secrets

# Check Cloudflared
kubectl get pods -n cloudflared
kubectl get externalsecret cloudflared-credentials -n cloudflared

# Check External DNS
kubectl get pods -n external-dns

# Check HTTPRoutes (Gateway API resources)
kubectl get httproute --all-namespaces
```

#### Test Secret Sync

```bash
# Create a test secret in Vault
kubectl exec -n vault local-vault-0 -- vault kv put secret/test-app \
  database_url="postgresql://db:5432/app" \
  api_key="test-api-key-123"

# Create ExternalSecret
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-app-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-secretstore
    kind: ClusterSecretStore
  target:
    name: test-app-kubernetes-secret
  data:
    - secretKey: database_url
      remoteRef:
        key: test-app
        property: database_url
    - secretKey: api_key
      remoteRef:
        key: test-app
        property: api_key
EOF

# Verify secret was created
kubectl get secret test-app-kubernetes-secret -n default
kubectl get secret test-app-kubernetes-secret -n default -o jsonpath='{.data}' | jq
```

### 📋 Required Variables and Secrets Summary

**Vault Credentials (from Step 5.2):**
- ✅ Root Token: `hvs.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- ✅ 5 Unseal Keys (Base64 encoded)
- ✅ File: `hashicorp-vault-init.json` (stored in `helmcharts/argocd/bootstrap/`)

**Cloudflare Credentials:**
- ✅ API Token: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` (40 characters)
- ✅ Tunnel Name: `proxmox-rke2` (or your custom name)
- ✅ Tunnel ID: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (UUID)
- ✅ Certificate PEM: `-----BEGIN CERTIFICATE-----...`
- ✅ Credentials JSON: `{"AccountTag":"...","TunnelSecret":"...","TunnelID":"..."}`

**ArgoCD Credentials:**
- ✅ Admin Username: `admin`
- ✅ Admin Password: (from initial secret or changed password)

**Configuration Values:**
- ✅ Domain: `workquark.org` (update in values.yaml files)
- ✅ Storage Class: `longhorn` (or your storage class)
- ✅ Gateway Service: `istio-gateway-istio.istio-system.svc.cluster.local:80` (used in `helmcharts/cloudflared/values/<environment>.yaml`)
- ✅ LoadBalancer IP Pool: addresses for `istio-gateway-istio` (update in `helmcharts/cilium/values/<environment>.yaml`)

### 🔍 Troubleshooting

#### Vault Not Unsealing

```bash
# Check Vault status
kubectl exec -n vault local-vault-0 -- vault status

# Re-run unseal task (from repository root)
task hashicorp-vault-unseal

# Or manually unseal
kubectl exec -n vault local-vault-0 -- vault operator unseal <key1>
kubectl exec -n vault local-vault-0 -- vault operator unseal <key2>
kubectl exec -n vault local-vault-0 -- vault operator unseal <key3>
```

#### External Secrets Not Syncing

```bash
# Check External Secrets logs
kubectl logs -n external-secrets deployment/external-secrets --tail=100

# Check SecretStore status
kubectl describe clustersecretstore vault-secretstore

# Verify vault-token secret exists
kubectl get secret vault-token -n external-secrets

# Test Vault connectivity
kubectl exec -n vault local-vault-0 -- vault status
```

#### Cloudflared Not Connecting 🔌

```bash
# Check Cloudflared logs
kubectl logs -n cloudflared -l app.kubernetes.io/name=cloudflared --tail=100

# Verify credentials secret exists
kubectl get secret cloudflared-credentials -n cloudflared

# Check ExternalSecret status
kubectl describe externalsecret cloudflared-credentials -n cloudflared

# Verify tunnel exists in Cloudflare
cloudflared tunnel list
```

**🔍 Common Issues:**
- ❌ **Missing credentials**: ExternalSecret not synced from Vault
- ❌ **Wrong tunnel**: `credentials.json` in Vault points at a different tunnel than you expect (see §7.5)
- ❌ **Tunnel not created**: Tunnel doesn't exist in Cloudflare dashboard
- ❌ **Network issues**: Firewall blocking Cloudflare connections

#### Applications Not Deploying

```bash
# Check Application status
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# Check cluster labels
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'

# Force sync
argocd app sync <app-name>
```

#### HTTPRoute Not Working

```bash
# Check HTTPRoute status
kubectl get httproute --all-namespaces
kubectl describe httproute <name> -n <namespace>

# Check Gateway status
kubectl get gateway -n istio-system
kubectl describe gateway istio-gateway -n istio-system

# Check if service exists and has endpoints
kubectl get svc <service-name> -n <namespace>
kubectl get endpoints <service-name> -n <namespace>

# Check the gateway pod's logs
kubectl logs -n istio-system -l gateway.networking.k8s.io/gateway-name=istio-gateway --tail=100

# Check istiod — it programs the gateway
kubectl logs -n istio-system -l app=istiod --tail=100
```

#### Hostname Resolves but Returns 404 🔍

```bash
# The gateway Service is stable; confirm it exists and has an external IP
kubectl get svc -n istio-system istio-gateway-istio

# Confirm the route actually attached to the Gateway (look for Accepted=True)
kubectl get httproute -A -o wide

# Confirm which cloudflared connector answered — counters increment on the live one
kubectl port-forward -n cloudflared deploy/cloudflared 2000:2000
curl -s localhost:2000/metrics | grep cloudflared_tunnel_total_requests

# Restart Cloudflared if needed
kubectl rollout restart deployment/cloudflared -n cloudflared
```

**💡 Tip:** For `*.home.arpa` names, the authoritative DNS is the CoreDNS `hosts` block in `helmcharts/argocd/templates/kube-system/core-dns-cofigmap.yaml` — **not** external-dns. A stale IP there looks exactly like a broken Gateway.

### 🚀 Next Steps

After completing the setup:

1. **Review Security:**
   - Change ArgoCD admin password
   - Rotate Vault root token (create dedicated tokens)
   - Review and restrict Vault policies
   - Enable TLS for Vault (production)

2. **Configure Additional Applications:**
   - Deploy databases (PostgreSQL, Redis, etc.)
   - Deploy monitoring stack
   - Deploy application workloads

3. **Set Up Backup:**
   - Configure Vault Raft snapshots
   - Set up ArgoCD application backups
   - Document disaster recovery procedures

4. **Production Hardening:**
   - Enable TLS everywhere
   - Configure network policies
   - Set up audit logging
   - Implement secret rotation policies

For detailed documentation on each component, see:
- **ArgoCD**: [`helmcharts/argocd/README.md`](helmcharts/argocd/README.md)
- **Vault**: [`helmcharts/vault/README.md`](helmcharts/vault/README.md)
- **Cloudflared**: [`helmcharts/cloudflared/README.md`](helmcharts/cloudflared/README.md)
- **External Secrets**: [`helmcharts/external-secrets/README.md`](helmcharts/external-secrets/README.md)
- **Istio / istio-gateway**: [`docs/istio/index.md`](https://github.com/Alarmify/alarmify-docs/blob/main/docs/istio/index.md) and the [deployment runbook](https://github.com/Alarmify/alarmify-docs/blob/main/docs/istio/istio-deployment-runbook.md)
- **Gateway API**: The shared `Gateway` lives in [`helmcharts/istio/istio-gateway/templates/`](helmcharts/istio/istio-gateway/templates/); each service's HTTPRoute/TCPRoute is templated in its own chart

## 📦 Helm Charts

<div align="center">

### 🎯 **Helm Charts Overview** 🎯

</div>

This repository contains **51 custom Helm charts**, each wrapping an official upstream chart with production-ready configurations, custom templates, and comprehensive documentation.

### 📊 Core Infrastructure Charts

<div align="center">

| 📦 Chart | 📌 Version | 📝 Description | ✅ Status |
|---------|-----------|---------------|----------|
| **🚀 argocd** | 9.3.4 (v3.2.0) | GitOps continuous delivery | ✅ Production Ready |
| **📱 argocd-apps** | 0.1.0 | App-of-Apps & ApplicationSets | ✅ Configured |
| **🕸️ istio** | 1.30.2 | Ambient mesh (9 subcharts) + `istio-gateway` ingress | ✅ Production Ready |
| **🔷 cilium** | 1.20.0-rc.1 | CNI, kube-proxy replacement, bare-metal load balancer | ✅ Production Ready |
| **🔒 cert-manager** | Latest | Certificate management | ✅ Configured |
| **🗄️ vault** | 0.31.0 | Secrets management | ✅ Configured |
| **🌐 cloudflared** | 2.2.1 | Cloudflare Tunnel | ✅ Configured |
| **🌍 external-dns** | 1.13.1 | DNS automation with Cloudflare | ✅ Production Ready |
| **🔐 external-secrets** | 0.20.3 | External Secrets Operator | ✅ Configured |
| **📊 kube-prometheus-stack** | 78.5.0 | Prometheus + Grafana monitoring | ✅ Configured |
| **🐂 longhorn** | 1.11.1 | Distributed block storage (CSI) | ✅ Production Ready |
| **🐘 cloudnative-pg** | 0.26.1 | PostgreSQL operator | ✅ Configured |
| **📨 strimzi-kafka-operator** | 0.45.0 | Apache Kafka operator | ✅ Configured |
| **⚡ keda** | 2.18.1 | Event-driven autoscaling | ✅ Configured |
| **🎨 backstage** | 2.6.2 | Developer portal platform | ✅ Configured |
| **🔄 n8n** | 1.15.16 | Workflow automation | ✅ Configured |

</div>

### 📚 Comprehensive Documentation

For detailed Helm charts documentation, including:

- **Complete chart reference** with versions, dependencies, and configurations
- **Chart structure** and organization
- **Configuration management** strategies
- **Deployment strategies** and best practices
- **Chart development** guidelines

See: **[📦 Complete Helm Charts Documentation](https://github.com/Alarmify/alarmify-docs/blob/main/docs/helm-charts/README.md)**

### 🔑 Key Features

- ✅ **Production-ready defaults** for all charts
- ✅ **Custom templates** where needed
- ✅ **Comprehensive documentation** per chart
- ✅ **ArgoCD integration** via Applications and ApplicationSets
- ✅ **Dependency management** with locked versions

## 🎨 Applications

<div align="center">

### 🚀 **Bootstrap Applications (Self-Management)** 🚀

</div>

Located in `helmcharts/argocd-apps/templates/applications/` — **3 active** of 6 files:

<div align="center">

| 🎯 Application | 📝 Purpose | 📦 Repository | 📁 Path |
|---------------|-----------|-------------|---------|
| **🚀 argocd** | ArgoCD self-management | defyjoy/ArgoCD | helmcharts/argocd |
| **📱 argocd-apps** | Manages all ApplicationSets | defyjoy/ArgoCD | helmcharts/argocd-apps |
| **📊 kube-prometheus-stack** | Monitoring stack (Prometheus + Grafana) | defyjoy/ArgoCD | helmcharts/kube-prometheus-stack |

</div>

<div align="center">

> **💡 Note:** The other three files render nothing. `rancher.yaml` is entirely commented out; `portainer.yaml` and `victoria-metrics-vmauth.yaml` are **empty files** with no backing chart in `helmcharts/`.
>
> **💡 Note:** HTTPRoute/TCPRoute resources are managed as templates inside the chart that owns the service they route to; the shared `Gateway` lives in `helmcharts/istio/istio-gateway/`.

</div>

## 🎭 ApplicationSets

<div align="center">

### 🌐 **Multi-Cluster Application Deployment** 🌐

</div>

ApplicationSets enable multi-cluster application deployment using cluster generators. Located in `helmcharts/argocd-apps/templates/applicationsets/` (131 total, including the `istio/` and `alarmify/` subdirectories):

<div align="center">

#### 📊 **Status Legend** 📊

</div>

<div align="center">

| Status | Description |
|--------|-------------|
| **✅ Configured** | Fully configured with cluster generators, proper sync policies, and production-ready settings |
| **⚠️ Partial** | Configured but uses list generator instead of cluster generator (needs cluster labeling) |
| **📝 Template** | Basic template exists but needs configuration |

</div>

<div align="center">

### 🌐 **Networking & Load Balancing** 🌐

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **🔷 cilium** | eBPF networking — CNI, kube-proxy replacement, LoadBalancer | `cilium=true` | ✅ Configured |
| **🌐 cloudflared** | Cloudflare tunnels | `cloudflared=true` | ✅ Configured |
| **🌍 external-dns** | DNS automation | `external-dns=true` | ✅ Configured |

</div>

<div align="center">

### 🕸️ **Service Mesh (Istio, Ambient)** 🕸️

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **🧩 istio-base** | Istio CRDs & cluster RBAC (wave 10) | `istio-base=true` | ✅ Configured |
| **🎛️ istiod** | Istio control plane, ambient profile (wave 11) | `istiod=true` | ✅ Configured |
| **🔌 istio-cni** | Istio CNI node agent, ambient profile (wave 12) | `istio-cni=true` | ✅ Configured |
| **📡 ztunnel** | Ambient per-node data-plane proxy (wave 13) | `ztunnel=true` | ✅ Configured |
| **🚪 istio-gateway** | Gateway API ingress — `istio-gateway-istio` in `istio-system` (wave 14) | `istio-gateway=true` | ✅ Configured |
| **📊 kiali** | Mesh observability dashboard, OIDC via Zitadel (wave 14) | `kiali=true` | ✅ Configured |
| **🔗 istio-eastwest** | Ambient east-west gateway, multicluster (wave 15) | `istio-eastwest=true` | ✅ Configured |
| **🎟️ istio-remote-secrets** | Cross-cluster API-server credentials (wave 15) | `istio-remote-secrets=true` | ✅ Configured |
| **🔑 istio-cacerts** | Shared intermediate CA for mesh trust unification (wave 12) | `istio-cacerts=true` | ✅ Configured |

> **⚠️ All Istio ApplicationSets additionally gate on `environment in (dev, hub)`.** The component label alone is not enough — an unlabelled-environment cluster generates no Application.

See [`docs/istio/index.md`](https://github.com/Alarmify/alarmify-docs/blob/main/docs/istio/index.md) for architecture,
[`docs/istio/istio-deployment-runbook.md`](https://github.com/Alarmify/alarmify-docs/blob/main/docs/istio/istio-deployment-runbook.md) for the
mesh rollout, and
[`docs/istio/kiali-deployment-runbook.md`](https://github.com/Alarmify/alarmify-docs/blob/main/docs/istio/kiali-deployment-runbook.md) for Kiali.
`istio-gateway` replaced Envoy Gateway as the sole north-south ingress on **2026-07-12**.

</div>

<div align="center">

### 📊 **Monitoring & Observability** 📊

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **📊 kube-prometheus-stack** | Prometheus + Grafana | `kube-prometheus-stack=true` | ✅ Configured |
| **📈 victoria-metrics-operator** | VM operator | `victoria-metrics-operator=true` | ⚠️ Partial |
| **📉 grafana-k8s-monitoring** | Grafana stack | `grafana-k8s-monitoring=true` | 📝 Template |
| **📋 vector** | Log aggregation | `vector=true` | 📝 Template |
| **📡 kubernetes-event-exporter** | Event monitoring | `kubernetes-event-exporter=true` | 📝 Template |
| **🛡️ falco** | Runtime security | `falco=true` | 📝 Template |
| **🔍 trivy-operator** | Security scanning | `trivy-operator=true` | 📝 Template |
| **🔐 snyk-monitor** | Security monitoring | `snyk-monitor=true` | 📝 Template |
| **🦈 kubeshark** | API traffic viewer | `kubeshark=true` | 📝 Template |
| **👁️ popeye** | Cluster sanitizer | `popeye=true` | 📝 Template |
| **👀 kwatch** | Event watcher | `kwatch=true` | 📝 Template |

</div>

<div align="center">

### 🔐 **Security & Secrets** 🔐

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **🔐 external-secrets-operator** | External secrets | `external-secrets-operator=true` | ✅ Configured |
| **🗄️ hashicorp-vault** | Vault secrets | `hashicorp-vault=true` | ✅ Configured |
| **1️⃣ 1password-connect** | 1Password integration | `1password-connect=true` | 📝 Template |
| **🔒 authelia** | SSO & 2FA | `authelia=true` | 📝 Template |
| **👤 authentik** | Identity provider | `authentik=true` | 📝 Template |
| **🎫 keycloak** | IAM platform | `keycloak=true` | 📝 Template |
| **🆔 zitadel** | Identity management | `zitadel=true` | 📝 Template |
| **🚧 gatekeeper** | Policy enforcement | `gatekeeper=true` | 📝 Template |
| **⚖️ kyverno-operator** | Policy engine | `kyverno-operator=true` | 📝 Template |
| **📊 kyverno-policy-reporter** | Policy reporting | `kyverno-policy-reporter=true` | 📝 Template |
| **🛡️ kubewarden** | Policy engine | `kubewarden=true` | 📝 Template |

</div>

<div align="center">

### 💾 **Storage & Databases** 💾

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **🐂 longhorn** | Distributed block storage (CSI) — the storage provisioner | `longhorn=true` | ✅ Configured |
| **🐘 cloudnative-pg** | PostgreSQL operator | `cloudnative-pg=true` | ✅ Configured |
| **☁️ minio-operator** | S3-compatible storage | `minio-operator=true` | 📝 Template |
| **📊 cassandra** | Cassandra operator | `cassandra=true` | 📝 Template |
| **🪳 cockroachdb** | CockroachDB | `cockroachdb=true` | 📝 Template |
| **🕸️ neo4j** | Graph database | `neo4j=true` | 📝 Template |
| **🔑 keydb** | Redis alternative | `keydb=true` | 📝 Template |
| **🔴 redis-cluster** | Redis cluster | `redis-cluster=true` | 📝 Template |
| **🐉 dragonfly** | Modern Redis | `dragonfly=true` | 📝 Template |
| **⚡ valkey** | Redis fork | `valkey=true` | 📝 Template |
| **📸 csi-snapshot-controller** | Volume snapshots | `csi-snapshot-controller=true` | 📝 Template |
| **💿 csi-wekafsplugin** | WekaFS CSI | `csi-wekafsplugin=true` | 📝 Template |

</div>

<div align="center">

### 🤖 **Data & ML Platforms** 🤖

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **🌪️ airflow-operator** | Workflow orchestration | `airflow-operator=true` | 📝 Template |
| **🧠 kubeflow-operator** | ML platform | `kubeflow-operator=true` | 📝 Template |
| **📊 mlflow** | ML lifecycle | `mlflow=true` | 📝 Template |
| **🔬 clearml** | ML ops platform | `clearml=true` | 📝 Template |
| **⚡ dask** | Parallel computing | `dask=true` | 📝 Template |
| **🔥 spark** | Big data processing | `spark=true` | 📝 Template |
| **🔍 trino** | Distributed SQL | `trino=true` | 📝 Template |
| **📈 superset** | Data visualization | `superset=true` | 📝 Template |

</div>

<div align="center">

### 📨 **Messaging & Streaming** 📨

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **📨 strimzi-kafka-operator** | Apache Kafka operator | `strimzi-kafka-operator=true` | ✅ Configured |
| **🐰 rabbitmq-cluster-operator** | RabbitMQ operator | `rabbitmq-cluster-operator=true` | ✅ Configured |
| **🎛️ kafka-ui** | Kafka management | `kafka-ui=true` | 📝 Template |
| **🦝 redpanda** | Kafka alternative | `redpanda=true` | 📝 Template |
| **⭐ pulsar** | Pub/sub platform | `pulsar=true` | 📝 Template |
| **🌐 nats** | Cloud-native messaging | `nats=true` | 📝 Template |

</div>

<div align="center">

### 🔄 **CI/CD & GitOps** 🔄

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **🔄 argocd-workflows** | Argo Workflows | `argocd-workflows=true` | 📝 Template |
| **📡 argo-events** | Event-based workflows | `argo-events=true` | 📝 Template |
| **🐙 github-arc-operator** | GitHub Actions runner | `github-arc-operator=true` | 📝 Template |
| **🏗️ atlantis** | Terraform automation | `atlantis=true` | 📝 Template |
| **☁️ terraform-operator** | Terraform operator | `terraform-operator=true` | 📝 Template |
| **🔄 renovate** | Dependency updates | `renovate=true` | 📝 Template |

</div>

<div align="center">

### 🛠️ **Developer Tools** 🛠️

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **🎨 backstage** | Developer portal platform | `backstage=true` | ✅ Configured |
| **🐳 harbor** | Container registry | `harbor=true` | 📝 Template |
| **🔍 sonarqube** | Code quality | `sonarqube=true` | 📝 Template |
| **📦 dependency-track** | Component analysis | `dependency-track=true` | 📝 Template |
| **🐛 glitchtip** | Error tracking | `glitchtip=true` | 📝 Template |
| **🚦 semaphore** | CI/CD platform | `semaphore=true` | 📝 Template |
| **📋 rundeck** | Runbook automation | `rundeck=true` | 📝 Template |

</div>

<div align="center">

### ⚡ **Automation & Scaling** ⚡

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **⚡ keda** | Event-driven autoscaling | `keda=true` | ✅ Configured |
| **💥 chaos-operator** | Chaos engineering | `chaos-operator=true` | 📝 Template |
| **🐵 kube-monkey** | Chaos testing | `kube-monkey=true` | 📝 Template |
| **🔄 kured** | Node reboot daemon | `kured=true` | 📝 Template |

</div>

<div align="center">

### 🎯 **Miscellaneous** 🎯

</div>

<div align="center">

| 🎯 ApplicationSet | 📝 Description | 🏷️ Label Required | ✅ Status |
|------------------|---------------|-------------------|----------|
| **📦 capsule** | Multi-tenancy | `capsule=true` | 📝 Template |
| **🔌 telepresense** | Local development | `telepresense=true` | 📝 Template |
| **🪶 headscale** | Tailscale control | `headscale=true` | 📝 Template |
| **🌐 ngrok-operator** | Ingress tunnels | `ngrok-operator=true` | 📝 Template |
| **🎮 nvidia-gpu-operator** | GPU support | `nvidia-gpu-operator=true` | 📝 Template |
| **🌊 flink-operator** | Stream processing | `flink-operator=true` | 📝 Template |
| **🤖 awx-operator** | Ansible automation | `awx-operator=true` | 📝 Template |
| **🔄 n8n** | Workflow automation | `n8n=true` | ✅ Configured |
| **📚 moodle** | Learning management | `moodle=true` | 📝 Template |
| **🔐 passbolt** | Password manager | `passbolt=true` | 📝 Template |
| **🚩 unleash** | Feature flags | `unleash=true` | 📝 Template |
| **🕵️ opencti** | Threat intelligence | `opencti=true` | 📝 Template |
| **🔒 openfga** | Authorization | `openfga=true` | 📝 Template |
| **📊 hertzbeat** | Monitoring platform | `hertzbeat=true` | 📝 Template |
| **🔒 autocert** | Certificate automation | `autocert=true` | 📝 Template |

</div>

## 🚀 Usage

<div align="center">

### 🏷️ **Deploy Applications Using Labels** 🏷️

</div>

ApplicationSets use cluster labels to determine which applications to deploy:

<div align="center">

#### 📋 **Common Cluster Labels** 📋

</div>

```bash
# 🕸️ Labels for the Istio ambient stack + ingress (first in Step 4 / Phase 1 order).
# These also require the cluster to carry environment=dev or environment=hub.
kubectl label secret -n argocd cluster-local \
  istio-base=true istiod=true istio-cni=true ztunnel=true istio-gateway=true

# 🔷 Label a cluster for Cilium (CNI + kube-proxy replacement + LoadBalancer)
kubectl label secret -n argocd cluster-local cilium=true

# Label for monitoring stack
kubectl label secret -n argocd cluster-local kube-prometheus-stack=true

# Label for DNS automation
kubectl label secret -n argocd cluster-local external-dns=true

# Label for external secrets
kubectl label secret -n argocd cluster-local external-secrets-operator=true

# Label for storage
kubectl label secret -n argocd cluster-local longhorn=true

# Label for workflow automation
kubectl label secret -n argocd cluster-local n8n=true

# Label for Vault secrets management
kubectl label secret -n argocd cluster-local vault=true

# Label for Cloudflare tunnels
kubectl label secret -n argocd cluster-local cloudflared=true

# Label for PostgreSQL operator
kubectl label secret -n argocd cluster-local cloudnative-pg=true

# Label for Kafka operator
kubectl label secret -n argocd cluster-local strimzi-kafka-operator=true

# Label for RabbitMQ operator
kubectl label secret -n argocd cluster-local rabbitmq-cluster-operator=true

# Label for KEDA autoscaling
kubectl label secret -n argocd cluster-local keda=true

# Label for Backstage developer portal
kubectl label secret -n argocd cluster-local backstage=true

# Verify labels
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'
```

### Check Application Status

```bash
# Using Task (from repository root)
task status

# Using ArgoCD CLI
argocd app list
argocd app get <app-name>

# Using kubectl
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
```

## 🎯 Deployment Order (Recommended Phases)

<div align="center">

### 📋 **Phased Deployment Strategy** 📋

</div>

Based on chart dependencies, deploy components in the following order to ensure all prerequisites are met:

### Phase 1: Core Infrastructure

Deploy these foundational components first (aligned with **Step 4** in this README: **Cilium** is already in place from the **Step 2** bootstrap, then the **Istio ambient stack**):

1. **Cilium** - CNI, kube-proxy replacement, and bare-metal `LoadBalancer` IPs (installed by `task bootstrap` in **Step 2**, ahead of ArgoCD)
2. **Istio** - ambient mesh and Gateway API ingress, in wave order: `istio-base` → `istiod` → `istio-cni` → `ztunnel` → `istio-gateway` (all in **`istio-system`**)
3. **Longhorn** - Distributed block storage; the storage provisioner for every stateful workload in this repo
4. **Cert-Manager** - Certificate management (optional, for TLS)
5. **Vault** - Secrets storage
6. **External-Secrets** - Secret management (depends on Vault)
7. **External-DNS** - DNS automation (depends on External-Secrets)
8. **Cloudflared** - Cloudflare tunnel (depends on External-Secrets and istio-gateway)
9. **Kube-Prometheus-Stack** - Monitoring infrastructure
10. **ArgoCD** - GitOps platform (if not already bootstrapped)

**Label clusters:**
```bash
kubectl label secret -n argocd cluster-local cilium=true
kubectl label secret -n argocd cluster-local \
  istio-base=true istiod=true istio-cni=true ztunnel=true istio-gateway=true
kubectl label secret -n argocd cluster-local longhorn=true
kubectl label secret -n argocd cluster-local cert-manager=true
kubectl label secret -n argocd cluster-local vault=true
kubectl label secret -n argocd cluster-local external-secrets=true
kubectl label secret -n argocd cluster-local external-dns=true
kubectl label secret -n argocd cluster-local cloudflared=true
kubectl label secret -n argocd cluster-local kube-prometheus-stack=true
```

### Phase 2: Databases & Messaging

Deploy database and messaging infrastructure:

11. **CloudNative-PG** - PostgreSQL operator (depends on Longhorn)
12. **Redis** - Cache/session storage (depends on Longhorn)
13. **Valkey** - Redis alternative (depends on Longhorn)
14. **Yugabyte** - Distributed SQL database (depends on Longhorn)
15. **Neo4j** - Graph database (depends on Longhorn)
16. **Cassandra** - NoSQL database (depends on Longhorn)
17. **ClickHouse** - Analytics database (depends on Longhorn)
18. **Strimzi Kafka** - Message streaming (depends on Longhorn)
19. **NATS** - Pub/sub messaging (depends on Longhorn)

**Label clusters:**
```bash
kubectl label secret -n argocd cluster-local cloudnative-pg=true
kubectl label secret -n argocd cluster-local redis=true
kubectl label secret -n argocd cluster-local valkey=true
kubectl label secret -n argocd cluster-local yugabyte=true
kubectl label secret -n argocd cluster-local neo4j=true
kubectl label secret -n argocd cluster-local cassandra=true
kubectl label secret -n argocd cluster-local clickhouse=true
kubectl label secret -n argocd cluster-local strimzi-kafka-operator=true
kubectl label secret -n argocd cluster-local nats=true
```

### Phase 3: Operators & Security

Deploy operators and security tools:

20. **KEDA** - Event-driven autoscaling
21. **Kyverno** - Policy engine
22. **Falco** - Runtime security monitoring
23. **Argo Events** - Event processing (depends on ArgoCD)
24. **Argo Workflows** - Workflow engine (depends on ArgoCD)
25. **AWX Operator** - Ansible automation (depends on PostgreSQL, Ingress, Cert-Manager)

**Label clusters:**
```bash
kubectl label secret -n argocd cluster-local keda=true
kubectl label secret -n argocd cluster-local kyverno=true
kubectl label secret -n argocd cluster-local falco=true
kubectl label secret -n argocd cluster-local argo-events=true
kubectl label secret -n argocd cluster-local argo-workflows=true
kubectl label secret -n argocd cluster-local awx-operator=true
```

### Phase 4: Applications

Deploy application workloads:

26. **Harbor** - Container registry (depends on PostgreSQL, Redis, Ingress, Cert-Manager)
27. **Backstage** - Developer portal (depends on PostgreSQL, Ingress, Cert-Manager)
28. **Airflow** - Workflow orchestration (depends on PostgreSQL, Redis, Ingress, Cert-Manager)
29. **Superset** - Business intelligence (depends on PostgreSQL, Ingress, Cert-Manager)
30. **MLflow** - ML lifecycle management (depends on PostgreSQL, Ingress, Cert-Manager)
31. **n8n** - Workflow automation (depends on PostgreSQL, Ingress, Cert-Manager)
32. **Rancher** - Container management (depends on Ingress, Cert-Manager)
33. **Atlantis** - Terraform automation (depends on Ingress, Cert-Manager)
34. **Glitchtip** - Error tracking (depends on PostgreSQL, Ingress, Cert-Manager)

**Label clusters:**
```bash
kubectl label secret -n argocd cluster-local harbor=true
kubectl label secret -n argocd cluster-local backstage=true
kubectl label secret -n argocd cluster-local airflow=true
kubectl label secret -n argocd cluster-local superset=true
kubectl label secret -n argocd cluster-local mlflow=true
kubectl label secret -n argocd cluster-local n8n=true
kubectl label secret -n argocd cluster-local rancher=true
kubectl label secret -n argocd cluster-local atlantis=true
kubectl label secret -n argocd cluster-local glitchtip=true
```

### Phase 5: Virtualization & Advanced

Deploy virtualization and advanced features:

35. **Tailscale** - VPN connectivity

**Label clusters:**
```bash
kubectl label secret -n argocd cluster-local tailscale=true
```

### Quick Deploy All Phases

To deploy all components at once (ArgoCD will handle dependencies):

```bash
# Phase 1: Core Infrastructure (Istio first matches this README’s Step 4 order)
kubectl label secret -n argocd cluster-local \
  cilium=true istio-base=true istiod=true istio-cni=true \
  ztunnel=true istio-gateway=true longhorn=true \
  cert-manager=true vault=true external-secrets=true \
  external-dns=true cloudflared=true kube-prometheus-stack=true

# Phase 2: Databases & Messaging
kubectl label secret -n argocd cluster-local \
  cloudnative-pg=true redis=true valkey=true \
  yugabyte=true neo4j=true cassandra=true \
  clickhouse=true strimzi-kafka-operator=true nats=true

# Phase 3: Operators & Security
kubectl label secret -n argocd cluster-local \
  keda=true kyverno=true falco=true \
  argo-events=true argo-workflows=true awx-operator=true

# Phase 4: Applications
kubectl label secret -n argocd cluster-local \
  harbor=true backstage=true airflow=true \
  superset=true mlflow=true n8n=true \
  rancher=true atlantis=true glitchtip=true

# Phase 5: Virtualization
kubectl label secret -n argocd cluster-local \
  tailscale=true
```

> **Note:** For detailed dependency information, see [`https://github.com/Alarmify/alarmify-docs/blob/main/docs/helm-charts/HELM-CHART-DEPENDENCY-GRAPH.md`](https://github.com/Alarmify/alarmify-docs/blob/main/docs/helm-charts/HELM-CHART-DEPENDENCY-GRAPH.md)

## 🔧 Configuration

<div align="center">

### 🌍 **Environment-Specific Values** 🌍

</div>

Some charts support environment-specific values:

<div align="center">

```
helmcharts/longhorn/values/
├── 💻 local.yaml      # management cluster
└── 🧪 dev.yaml        # dev cluster
```

</div>

Overlays hold **only differential overrides** — the base `values.yaml` carries everything shared. Same pattern in `cilium`, `cert-manager`, and `cloudflared`.

Use in ApplicationSets:
```yaml
helm:
  valueFiles:
    - values.yaml
    - values/{{values.environment}}.yaml  # Environment-specific overrides
  ignoreMissingValueFiles: true
```

<div align="center">

### 📦 **Repository Configuration** 📦

</div>

All ApplicationSets are configured to use:

<div align="center">

```yaml
source:
  repoURL: git@github.com:defyjoy/ArgoCD.git  # 📦 Git repository
  targetRevision: HEAD                         # 🔄 Branch/tag
  path: helmcharts/<chart-name>                # 📁 Chart path
```

</div>

<div align="center">

> **💡 Tip**: Update your fork URL in all ApplicationSet files if needed.

</div>

## 🎭 Multi-Cluster Deployment

<div align="center">

### 🌐 **Register Additional Clusters** 🌐

</div>

```bash
# 📋 List available contexts
kubectl config get-contexts

# ➕ Add cluster to ArgoCD
argocd cluster add <context-name>

# ✅ Verify
argocd cluster list
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster
```

> **⚠️ This repo does not use `argocd cluster add`** (imperative — not reconstructable from git).
> The canonical, GitOps-native procedure for registering the **`dev`** cluster (declarative,
> Vault-backed `ExternalSecret`) is the runbook: **[`docs/runbooks/register-dev-cluster.md`](docs/runbooks/register-dev-cluster.md)**
> (rationale: [`alarmify-docs` ADR-005](https://github.com/Alarmify/alarmify-docs/blob/main/docs/istio/ambient/adrs/adr-005-argocd-cross-cluster-trust-model.md)).

<div align="center">

### 🚀 **Deploy to Multiple Clusters** 🚀

</div>

```bash
# 🏷️ Label clusters for specific apps
kubectl label secret -n argocd cluster-prod-us-east cilium=true
kubectl label secret -n argocd cluster-prod-us-west cilium=true
kubectl label secret -n argocd cluster-staging cilium=true

# ✨ ApplicationSet will automatically create Applications for each labeled cluster
```

<div align="center">

> **💡 Magic**: ApplicationSets automatically create Applications for each labeled cluster - no manual work needed!

</div>

## 📚 Documentation

<div align="center">

### 📖 **Chart-Specific Documentation** 📖

</div>

<div align="center">

| 📦 Chart | 📄 Documentation | 📝 Highlights |
|---------|-----------------|--------------|
| **🚀 ArgoCD** | `helmcharts/argocd/README.md`<br/>Tasks: `Taskfile.yml` + `scripts/` (repo root)<br/>Bootstrap notes: `helmcharts/argocd/bootstrap/README.md` | GitOps continuous delivery, Task runner |
| **🕸️ Istio** | `helmcharts/istio/*/README.md` (one per subchart) | Ambient mesh, `istio-gateway` ingress, east-west multicluster |
| **🔷 Cilium** | `helmcharts/cilium/README.md` | CNI, kube-proxy replacement, LB-IPAM + L2 announcement, per-cluster address pools |
| **🗄️ Vault** | `helmcharts/vault/README.md`<br/>Checklist: `helmcharts/vault/PRODUCTION-CHECKLIST.md`<br/>Ready: `helmcharts/vault/PRODUCTION-READY.md` | Secrets management, production hardening |
| **🌐 Cloudflared** | `helmcharts/cloudflared/README.md` | Cloudflare Tunnel setup and configuration |
| **🌍 External DNS** | `helmcharts/external-dns/README.md` (330+ lines) | Cloudflare integration, API token auth, monitoring |
| **🔐 External Secrets** | `helmcharts/external-secrets/README.md`<br/>Vault: `helmcharts/external-secrets/VAULT-INTEGRATION.md` | Secure secret management, Vault integration |
| **📊 Kube Prometheus Stack** | `helmcharts/kube-prometheus-stack/README.md` | Prometheus + Grafana, service discovery, alerting |
| **🐂 Longhorn** | `helmcharts/longhorn/README.md` | Distributed block storage (CSI), per-disk reservation tuning |
| **🔄 n8n** | `helmcharts/n8n/README.md` | Workflow automation, security compliance |
| **🐘 CloudNative-PG** | `helmcharts/cloudnative-pg/README.md` | PostgreSQL operator, HA, automated backups |
| **📨 Strimzi Kafka** | `helmcharts/strimzi-kafka-operator/README.md` | Apache Kafka, Connect, MirrorMaker, Bridge |
| **⚡ KEDA** | `helmcharts/keda/README.md` | Event-driven autoscaling, multi-source integration |
| **🎨 Backstage** | `helmcharts/backstage/README.md` | Developer portal, service catalog, TechDocs |
| **🐰 RabbitMQ** | `manifests/rabbitmq-operator/README.md` | RabbitMQ operator, Kustomize, HA messaging |

</div>

## 🛠️ Development

<div align="center">

### ➕ **Add New ApplicationSet** ➕

</div>

<div align="center">

#### 📝 **Step-by-Step Guide** 📝

</div>

**1️⃣ Create a new file** in `helmcharts/argocd-apps/templates/applicationsets/`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            my-app: "true"
  template:
    metadata:
      name: {{ `"{{name}}-my-app"` }}
    spec:
      source:
        repoURL: git@github.com:defyjoy/ArgoCD.git
        targetRevision: HEAD
        path: helmcharts/my-app
      destination:
        server: {{ `"{{server}}"` }}
        namespace: my-app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

2. Commit and push to Git
3. ArgoCD will auto-sync the new ApplicationSet

<div align="center">

### 🧪 **Test Helm Charts** 🧪

</div>

```bash
# 🚀 Test ArgoCD chart
cd helmcharts/argocd
helm template . --namespace argocd

# 📱 Test argocd-apps chart
cd helmcharts/argocd-apps
helm template . --namespace argocd

# 🔷 Test specific chart
cd helmcharts/cilium
helm template . --namespace kube-system
```

<div align="center">

> **💡 Tip**: Always test Helm charts with `helm template` before deploying to catch configuration errors early.

</div>

## 🔄 Bootstrap Flow

<div align="center">

### 🎬 **Complete Bootstrap Sequence** 🎬

</div>

```
┌──────────────────────────────────────────────────────────┐
│  1️⃣  Bootstrap ArgoCD                                     │
│  task bootstrap  (from repository root)                 │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│  2. ArgoCD Self-Management                               │
│  kubectl apply -f argocd-apps/templates/applications/    │
│                   argocd.yaml                            │
│  → ArgoCD manages itself from Git                        │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│  3. App-of-Apps Pattern                                  │
│  kubectl apply -f argocd-apps/templates/applications/    │
│                   argocd-apps.yaml                       │
│  → ArgoCD manages all ApplicationSets                    │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│  4. Label Clusters                                       │
│  kubectl label secret -n argocd cluster-<name>           │
│                       <app>=true                      │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│  5. Applications Auto-Deploy                             │
│  ApplicationSets create Applications for labeled         │
│  clusters automatically                                  │
└──────────────────────────────────────────────────────────┘
```

## 🎯 Common Tasks

<div align="center">

### ⚡ **Frequently Used Commands** ⚡

</div>

### Using Task Runner

```bash
# From repository root
# List all tasks
task --list

# Bootstrap ArgoCD
task bootstrap

# Check status
task status

# Access UI
task port-forward

# Upgrade ArgoCD
task upgrade

# Restart components
task restart
```

#### Tearing it back down

`task destroy-app-of-apps` is the inverse of `task app-of-apps`: it removes the root `argocd-apps`
Application, every ApplicationSet it renders, every Application those generate, and the workloads
behind them — **on every target cluster**, since the ApplicationSets also select `dev`.

```bash
# See exactly what would be deleted, change nothing
task destroy-app-of-apps DRY_RUN=true

# Tear down the workloads but keep the cluster usable
task destroy-app-of-apps KEEP_APPS_EXTRA="local-cilium local-longhorn"
```

> **⚠️ Cilium and Longhorn are ordinary app-of-apps Applications.** A full run therefore takes out
> the CNI (network datapath *and* LoadBalancer IPs) and the sole storage provisioner (every PV with
> it). `KEEP_APPS_EXTRA` excludes them; the task warns on stdout when either is in scope.
>
> Argo CD itself is deliberately preserved — it is the controller performing the deletion, so
> removing it mid-cascade strands every remaining Application on its finalizer. The `argocd`
> (self-management) and `argocd-apps` Applications survive; remove Argo CD afterwards with
> `task uninstall`.
>
> The ApplicationSet templates in this repo do **not** set `resources-finalizer.argocd.argoproj.io`
> on the Applications they generate, so simply deleting the ApplicationSets would orphan every
> workload in the cluster. The task adds that finalizer first — which is why deleting the
> ApplicationSets by hand is not equivalent.

### Using ArgoCD CLI

```bash
# Sync all applications
argocd app sync --all

# Sync specific app
argocd app sync <app-name>

# View app details
argocd app get <app-name>

# View diff
argocd app diff <app-name>

# Rollback
argocd app rollback <app-name> <revision>
```

## 🐛 Troubleshooting

<div align="center">

### 🔍 **Common Issues & Solutions** 🔍

</div>

### ArgoCD Not Starting

```bash
# Check pods
kubectl get pods -n argocd

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Using Task (from repository root)
task logs
```

### Applications Not Syncing

```bash
# Check application status
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# Force sync
argocd app sync <app-name> --force

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/component=application-controller
```

### LoadBalancer Service stuck in `Pending`

Cilium LB-IPAM only assigns an address that its pool actually contains, and the pool renders
nothing when the cluster's overlay supplies no `addresses`.

```bash
# Does the cluster have a pool at all, and does it cover the address you expect?
kubectl get ciliumloadbalancerippool -o yaml

# Is anything announcing on L2?
kubectl get ciliuml2announcementpolicy

# Conflicts show up as an event on the Service
kubectl describe svc <name> -n <namespace>
```

Add the `/32` to `helmcharts/cilium/values/<environment>.yaml` and let ArgoCD sync — do not
apply the pool by hand. See: `helmcharts/cilium/README.md`

## 📖 Resources

<div align="center">

### 🔗 **External Resources & Links** 🔗

</div>

### Official Documentation
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Task Runner](https://taskfile.dev/)

### Helm Charts
- [Argo CD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Istio](https://istio.io/latest/docs/ambient/)
- [Longhorn](https://longhorn.io/docs/)
- [Cilium](https://docs.cilium.io/)
- [HashiCorp Vault](https://github.com/hashicorp/vault-helm)

## 🤝 Contributing

<div align="center">

### 🌟 **How to Contribute** 🌟

</div>

<div align="center">

| Step | Action | Description |
|------|--------|-------------|
| **1️⃣** | 🌿 **Create Feature Branch** | `git checkout -b feat/your-feature-name` |
| **2️⃣** | ✏️ **Make Your Changes** | Update charts, manifests, or documentation |
| **3️⃣** | ✅ **Test Changes** | `helm template` and `kubectl apply --dry-run` |
| **4️⃣** | 📝 **Update Documentation** | Keep docs in sync with changes |
| **5️⃣** | 🚀 **Submit Pull Request** | Create PR with clear description |

</div>

## 📝 License

<div align="center">

[Add your license here]

</div>

---

<div align="center">

**📦 Repository**: `git@github.com:defyjoy/ArgoCD.git`  
**🌿 Branch**: `main`  
**🤖 Managed By**: ArgoCD (self-managed after bootstrap)

</div>
