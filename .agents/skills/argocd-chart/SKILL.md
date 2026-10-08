---
name: argocd-chart
description: Progressive-disclosure reference for onboarding a new component onto this ArgoCD-managed cluster — looking up a chart on artifacthub.io, vendoring it as an umbrella Helm chart, and wiring up the ApplicationSet. Used by the argocd agent; load only the reference file each step needs.
disable-model-invocation: true
---

# ArgoCD chart onboarding

This skill is reference material, not a script to run start to finish. Load the file for the
step you're on; don't read all of them up front.

- `references/artifacthub-lookup.md` — finding a chart on artifacthub.io, rejecting
  pre-release/RC versions, confirming the latest stable version.
- `references/chart-wrapping.md` — this repo's umbrella-chart pattern for vendoring a
  third-party chart (Chart.yaml dependency, Chart.lock, README conventions).
- `references/applicationset-template.md` — the two ApplicationSet shapes used in this repo
  (chart-in-this-repo vs. git-sourced manifests) and the cluster-label gating convention.

Repo-wide conventions (no comments in values, secrets via Vault, per-cluster overlays,
PodSecurity, `hub` being the only real cluster) live in the repo's `AGENTS.md`, not here — read
that directly rather than looking for a duplicate copy in this skill.
