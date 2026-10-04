# cilium-gateway

North-south ingress `Gateway` (`gatewayClassName: cilium`), replacing `istio-gateway`. One
shared `Gateway` object per cluster; every `HTTPRoute` in the cluster attaches to it via
`parentRefs`.

## Listeners

`values.yaml`'s `gateway.commonListeners` holds the `http:80` listener every cluster gets.
`values/<env>.yaml` appends to `gateway.envListeners` for anything cluster-specific —
`gateway.yaml` renders `concat(commonListeners, envListeners)`. `envListeners` must default
to `[]` rather than being omitted: `concat` errors on `nil`.

### TLS on hub: self-signed, not a real CA

Hub has no CA yet — no StepCA, no ACME `ClusterIssuer`. `values/hub.yaml` sets
`gateway.tls.enabled: true`, which renders `templates/tls-selfsigned.yaml`: a cert-manager
`Issuer` of type `selfSigned` plus a `Certificate` for `*.home.arpa` / `home.arpa`, written to
a Secret in the `cilium-gateway` namespace. `envListeners` on hub then adds the `https:443`
listener with `tls.certificateRefs` pointing at that same Secret name.

```yaml
gateway:
  tls:
    enabled: true
    secretName: home-arpa-tls
    dnsNames:
      - "*.home.arpa"
      - "home.arpa"
  envListeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: home-arpa-tls
```

`secretName` appears in two places in the same file (the `tls` block that drives the
Certificate, and the literal `certificateRefs.name` in `envListeners`) — keep them identical
when touching either. The Secret lives in the Gateway's own namespace specifically so no
`ReferenceGrant` is needed (`certificateRefs` without an explicit `namespace` defaults to the
Gateway's).

Browsers will show an untrusted-certificate warning — there's no root to install, this is
purely "stop the TLS handshake from timing out," not a trusted chain. Swap it for a StepCA/ACME
issuer once that's deployed: flip `gateway.tls.enabled` off (or repoint `issuerRef` at the real
`ClusterIssuer`) and re-render; `envListeners`' `certificateRefs` name doesn't need to change if
the new issuer still targets the same Secret name.

### Why the Gateway only had `http` for a while

Hub previously shipped with `commonListeners` only (`http:80`) and empty `envListeners` — see
`c3510af "Fix cilium-gateway address and drop dead listeners for hub"`. Any `HTTPRoute` with a
`sectionName: https` parentRef (e.g. `longhorn-httproute`, which has **only** an https
parentRef) was unreachable until this `https` listener existed; `kubectl get httproute -o yaml`
showed `reason: NoMatchingParent` on that parent while `http` stayed `Accepted: True`. That's
expected with no `https` listener — it isn't a routing bug by itself.

### L2 announcements must actually be live

The Gateway's `addresses` IP (`192.168.7.10` on hub) is a Cilium `LoadBalancer` IP announced
over L2 (`CiliumL2AnnouncementPolicy`). `enable-l2-announcements` is **not hot-reloadable** —
if it's flipped on in the `cilium-config` ConfigMap after the agent pods already started, every
agent logs `config-drift-checker ... key=enable-l2-announcements actual=false expectedValue=true`
and no node actually answers ARP for the IP, so the Gateway is unreachable from anywhere even
though the `HTTPRoute`/`Gateway` objects themselves look perfectly healthy. Fix: `kubectl -n
kube-system rollout restart daemonset cilium`.

### Publicly-trusted certs: `gateway.publicCertificates`

`gateway.tls` only covers the one self-signed `home-arpa-tls` cert for `*.home.arpa` --
browsers warn on it by design (see above), which is fine for a LAN-only hostname but not for a
real public domain like `wion.trade` that external-dns actually publishes to Cloudflare.
`gateway.publicCertificates` is a list of `{secretName, clusterIssuerName, dnsNames}`; each
entry becomes its own `cert-manager.io/v1 Certificate` (`templates/tls-public.yaml`) issued by
a real `ClusterIssuer` (e.g. `letsencrypt`, see `helmcharts/cert-manager`'s
`letsEncryptClusterIssuer`), not the gateway's local self-signed `Issuer`. The resulting Secret
still has to be added to the `https` listener's `certificateRefs` by hand in `values/hub.yaml`
-- `envListeners` is plain data, not generated from this list, so SNI only picks it up once
it's listed there too.

Let's Encrypt's HTTP-01 challenge can't issue wildcards, so each entry needs its exact
hostnames listed (e.g. `argocd.wion.trade`, not `*.wion.trade`).
