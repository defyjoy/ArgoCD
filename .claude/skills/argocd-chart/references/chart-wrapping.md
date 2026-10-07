# Vendoring a third-party chart as an umbrella chart

This repo never hand-copies an upstream chart's templates in. It wraps the upstream chart as a
Helm dependency and vendors it, following the pattern in `helmcharts/cert-manager`.

## Chart.yaml

```yaml
apiVersion: v2
name: <component>
description: A Helm chart for <component> - <one-line upstream description>
type: application
version: 0.1.0
appVersion: "<pinned upstream appVersion>"

dependencies:
  - name: <component>
    version: <pinned chart version from artifacthub, confirmed non-RC>
    repository: <upstream repo URL, from artifacthub>
    condition: enabled
```

`version` here (this repo's own chart version) starts at `0.1.0` and is bumped on future changes
to this wrapper — it is independent of the upstream chart version pinned in `dependencies`.

## Vendor it

```bash
helm dependency update helmcharts/<component>
```

This produces `Chart.lock` and a `charts/` directory — commit both. Never edit `charts/` by
hand; re-run `helm dependency update` after bumping the pinned version in `Chart.yaml`.

## values.yaml / values/hub.yaml

- `values.yaml` holds whatever defaults apply everywhere; nest upstream chart values under the
  dependency's release name key (check the upstream chart's own values.yaml / README for its
  top-level keys) plus an `enabled: true` the `condition:` above reads.
- Only create `values/hub.yaml` if something is genuinely cluster-specific (hostnames, tunnel
  IDs, resource sizing tuned to this cluster). Don't create an empty overlay file speculatively.
- No comments in either file — `task lint:values` enforces this. Explain rationale in the
  README instead.
- If the chart ships a `ServiceMonitor`/`PodMonitor` under a values toggle, leave it enabled;
  `victoria-metrics-operator` scrapes it automatically with no extra config.
- Secrets never go in values — wire them through Vault + External Secrets per CLAUDE.md's
  `appVarsKeys`/`secretKeyRefs` rules, and never duplicate a Vault-sourced value as a literal
  `env` entry in this chart's values (it would silently win over anything ESO injects).

## README.md

Minimum sections: what the chart is, upstream chart name + artifacthub link + pinned version,
which cluster(s) it targets, and a `## Configuration` section. For every non-default value this
wrapper sets, show the YAML snippet and explain why in prose next to it — don't just restate the
key name.
