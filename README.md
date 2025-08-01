# Org Coding Hours Action 🕒  `v6`

Generate **per‑contributor coding‑hour metrics** for one or many repositories, then (optionally) publish
those JSON reports and a static KPI dashboard to GitHub Pages.

|    |  |
|----|--|
| **Latest tag** | `v6` |
| **Marketplace** | *Coming soon* |
| **License** | MIT |

---

## 1 ‑ Why would I use this?

* **Quick KPI snapshots** – track volunteer or contractor effort across all repos in your org.  
* **Works on public *and* private repos** – private repos require `GITHUB_TOKEN` (or a PAT) to authenticate clones. Only GitHub’s REST API is used.
* **Zero runtime deps** – the action bundles [`git‑hours`](https://github.com/kimmobrunfeldt/git-hours); no npm/pip install.  
* **Straight‑to‑Pages workflow** – set two optional inputs and *build‑site/deploy* jobs disappear.  

---

## 2 ‑ Usage at a glance

| Scenario | Minimum inputs | Extra jobs needed |
|----------|----------------|-------------------|
| **Just want JSON**<br>(you’ll process it yourself) | `repos` | *none* |
| **Want JSON + dashboard**<br>but keep logic in the *workflow* | `repos` | **build‑site**<br>optional **deploy‑pages** |
| **Auto‑publish JSON + dashboard** | `repos`, `metrics_branch`, `pages_branch` | *none* – the action pushes both branches |

---

## 3 ‑ Quick‑start workflows

### 3.1  Single‑job (only JSON)

```yaml
jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v6
        with:
          repos: my-org/*
      - uses: actions/upload-artifact@v4   # upload **everything** in reports/
        with:
          name: git-hours-json
          path: reports/                   # <‑‑ NOT a wildcard
```

### 3.2  Two‑job (JSON → site)

```yaml
jobs:
  report:
    runs-on: ubuntu-latest
    outputs:
      have_reports: ${{ steps.check.outputs.ok }}
    steps:
      - uses: actions/checkout@v4
      - uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v6
        with:
          repos: |
            my-org/project‑A
            my-org/project‑B
      - name: Sanity‑check reports/
        id: check
        run: test -d reports && echo "ok=true" >>"$GITHUB_OUTPUT"
      - uses: actions/upload-artifact@v4
        if: steps.check.outputs.ok == 'true'
        with:
          name: git-hours-json       # <‑‑ MUST match download step
          path: reports/

  build-site:
    needs: report
    if: needs.report.outputs.have_reports == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: git-hours-json       # <‑‑ SAME artifact name
          path: tmp
      # … your existing site‑generation script …
```

*Why the guard?* If `reports/` is missing (e.g. a repo list typo produced no data), the upload step is skipped, so the
download step would otherwise fail with *“Artifact not found”*.

---

## 4 ‑ Inputs

| Name | Required | Default | Notes |
|------|----------|---------|-------|
| `repos` | ✅ | — | Newline *or* space separated list (`owner/repo`). Wildcards allowed: `my‑org/*`. |
| `window_start` | ❌ | *30 days ago* | ISO date `YYYY‑MM‑DD`. |
| `metrics_branch` | ❌ | `metrics` | Commit JSON snapshots here. |
| `pages_branch` | ❌ | *(none)* | If set *and* `metrics_branch` set, a static dashboard is pushed here. |
| `git_hours_version` | ❌ | `v0.1.2` | Pin the bundled `git‑hours` binary. |

See the full schema in [`action.yml`](action.yml).

---

## 5 ‑ Outputs & file layout

```
reports/
├─ git-hours-aggregated-YYYY‑MM‑DD.json   # all repos
├─ git-hours-<repo>-YYYY‑MM‑DD.json       # one per repo
```

If `pages_branch` is enabled:

```
site/
├─ index.html
├─ git-hours-latest.json
└─ data/          # historical snapshots
```

---

## 6 ‑ Troubleshooting

| Symptom | Likely cause & fix |
|---------|-------------------|
| **“Artifact not found”** when another job downloads | 1) Upload step used a *different* `name:` than the download step.<br>2) `reports/` was empty or never created – verify with `run: ls -R`.<br>3) Artifact expired (default 90 days) – raise `retention-days`. |
| `reports/` directory missing | Action failed earlier – check logs for Go/Python install errors. |
| Empty JSON (0 hours) | `window_start` too recent, repo typo, or token lacks access to private repos. |
| Action fails with 403 on a fork | Grant `read` on *actions* and *contents* or use a PAT. |

*(Tip: add the “Sanity‑check reports/” step shown above; it prevents downstream jobs from failing if no data is produced.)*

---

## 7 ‑ Change‑log (v6 vs v5)

* **Docs:** Added two‑job workflow & artifact guard to prevent *“artifact not found”* pitfalls.  
* **Defaults:** Documented `git_hours_version` default `v0.1.2`.
* **Internal:** Minor performance tweaks; no breaking input changes.

Older release notes remain [here](CHANGELOG.md).

---

## 8 ‑ Contributing & Support

Please open an issue with:

* Exact **Actions log** snippet  
* Your **workflow YAML** (redact secrets)  
* Output of `ls -R reports` if upload fails

PRs welcome!

---

### References

* GitHub Actions workflow syntax –  
* `actions/upload-artifact` wildcard behaviour –  
