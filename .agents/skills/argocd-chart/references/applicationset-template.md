# ApplicationSet templates

New file goes at `helmcharts/argocd-apps/templates/applicationsets/<component>-as.yaml`. Pick the
shape that matches the source.

## Shape A — chart lives in this repo (the normal case for a vendored artifacthub chart)

Model on `helmcharts/argocd-apps/templates/applicationsets/cert-manager-as.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: <component>
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "<pick based on dependency ordering, see below>"
spec:
  generators:
    - clusters:
        selector:
          matchExpressions:
            - key: environment
              operator: In
              values:
                - hub
  syncPolicy:
    applicationsSync: sync
    preserveResourcesOnDeletion: false

  template:
    metadata:
      name: {{`"{{name}}-<component>"`}}
      namespace: argocd
      labels:
        cluster: {{`"{{name}}"`}}
        environment: {{`"{{metadata.labels.environment}}"`}}
      annotations:
        argocd.argoproj.io/manifest-generate-paths: "."
        argocd.argoproj.io/sync-wave: "<same as above>"
    spec:
      project: default
      source:
        repoURL: git@github.com:defyjoy/ArgoCD.git
        targetRevision: HEAD
        path: helmcharts/<component>
        helm:
          valueFiles:
            - values.yaml
            - {{ `"values/{{metadata.labels.environment}}.yaml"` }}
          ignoreMissingValueFiles: true
      destination:
        server: {{ `"{{server}}"` }}
        namespace: <component>
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: false
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
          - RespectIgnoreDifferences=true
          - PruneLast=true
```

Only gate on `hub` right now — there is no `dev` cluster yet (per CLAUDE.md). Don't add `dev` to
the `values:` list speculatively.

## Shape B — in-house app / raw manifests (not an upstream artifacthub chart)

Use the `/new-app` command's chart+ApplicationSet scaffold instead of this skill — it already
covers CoreDNS, cluster labels, and the HTTPRoute/Deployment/Service template set for in-house
services. This skill is specifically for pulling in a third-party component from artifacthub.io.

## Sync-wave ordering

Check existing ApplicationSets' `argocd.argoproj.io/sync-wave` annotations for anything the new
component genuinely depends on (e.g. it needs `cert-manager` or `external-secrets` first), and
pick a wave number after those. Don't invent an elaborate wave scheme if nothing in the new
component has an ordering dependency — omitting the annotation (default wave `0`) is fine when
there's no real ordering constraint.

## Cluster label gating

If the component needs to be selectively deployed (not every app needs to be on every cluster
label), add a dedicated label to `helmcharts/argocd/templates/cluster/hub-cluster-secret.yaml`
and gate the generator on `matchLabels: { <component>: "true" }` instead of the blanket
`environment In [hub]` shown above. Never `kubectl label` the live `hub` secret directly — add
the label in the template and let the self-managed `argocd` Application apply it.
