# Org Coding Hours Action 🕒

Generate **per‑contributor coding‑hour metrics** for one or many repositories, then (optionally) publish
those JSON reports and a static KPI dashboard to GitHub Pages.

|              |                             |
|--------------|-----------------------------|
| **Latest tag** | `v5` |
| **Marketplace** | _Coming soon_ |
| **License** | MIT |

---

## 1 ‑ Why would I use this?

* **Quick KPI snapshots** – track volunteer or contractor effort across all repos in your org.
* **Works on public *and* private repos** – only GitHub’s REST API is used.
* **Zero runtime deps** – the action bundles the [`git-hours`](https://github.com/kimmobrunfeldt/git-hours) binary; no npm/pip install step required.  
* **Straight‑to‑Pages workflow** – add two optional inputs and the action will commit reports
  to a branch (`metrics_branch`) *and* push a pre‑built static site to another branch
  (`pages_branch`), removing the need for a custom “build‑site” job.

---

## 2 ‑ Quick‑start workflow

```yaml
name: Org Coding Hours
on:
  workflow_dispatch:        # manual trigger
    inputs:
      window_start:
        description: 'Only include commits after YYYY‑MM‑DD'
        required: false

permissions:
  contents: write            # needed for Pages publishing (optional)
  id-token:  write           # needed only for OIDC auth to Pages
  pages:     write

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Org Coding Hours
        uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v5
        with:
          repos: |
            LabVIEW-Community-CI-CD/labview-icon-editor
            LabVIEW-Community-CI-CD/awesome-plugin
          window_start: ${{ github.event.inputs.window_start }}
          # metrics_branch: metrics        # optional
          # pages_branch:   gh-pages       # optional
          # git_hours_version: v1.3.0      # optional

      # Grab everything the action put in ./reports
      - uses: actions/upload-artifact@v4
        with:
          name: git-hours-json
          path: reports/
```

> **Common pitfall**: the upload step must target `reports/**`, not  
> `reports/git-hours-*.json`. The action also drops *per‑repo* files whose names
> do **not** match the wildcard you used, so the artifact may appear missing.  
> Use `ls -R reports` in a debug step if in doubt.

---

## 3 ‑ Inputs

| Input&nbsp;name | Required | Default | Notes |
|-----------------|----------|---------|-------|
| `repos` | ✅ | — | Newline‑separated list of `owner/repo` pairs (max 100). |
| `window_start` | ❌ | *30 days ago* | ISO date (`YYYY‑MM‑DD`). Leave blank for rolling window. |
| `metrics_branch` | ❌ | *(none)* | If set, the action commits JSON snapshots to this branch. |
| `pages_branch` | ❌ | *(none)* | If set *and* `metrics_branch` is set, a static HTML dashboard is also pushed here. |
| `git_hours_version` | ❌ | `latest` | Pin the bundled `git-hours` binary. Useful if upstream behaviour changes. |

---

## 4 ‑ Outputs & file layout

```
reports/
├─ git-hours-aggregated-2025-08-01.json   # all repos combined
├─ git-hours-<repo1>-2025-08-01.json      # per‑repo detail
├─ …                                      # one per listed repo
```

*JSON schema (excerpt)*

```jsonc
{
  "alice":   { "hours": 12.5, "commits": 8 },
  "bob":     { "hours":  7.0, "commits": 5 },
  "total":   { "hours": 19.5, "commits": 13 }
}
```

If you enable `pages_branch`, the action also writes:

```
site/
├─ index.html                  # KPI dashboard (Chart.js + sortable tables)
├─ git-hours-latest.json       # same as aggregated‑<date>.json
└─ data/                       # historical snapshots
```

---

## 5 ‑ Recipes

### 5.1 Publish dashboards automatically

```yaml
with:
  repos: my-org/*
  metrics_branch: metrics
  pages_branch:   gh-pages
```

The action:

1. Commits **only JSON** to `metrics` (keeps history thin).  
2. Builds the static site and force‑pushes the *rendered* artefacts to `gh-pages`.  
3. Emits a deployment URL in the job summary.

### 5.2 Ad‑hoc date windows

Trigger manually and set **window_start = 2024‑01‑01** to regenerate last year’s
numbers without touching the rolling dashboard.

---

## 6 ‑ Troubleshooting

| Symptom | Likely cause & fix |
|---------|-------------------|
| **“No files were found with the provided path…​”** during `upload-artifact` | Path mismatch (see *Outputs* section). List directory with `run: ls -R` to confirm. |
| Reports are empty (0 hours) | 1) `window_start` too recent, 2) repo list typo, or 3) token lacks access to private repos. |
| Action fails with 403 | Running on a *fork* of a private repo: grant `read` on actions and contents, or use a PAT. |
| Need more than 100 repos | Split the list and run the action twice; aggregate the two JSON files later. |

---

## 7 ‑ Change‑log (v5 vs v4)

* **Docs overhaul.** (You’re reading it! 🥳)
* Added **optional** `metrics_branch`, `pages_branch`, `git_hours_version`.
* Minor dependency bumps; *no* breaking input or output changes.

---

## 8 ‑ Contributing & Support

Issues and PRs are welcome.  
Please include:

* **Exact GitHub Actions log** snippet  
* Your **workflow YAML** (trim secrets)  
* Output of `ls -R reports` if the upload step fails

---

### References

* GitHub Actions workflow syntax – <https://docs.github.com/actions>
* `actions/upload-artifact` wildcard behaviour – <https://github.com/actions/upload-artifact#uploading-disregarding-no-files-found>
