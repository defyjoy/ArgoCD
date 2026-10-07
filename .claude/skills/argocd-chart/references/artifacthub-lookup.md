# artifacthub.io lookup

## Search for candidates

```
GET https://artifacthub.io/api/v1/packages/search?kind=0&limit=20&ts_query_web=<component name>
```

`kind=0` restricts results to Helm charts. Read `repository.name`, `repository.url`, and
`package_id` off each hit. Prefer official/verified publisher repos (`repository.verified_publisher`
or `repository.official`) over random forks when more than one chart matches.

## Get full version info for a candidate

```
GET https://artifacthub.io/api/v1/packages/helm/<repoName>/<packageName>
```

The response's top-level `version` is whatever artifacthub currently considers "latest", but
**do not trust that alone** — it can be a pre-release. Check:

- `prerelease` (boolean on the package detail) — if `true`, this version is disqualified.
- `available_versions[]` — each entry has `version` and `ts` (release timestamp). Sort by `ts`
  descending and walk down until you find one that is not a pre-release.
- Treat any version string containing `-rc`, `-alpha`, `-beta`, `-pre`, or a `0.0.0-...`
  SNAPSHOT-style suffix as a release candidate, regardless of the `prerelease` flag — some
  repos don't set it correctly.
- The chart's own `version` vs `appVersion` can diverge (chart packaging version vs upstream app
  version) — pin on the **chart `version`**, since that's what `repository:`/`version:` in
  Chart.yaml's `dependencies:` block needs, but report the `appVersion` too so the user
  recognizes what app release they're getting.

## Present to the user before doing anything else

Show, for each shortlisted candidate: chart name, repository name + URL, the artifacthub package
page URL (`https://artifacthub.io/packages/helm/<repoName>/<packageName>`), the pinned chart
version, and the corresponding app version. Use AskUserQuestion to get explicit confirmation of
one option before writing any files. If the user already named the exact chart, still confirm
the version you're about to pin — don't silently assume they want latest if they didn't say so.
