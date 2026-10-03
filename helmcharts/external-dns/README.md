# External DNS

Manages Cloudflare DNS records for Gateway `HTTPRoute`, `Service`, and `DNSEndpoint`
resources on this cluster. Wraps the upstream
[kubernetes-sigs/external-dns](https://github.com/kubernetes-sigs/external-dns) chart
(`1.21.1`) with the Cloudflare provider.

## Current bootstrap state (2026-10)

Vault and External Secrets Operator are **not fully wired up yet** on `hub`:

```bash
export KUBECONFIG=~/.kube/talos-hub.yaml
kubectl get pods -n external-secrets     # ESO controller: Running
kubectl get clustersecretstore           # vault-secretstore: InvalidProviderConfig
kubectl get ns vault                     # NotFound — Vault isn't deployed
kubectl get externalsecret -n external-dns cloudflare-api-token   # SecretSyncedError
```

`templates/cloudflare-api-token-secret.yaml` in this chart already creates an
`ExternalSecret` (`creationPolicy: Owner`) that expects to read
`alarmify/hub/cloudflared/token` from Vault. It syncs today — Vault has no backend to read
from. Until Vault is live, **the Secret it wants to own must be created manually**, or
external-dns's pod never gets `CF_API_TOKEN` and sits healthy while doing nothing.

> ⚠️ Once Vault + the real secret path exist, delete the manually-created Secret (or just
> let the `ExternalSecret` resync — `creationPolicy: Owner` will adopt and overwrite it).
> Re-run `kubectl get externalsecret -n external-dns cloudflare-api-token` after Vault comes
> up to confirm it flips to `SecretSynced` / `Ready: True`, then this whole runbook section
> is dead and the manual Secret can go.

## Runbook: bootstrap `cloudflare-api-token` by hand

1. **Get a Cloudflare API token** with `Zone:Read` + `DNS:Edit` scoped to `workquark.org`
   (Cloudflare dashboard → My Profile → API Tokens, or Account → API Tokens for an
   account-owned token — either works for this flow).

2. **Verify the token can actually see the zone** before trusting it — a bad token leaves
   external-dns running and "healthy" while silently never reconciling any record:

   ```bash
   CF_API_TOKEN=your-token-here
   ZONE=workquark.org

   curl -s -H "Authorization: Bearer ${CF_API_TOKEN}" \
     "https://api.cloudflare.com/client/v4/zones?name=${ZONE}" | jq '.success, .result[].name'
   ```

   > ⚠️ Don't use `/user/tokens/verify` for this check. It only validates **user-owned**
   > tokens and returns `code 1000 Invalid API Token` for a perfectly valid
   > **account-owned** token — a false negative on a working token. Hit 2026-08-06, still
   > true here.

   Expect `true` and `"workquark.org"`. If you get `false` or an empty result, the token is
   missing `Zone:Read` on that zone — fix it in Cloudflare before continuing.

3. **Create the namespace and Secret directly with kubectl** — this is the step that
   replaces Vault for now. The Secret name/key must match what `values.yaml`'s
   `external-dns.env` reads (`cloudflare-api-token` / `api-token`):

   ```bash
   export KUBECONFIG=~/.kube/talos-hub.yaml

   kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -

   kubectl create secret generic cloudflare-api-token \
     --namespace external-dns \
     --from-literal=api-token="${CF_API_TOKEN}" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

   For `dev`, same command, pointed at that cluster's kubeconfig — `dev` doesn't exist yet
   per this repo's cluster notes, so skip until it does.

4. **Let ArgoCD sync the rest of the chart** (Deployment, RBAC, ServiceMonitor). The
   `ExternalSecret` resource will keep reporting `SecretSyncedError` — that's expected and
   harmless as long as the manually-created Secret above already exists; ESO just can't
   take ownership of it yet.

5. **Confirm the Deployment actually picked up the token**:

   ```bash
   kubectl get pods -n external-dns
   kubectl logs -n external-dns deployment/external-dns | head -30
   ```

   A token that's missing or wrong shows up as external-dns running cleanly but never
   creating/updating any DNS record — check Cloudflare's dashboard for the expected record,
   don't trust pod health alone.

## Configuration

Values under `external-dns:` are passed straight through to the **upstream** chart — use
its schema (flat `sources`, `provider.name`, `env`, ...). A nested key like `externalDns`
is silently ignored by the dependency; that mistake previously meant only the default
sources (`service`, `ingress`) applied and HTTPRoute records were never created.

```yaml
external-dns:
  provider:
    name: cloudflare
  domainFilters:
    - workquark.org
  annotationFilter: external-dns.alpha.kubernetes.io/class=cloudflare
  sources:
    - gateway-httproute   # HTTPRoute objects — not the legacy name "gateway"
    - service
    - crd
  policy: sync
  registry: txt
  txtOwnerId: external-dns
  txtPrefix: external-dns
  triggerLoopOnEvent: true   # reconcile on HTTPRoute/Service/CRD changes, not just the 1m timer
```

### Per-cluster TXT registry owner

`hub` and `dev` manage the **same `workquark.org` zone**. `values/dev.yaml` overrides
`txtOwnerId`/`txtPrefix` to `external-dns-dev` so dev's external-dns doesn't fight the hub
instance over ownership of the same records. `values/hub.yaml` only carries the
`cloudflareApiToken.vaultPath` override — hub's `external-dns:` config is the shared
defaults as-is.

### Cloudflare token, once Vault is live

`templates/cloudflare-api-token-secret.yaml` reads the single property `token` from the
per-cluster Vault path:

```yaml
cloudflareApiToken:
  vaultPath: alarmify/hub/cloudflared/token   # alarmify/dev/cloudflared/token on dev
```

It shares the `cloudflared/` prefix with the tunnel credentials but is a separate Vault
object — `spec.data[]` hands external-dns only the API token, never the tunnel's `cert`,
so rotating one doesn't touch the other. Seed it with `task provision-vault-secrets` (see
`helmcharts/cloudflared/README.md`) once Vault exists — that task does the same zone-read
check as step 2 above before writing.

## Using external-dns

### HTTPRoute

Must carry the annotation external-dns is filtered on:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-httproute
  namespace: default
  annotations:
    external-dns.alpha.kubernetes.io/class: cloudflare
spec:
  parentRefs:
    - name: default
      namespace: envoy-gateway-system
  hostnames:
    - example.workquark.org
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: example-service
          port: 80
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service
  namespace: default
  annotations:
    external-dns.alpha.kubernetes.io/hostname: service.workquark.org
    external-dns.alpha.kubernetes.io/class: cloudflare
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: example
```

### DNSEndpoint CRD

```yaml
apiVersion: external-dns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: example-dnsendpoint
  namespace: default
spec:
  endpoints:
    - dnsName: "api.workquark.org"
      recordTTL: 300
      recordType: "A"
      targets:
        - "192.168.1.100"
```

## Troubleshooting

**Token issues** — check the Secret external-dns actually mounted, not the ExternalSecret:

```bash
kubectl get secret -n external-dns cloudflare-api-token -o jsonpath='{.data.api-token}' | base64 -d | head -c 10; echo
```

**Records not created** — check logs and that the annotation filter matches:

```bash
kubectl logs -n external-dns deployment/external-dns
kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations}{"\n"}{end}'
```

**Metrics**:

```bash
kubectl port-forward -n external-dns svc/external-dns 7979:7979
curl -s http://localhost:7979/metrics | grep external_dns_controller
```

> 📉 CPU limit halved on 2026-07-11 (`values.yaml` resources) — 24h peak usage was 2.0m per
> VictoriaMetrics.
