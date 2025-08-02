# Org Coding Hours Action — **v8 (docs‑only, broken)**  
> **Status:** `main` branch is under active repair.  
> **Tag v8 exists *solely* so other AI assistants can pin a stable README while contributing.  
> **Do NOT** rely on v8 for production metrics ‑‑ it is known broken.

---

## 📜 Purpose of this README
This document is written *for AIs as well as humans*.  
It serves three parallel goals:

1. **Quick‑start guide** for people who want to *use* the action once it is fixed.  
2. **Design & troubleshooting reference** for contributors (human or AI) who wish to *improve* the codebase.  
3. **Interaction contract** that tells large‑language‑model agents exactly *how* to help without trampling each other.

---

## ✨ What the Action *will* do (once fixed)

| Feature | Description |
|---------|-------------|
| **Per‑repo & org‑wide metrics** | Uses the upstream [`git‑hours`](https://github.com/lazypic/git-hours) binary to calculate coding‑hour totals per author, per repository. |
| **Zero runtime deps** | The action downloads a pre‑built `git‑hours` binary; no Go tool‑chain, Node modules, or Python wheels required. |
| **Dashboard optional** | JSON reports are always produced; an *optional* Hugo‑based site can be built & deployed to GitHub Pages for KPI visualisation. |
| **Runs anywhere** | Works on public and private repos (needs a token for private). Linux/macOS runners supported out‑of‑the‑box. |

---

## 🚦 Current blocker (why v8 is “docs‑only”)

*The action fails if it clones a **shallow** repository; `git‑hours` exits with code 1 when it sees `.git/shallow`.*  
The planned fix is to clone with `fetch-depth: 0` **and** migrate to the pre‑built binary so we no longer compile from source. citeturn3view0

---

## 🛠️ Roadmap & Work Policy for AI Assistants

> **☑  Canonical branch structure**  
> * `main` — stable, always releasable  
> * `develop` — integration / feature staging  
> * `feature/*` — short‑lived topics

### 1 — Open issues **before** submitting a PR  
Include a *one‑sentence outline* of the intended change and reference this README section.

### 2 — One concern per PR  
E.g. “replace Go build with binary download” **or** “add Windows runner support”, *not* both.

### 3 — Update this README when:  
* a public interface changes (`action.yml` inputs/outputs)  
* troubleshooting steps or FAQs become outdated

### 4 — Commit message conventions
```
<type>(scope): <subject>

BODY (why not what) …
Fixes #123
```
*Types:* `fix`, `feat`, `docs`, `ci`, `refactor`, `test`, `chore`

### 5 — Label usage (applies to issues & PRs)  
* `needs‑repro` – provide a failing workflow link  
* `good‑first‑task` – scoped, ≤20 LOC change  
* `ai‑friendly` – well‑specified tasks suited to LLM agents  

---

## 🚀 Quick‑start (post‑fix **expected** syntax)

### Minimal “JSON‑only” workflow

```yaml
jobs:
  coding-hours:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }      # full history – **mandatory**
      - uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v9
        with:
          repos: my-org/*
      - uses: actions/upload-artifact@v4
        with:
          name: git-hours-${{ github.run_number }}.json
          path: reports/git-hours.json
```

### Full “JSON + Dashboard + Pages” (outline)

1. **Job A:** run the action → uploads reports  
2. **Job B:** build Hugo site from reports  
3. **Job C:** deploy `public/` to `gh-pages` branch

See [`docs/workflow-examples.md`](docs/workflow-examples.md) once created.

---

## 🔍 Repository tour (AI index)

| Path | Purpose |
|------|---------|
| `.github/actions/git-hours/` | Composite action wrapper around the `git-hours` binary |
| `.github/workflows/ci.yml` | Lint, unit test, generate metrics (no release) |
| `.github/workflows/release.yml` | Tag‑triggered; bundles JSON & (eventually) dashboard |
| `scripts/` | Bash and PowerShell helper scripts, deterministic & shellcheck‑clean |
| `tests/` | Bats & PowerShell‑Pester tests (must pass in CI) |
| `action.yml` | Public interface – **bump `version` on breaking changes!** |

---

## 🧑‍💻 Local development cheat‑sheet

```bash
# Clone with full history (important!)
git clone --depth 0 https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action
cd org-coding-hours-action

# Run shell unit tests
./scripts/test.sh

# Lint composite action (YAML + metadata)
npm exec -y @redhat-plumbers-in-action/action-validator .

# Manual git-hours run against this repo
curl -sL https://github.com/lazypic/git-hours/releases/download/v0.0.6/git-hours_0.0.6_Linux_x86_64.tar.gz  | tar xz git-hours && ./git-hours -format json -output tmp.json .
```

---

## ❓ FAQ (for humans *and* AIs)

**Q.** *Can I run this on Windows self‑hosted runners?*  
**A.** The composite action currently autodetects `Linux‑x86_64` and macOS variants.  
Add a case for `Windows‑x86_64` that fetches the `.zip` asset once tested.

**Q.** *Why not calculate “lines changed” instead of “hours”?*  
**A.** The upstream `git‑hours` heuristic is more robust across file renames and large binary commits.

**Q.** *What if private repos exceed the GitHub API rate limit?*  
**A.** Use a Personal Access Token with `repo` scope via the `token` input; the action will throttle and retry automatically.

---

## 🏁 Contributing next steps
* [ ] **FIX THE SHALLOW‑CLONE BUG** (`fetch-depth: 0` + pre‑built binary)  
* [ ] Tag **v9** once CI is green  
* [ ] Publish to the GitHub Marketplace  
* [ ] Extend metrics to **per‑team aggregates**
