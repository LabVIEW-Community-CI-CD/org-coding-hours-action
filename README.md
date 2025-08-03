# Org Coding Hours Action 🕒

[![CI Status](https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action/actions/workflows/ci.yml) 
[![Latest Release](https://img.shields.io/github/v/release/LabVIEW-Community-CI-CD/org-coding-hours-action?sort=semver)](https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action/releases)

## Overview

**Org Coding Hours** is a GitHub Action that aggregates **per-contributor coding hours** across one or more repositories. It uses the [`git-hours`](https://github.com/trinhminhtriet/git-hours) utility to estimate how many hours each contributor has spent (based on commit timestamps), and produces JSON summary reports. Optionally, it can also generate a **static HTML dashboard** and publish both the JSON metrics and the site to dedicated branches (for example, to host on GitHub Pages). This action is ideal for tracking contributor effort across multiple projects in an organization, whether for open-source volunteer tracking or internal metrics.

Key features and benefits:

- **Aggregate commit hours across repos** – Analyze one repository or an entire org (supports wildcards like `my-org/*`). The action outputs a combined **organization-wide report** as well as per-repository breakdowns.
- **Works with private repos** – Private repositories are supported. The action will use the provided `GITHUB_TOKEN` (or a supplied PAT) to authenticate `git` clones via HTTPS for private repositories.
- **Zero external dependencies** – No need to install languages or packages manually. The action automatically uses a pinned version of the `git-hours` binary (default v0.1.2) and includes a built-in Python script for data processing. Everything runs within the GitHub Actions runner via a Docker container, so runtime requirements are fully contained.
- **Flexible output** – Use the JSON reports directly (e.g. for further processing or archival), or generate a lightweight **dashboard** to visualize commit hours and commits per contributor. You can let the action publish the results to your repository (in a metrics branch and a Pages branch) or handle the publishing in a separate workflow job.
- **Seamless GitHub Pages integration** – When configured, the action can push a static site with the latest metrics to a Pages branch (e.g. `gh-pages`), eliminating the need for a separate site generation workflow.
- **Deterministic and automated releases** – This repository follows semantic versioning for tags (e.g. `v7`, `v7.0.0`). Releases are automated via GitHub Actions: when a new version is prepared, a Git tag is created and a GitHub Release is published using the GitHub CLI with `--generate-notes` to auto-generate the changelog. (See [Release Process](#release-process) for details.)

## Inputs

This action supports the following inputs:

| **Input Name**   | **Required?** | **Default**    | **Description** |
|------------------|--------------|---------------|-----------------|
| `repos`          | **Yes**      | *(none)*      | List of repositories to process, in `owner/repo` format. Separate multiple entries with spaces or newlines. Supports wildcards (e.g. `my-org/*` for all repositories in an organization). **Each repository listed will be cloned and analyzed**. |
| `window_start`   | No           | *(none)*      | Optional start date (`YYYY-MM-DD`) for the reporting window. Commits before this date will be ignored. If not set, the default is effectively “30 days ago” (as determined by the `git-hours` tool). Use this to limit the metrics to a recent timeframe (e.g. quarterly reports). |
| `metrics_branch` | No           | `metrics`     | Name of the branch where JSON report snapshots should be committed. If provided, the action will commit the contents of the `reports/` directory to this branch. If this branch doesn’t exist, it will be created. *(Tip: use a dedicated branch like `metrics` to keep data separate from code.)* |
| `pages_branch`   | No           | *(none)*      | Name of the branch for the static website. If set **along with** `metrics_branch`, the action will generate a dashboard under a `site/` directory and commit it to this branch (enabling GitHub Pages hosting). Typically set this to `gh-pages`. If not set, no site will be generated or published. |
| `git_hours_version` | No       | `v0.1.2`      | Version tag of the **git-hours** CLI to use. By default, a known stable version is included. You can override this to use a specific release of `git-hours`. |

> **Note:** All inputs are strings. If an input is left at default (e.g. `pages_branch` not provided), that feature is disabled as described above.

## Outputs

This action produces two outputs that can be consumed in subsequent steps or jobs:

- **`aggregated_report`** – The file path (within the workspace) to the aggregated JSON report. If multiple repositories were processed, this points to the combined report (summing all repos). If only one repository was processed, this points to that repository’s JSON file (so you don’t have to handle two cases).
- **`repo_slug`** – A URL/filename-safe identifier derived from the `repos` input. All slashes (`/`) and whitespace in the repository list are replaced with underscores. This is useful for naming artifacts or distinguishing outputs for different repo sets. For example, if `repos: foo/bar baz/qux`, the `repo_slug` will be `foo_bar-baz_qux`. If a single repo `my-org/my-repo` is processed, `repo_slug` will be `my-org_my-repo`.

In addition to outputs, the action writes files to the workspace in a structured way:

```text
reports/
├─ git-hours-aggregated-YYYY-MM-DD.json    # Aggregated report (all repos combined)
├─ git-hours-<repo_slug1>-YYYY-MM-DD.json  # Individual repo report (one per repo)
├─ git-hours-<repo_slug2>-YYYY-MM-DD.json  
└─ ... (etc., one JSON file for each repository)
```

If a dashboard site is generated (when `pages_branch` is set), the site files are placed in a `site/` directory:

```text
site/
├─ index.html             # Dashboard homepage (summary and tables)
├─ git-hours-latest.json  # Copy of the latest aggregated JSON (for dynamic or external use)
└─ data/
    └─ *.json             # Historical JSON snapshots (each run’s aggregated report, including the latest)
```

Each JSON report (per repo or aggregated) contains a `"total"` object with total hours and commits, and then one entry per contributor (keyed by email or username) with their own hours and commit count.

## Example Usage

To use this action in a workflow, reference it by its repository and version tag. For example, to run a report across multiple repositories and save the JSON outputs as an artifact:

```yaml
name: Organization Coding Hours Report

on:
  workflow_dispatch:
    inputs:
      repos:
        description: "Space-separated list of repositories (owner/name format)"
        required: true
      window_start:
        description: "Optional start date (YYYY-MM-DD)"
        required: false

permissions:
  contents: write   # required for pushing to branches (metrics/pages)
  # pages: write    # (only if using Pages deployment action separately)

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Org Coding Hours Action
        uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v7
        with:
          repos: ${{ github.event.inputs.repos }}
          window_start: ${{ github.event.inputs.window_start }}
          # metrics_branch: metrics    # (optional) enable branch push for JSON
          # pages_branch: gh-pages     # (optional) enable Pages dashboard

      - name: Upload JSON reports
        uses: actions/upload-artifact@v4
        with:
          name: coding-hours-json
          path: reports/
```

### Publishing the Dashboard

There are two ways to publish the static HTML dashboard with the results:

- **Let the action handle it (automatic):** If you specify both `metrics_branch` and `pages_branch` inputs, the action will take care of committing the JSON files to the `metrics_branch` and generating the site in `site/` and committing it to `pages_branch`. No extra jobs are required in your workflow. For example, you could add to the above step:

  ```yaml
        with:
          repos: ${{ github.event.inputs.repos }}
          window_start: ${{ github.event.inputs.window_start }}
          metrics_branch: metrics    # branch to store JSON reports
          pages_branch: gh-pages     # branch to publish the site
  ```

  With those inputs, the action will push commits to the `metrics` branch (containing the JSON under a `reports/` folder) and to the `gh-pages` branch (containing the `site/` dashboard). Ensure the `GITHUB_TOKEN` or PAT in use has permission to push to those branches. Once the Pages branch is updated, if GitHub Pages is configured for that branch, the site will be available (for example, at `https://<your-org>.github.io/<your-repo>/`).

- **Handle it in workflow jobs (manual):** If you prefer more control or to integrate with an existing documentation site, you can run the action to produce JSON (without setting `pages_branch`), then generate or integrate the site in a separate job. For example, you might have a first job that runs the action and uploads the JSON artifact, and a second job that downloads this artifact, runs a custom script to build a webpage (or uses the same logic as this action’s site generator), and then deploys it (perhaps via the official `actions/upload-pages-artifact` and `actions/deploy-pages` actions). This manual approach is useful if you want to customize the HTML or combine the data with other metrics.

Both approaches achieve the same outcome: a JSON record of coding hours and an optional live dashboard. The automatic mode is simpler if you’re happy with the default dashboard and want a quick setup. The manual mode is there if you need flexibility.

> **Tip:** If you use the automatic publishing (setting `metrics_branch`/`pages_branch`), you typically do **not** need to include an `actions/upload-artifact` step for the JSON, since the data is already preserved in the repository branches. However, you may still upload it as an artifact if you want a backup or to use the data outside GitHub.

## Release Process

This project uses **semantic versioning** for its action releases (e.g. v1.0.0, v2.1.3). The release process is designed to be deterministic and fully automated for consistency and reliability:

- **Version bumps:** New versions are tagged when meaningful changes are introduced (features, fixes, etc.). The versioning follows semantic rules: **MAJOR.MINOR.PATCH**. Breaking changes or major new features increase the major version, new functionality without breaking existing usage increases the minor version, and patches/bugfixes increment the patch number.
- **Automated GitHub Releases:** When a new version is ready, the maintainers trigger an automated workflow (via a pull request merge or manual dispatch) that creates a **signed Git tag** (e.g. `v7.0.0`) and pushes it to the repository. A GitHub Actions workflow then uses the GitHub CLI to create a **GitHub Release** for that tag. The release is created with the `--generate-notes` flag, which means the release notes (changelog) are automatically compiled from commit messages and PR descriptions since the last release.
- **Changelog generation:** By using `gh release create --generate-notes`, we ensure the changelog is generated **deterministically** from the history. GitHub will include summaries of changes (for example, PR titles, commit messages like “feat: ...” or “fix: ...”) in the release notes. This removes manual steps and potential human error from the release documentation. You can view the history of changes for each release in the **Releases** section of the repository, which will contain these auto-generated notes.
- **Deterministic outputs:** Every release of the action is a specific tagged commit, so your workflows should reference the action with a version tag (for example, `uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v7`). Using pinned versions guarantees that your CI runs are repeatable and aren’t unexpectedly changed by new updates. (You can always upgrade to a newer version intentionally by updating the tag.)

*(For contributors: if you contribute to this action, the maintainers will handle the tagging and release process. Simply follow conventional commit guidelines (using `feat:`, `fix:`, etc. in commit messages) to help the release notes generation.)*

### Using a different git-hours version

The action downloads a prebuilt [`git-hours`](https://github.com/trinhminhtriet/git-hours) binary from the GitHub release assets at runtime. By default, it fetches version `v0.1.2`, but you can select another release by setting the `git_hours_version` input when invoking the action. No manual rebuild of the container is required.

## Additional Notes and Best Practices

- **Runner requirements:** This action runs inside a Docker container and thus **requires a Linux runner** (e.g., `ubuntu-latest`). Ensure your workflow uses an appropriate runner, as Windows and macOS runners are not supported for container actions.
- **Authentication and permissions:** If you are analyzing private repositories, make sure the job’s GITHUB_TOKEN has access to those repos. In an organization, the default token usually has access to org repositories, but in some cases (forked repositories or when using a fine-grained PAT) you may need to supply a Personal Access Token with `repo` scope and pass it to the action (e.g., via an input or as the `GITHUB_TOKEN` env override). The action automatically uses the `GITHUB_TOKEN` environment variable for git clone authentication. Also, if using the branch-push features (`metrics_branch`/`pages_branch`), the token must have **write permission** to contents (and to Pages, if publishing a Pages branch). On forked repositories, GitHub’s default token has read-only permissions, so you’ll need to explicitly enable workflow permissions or use your own PAT.
- **Graceful failure behavior:** The action is designed to fail fast if something goes wrong (it will exit with an error if any repository cannot be cloned or if the `git-hours` tool encounters an issue). This will mark the step as failed, preventing later steps from using incomplete data. If no commits are found within the `window_start` range (resulting in zero hours), the JSON reports will still be generated (with totals of 0 hours) rather than causing a failure. In other words, an “empty” result is considered a successful run (the absence of a `reports/` directory would indicate a failure earlier in the process). If you want to handle a “no data” scenario more gracefully, you can add a check in your workflow after the action step. For example, you might include a step to verify that the `reports/` directory exists (and perhaps contains the expected files) before trying to upload or use them.
- **Pinned tool versions:** The action pins the `git-hours` tool version by default (v0.1.2) to ensure consistent behavior. You can override `git_hours_version` if a new version of the tool is released and you want to try it, but note that the Docker image must include or install that version for the change to take effect.
- **Performance considerations:** Analyzing many repositories can take several minutes, especially with large commit histories. Consider narrowing the `window_start` or running the action on a scheduled workflow (e.g., weekly) for long-term tracking.
