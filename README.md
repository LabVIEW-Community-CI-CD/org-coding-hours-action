# Org Coding Hours Action 🕒

[![CI Status](https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action/actions/workflows/ci.yml) 
[![Latest Release](https://img.shields.io/github/v/release/LabVIEW-Community-CI-CD/org-coding-hours-action?sort=semver)](https://github.com/LabVIEW-Community-Ci-CD/org-coding-hours-action/releases)

## Overview

**Org Coding Hours** is provided as both a composite and Docker container GitHub Action that aggregates **per-contributor coding hours** across one or more repositories. It uses the [`git-hours`](https://github.com/kimmobrunfeldt/git-hours) utility to estimate how many hours each contributor has spent (based on commit timestamps), and produces JSON summary reports. Optionally, it can also generate a **static HTML dashboard** and publish both the JSON metrics and the site to dedicated branches (for example, to host on GitHub Pages). This action is ideal for tracking contributor effort across multiple projects in an organization, whether for open-source volunteer tracking or internal metrics.

Key features and benefits:

- **Aggregate commit hours across repos** – Analyze one repository or an entire org (supports wildcards like `my-org/*`). The action outputs a combined **organization-wide report** as well as per-repository breakdowns.
- **Works with private repos** – Private repositories are supported. The action will use the provided `GITHUB_TOKEN` (or a supplied PAT) to authenticate `git` clones via HTTPS for private repositories.
- **Zero external dependencies** – No need to install languages or packages manually. The action automatically installs a pinned version of the `git-hours` binary (default v0.1.2) using Go 1.24, and uses a built-in Python script for data processing. Everything runs within the GitHub Actions runner.
- **Flexible output** – Use the JSON reports directly (e.g. for further processing or archival), or generate a lightweight **dashboard** to visualize commit hours and commits per contributor. You can let the action publish the results to your repository (in a metrics branch and a Pages branch) or handle the publishing in a separate workflow job.
- **Seamless GitHub Pages integration** – When configured, the action can push a static site with the latest metrics to a Pages branch (e.g. `gh-pages`), eliminating the need for a separate site generation workflow.
- **Deterministic and automated releases** – This repository follows semantic versioning for tags (e.g. `v6`, `v6.1.0`). Releases are automated via GitHub Actions: when a new version is prepared, a Git tag is created and a GitHub Release is published using the GitHub CLI with `--generate-notes` to auto-generate the changelog. (See [Release Process](#release-process) for details.)

## Inputs

The composite action defines the following inputs:

| **Input Name**   | **Required?** | **Default**    | **Description** |
|------------------|--------------|---------------|-----------------|
| `repos`          | **Yes**      | *(none)*      | List of repositories to process, in `owner/repo` format. Separate multiple entries with spaces or newlines. Supports wildcards (e.g. `my-org/*` for all repositories in an organization). **Each repository listed will be cloned and analyzed**. |
| `window_start`   | No           | *(none)*      | Optional start date (`YYYY-MM-DD`) for the reporting window. Commits before this date will be ignored. If not set, the default is effectively “30 days ago” (as determined by the `git-hours` tool). Use this to limit the metrics to a recent timeframe (e.g. quarterly reports). |
| `metrics_branch` | No           | `metrics`     | Name of the branch where JSON report snapshots should be committed. If provided, the action will commit the contents of the `reports/` directory to this branch. If this branch doesn’t exist, it will be created. *(Tip: use a dedicated branch like `metrics` to keep data separate from code.)* |
| `pages_branch`   | No           | *(none)*      | Name of the branch for the static website. If set **along with** `metrics_branch`, the action will generate a dashboard under a `site/` directory and commit it to this branch (enabling GitHub Pages hosting). Typically set this to `gh-pages`. If not set, no site will be generated or published. |
| `git_hours_version` | No       | `v0.1.2`      | Version tag of the **git-hours** CLI to use. By default, a known stable version is installed. You can override this to use a specific release of `git-hours`. |

> **Note:** These inputs correspond to fields in the action’s `action.yml`. All inputs are strings. If an input is left at default (e.g. `pages_branch` not provided), that feature is disabled as described.

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
└─ ... (etc for each repo)
```

If a dashboard site is generated (when `pages_branch` is set), the site files are placed in a `site/` directory:

```text
site/
├─ index.html             # Dashboard homepage (summary and tables)
├─ git-hours-latest.json  # Copy of the latest aggregated JSON (for dynamic charts)
└─ data/
    └─ *.json             # Historical JSON snapshots (including the latest, copied here for archival)
```

The JSON schema: Each JSON report (per repo or aggregated) contains a `"total"` object with total hours and commits, and then one entry per contributor (keyed by email or username) with their own hours and commit count.

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
        uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v6
        with:
          repos: ${{ github.event.inputs.repos }}
          window_start: ${{ github.event.inputs.window_start }}

      - name: Upload JSON reports
        uses: actions/upload-artifact@v4
        with:
          name: coding-hours-json
          path: reports/
```

Alternatively, you can use the Docker container action:

```yaml
      - name: Run Org Coding Hours Action (container)
        uses: LabVIEW-Community-CI-CD/org-coding-hours-action/docker-action@v1
        with:
          repos: ${{ github.event.inputs.repos }}
          window_start: ${{ github.event.inputs.window_start }}
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
- **Deterministic outputs:** Every release of the action is a specific tagged commit, so your workflows should reference the action with a version tag (for example, `uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v6`). Using pinned versions guarantees that your CI runs are repeatable and aren’t unexpectedly changed by new updates. (You can always upgrade to a newer version intentionally by updating the tag.)

*(For contributors: if you contribute to this action, the maintainers will handle the tagging and release process. Simply follow conventional commit guidelines (using `feat:`, `fix:`, etc. in commit messages) to help the release notes generation.)*

## Additional Notes and Best Practices

- **Runner requirements:** This action runs on Linux runners (Ubuntu) and requires access to the internet to clone the target repositories. Ensure your workflow is using an appropriate runner (e.g., `runs-on: ubuntu-latest`).
- **Authentication and permissions:** If you are analyzing private repositories, make sure the job’s `GITHUB_TOKEN` has access to those repos, or provide a PAT (Personal Access Token) with `repo` scope.
- **Graceful failure behavior:** If any repository clone fails or `git-hours` encounters an error, the action will fail, ensuring you are always aware of issues. A successful run requires all repositories to be processed successfully.
- **Pinned tool versions:** The action pins the `git-hours` tool version by default (v0.1.2) to ensure consistent behavior. You can override `git_hours_version` if a new version of the tool is released and you want to try it.
- **Performance considerations:** Analyzing many repositories can take several minutes, especially with large commit histories. Consider narrowing the `window_start` or running the action on a scheduled workflow (e.g. weekly).

## Additional Notes and Best Practices
- **Runner requirements:** This action runs on Linux runners (Ubuntu) and requires access to the internet to clone the target repositories. Ensure your workflow is using an appropriate runner (e.g., runs-on: ubuntu-latest). Windows runners should work in theory (Go, Git, and Python are available) but have not been extensively tested, so we recommend Ubuntu for simplicity.

- **Authentication and permissions:** If you are analyzing private repositories, make sure the job’s GITHUB_TOKEN has access to those repos. In an organization, the default token should have access to org repos, but in some cases (forked repositories or when using a fine-grained PAT) you may need to supply a Personal Access Token with repo scope and pass it to the action. The action will automatically use the GITHUB_TOKEN environment variable for git clone authentication. Also, as noted earlier, if using the branch-push features (metrics_branch/pages_branch), the token must have write permission to contents (and pages if applicable). On forked repositories, GitHub’s default token has read-only permissions, so you’ll need to explicitly enable workflow permissions or use your own token.

- **Graceful failure behavior:** The action is designed to fail fast if something goes wrong (it will exit with an error if any repository cannot be cloned or if the git-hours tool encounters an issue). This will mark the step as failed, preventing later steps from using incomplete data. If no commits are found within the window_start range (resulting in zero hours), the JSON reports will still be generated (with totals of 0 hours) rather than causing a failure. This means an empty result is considered a successful run (the absence of a reports/ directory would indicate a failure earlier in the process). In scenarios where you want to handle “no data” more gracefully, you can add a check in your workflow after the action step. For example, see the “Sanity-check reports/” step in the documentation – basically, verify the reports directory exists before attempting to upload or use it. This can prevent your workflow from erroring out on an empty artifact.

- **Artifact naming and repo_slug:** If you use the action in multiple contexts or with different sets of repositories, take advantage of the repo_slug output to differentiate artifacts. For instance, you can include it in the artifact name: name: hours-${{ steps.my_step.outputs.repo_slug }} so that each run’s artifact is uniquely identified by the repo(s) it covered.

- **Pinned tool versions:** The action pins the git-hours tool version by default (v0.1.2) to ensure consistent behavior. You can override git_hours_version if a new version of the tool is released and you want to try it. The action also uses specific versions of actions (checkout@v4, setup-go@v4, etc.) internally for stability. We recommend you also pin the Org Coding Hours Action itself to a release tag when using it (avoid using @main in production workflows).

- **Performance considerations:** Analyzing many repositories can take several minutes, since each repo must be cloned and processed. The runtime largely depends on the total number of commits in the time window and the number of repositories. The git-hours tool itself is quite fast in parsing commit logs, but network and git clone time can add up. Consider narrowing the window_start to limit history if performance is a concern, or running the action on a schedule (e.g., weekly) rather than on every push.

- **Viewing the dashboard:** If you publish the dashboard to GitHub Pages (either via the action or your own workflow), you can access it at the URL pattern https://<USERNAME or ORG>.github.io/<REPO>/ (for project Pages using the gh-pages branch). The dashboard is a simple static HTML that includes sortable tables and bar charts (using Chart.js) for visualizing the hours and commits per contributor. The site is entirely static (no server needed), so you could also host it on any static file host if desired.

## Troubleshooting tips: Common issues and their solutions:

- “Artifact not found” when downloading in a later job: This usually means the artifact upload step didn’t actually upload anything. Likely causes are (a) the artifact name in the download step doesn’t match exactly the name used in upload, (b) the reports/ directory was empty or never created (the action might have failed or found no data). To debug, you can add a step to list the contents (run: ls -R after the action step) to see if reports/ exists and has files. If the action produced no files but did not error, it could be due to no commits in the range or a repository name typo (check the action logs for each repo processed). Always ensure the artifact upload uses a non-wildcard path (e.g. path: reports/ is correct; using reports/*.json could cause an artifact with just a single file).

- **Action fails with a 403 error on a forked repo:** This indicates the token doesn’t have rights to clone or push. On forks, GitHub restricts the default token’s scopes. You will need to go to the fork repository’s Settings > Actions > General and enable “Workflow permissions: Read and write” for the token or use your own PAT (pass it as a secret and set it in the GITHUB_TOKEN env for the step). Also ensure allow: actions and contents is enabled if needed.
JSON shows 0 hours for all contributors: If the reports are generated but all values are zero, likely the window_start is too recent (no commits in that window) or the repositories were empty/typo’d. Double-check the window_start input and repo names. If the repos are private, also verify the token used has access, otherwise the clone might actually be pulling an empty repository or failing silently.

- **Need to adjust GitHub Pages settings:** If the Pages site isn’t showing up, ensure that your repository’s Pages configuration is set to deploy from the branch name you used (and the root directory). If you used a custom branch like metrics for data and gh-pages for the site, only gh-pages needs to be configured as the Pages source.

## License

This project is open source under the [MIT License](LICENSE). Contributions are welcome! If you encounter issues or have suggestions, please open an issue or pull request in this repository.

Enjoy tracking your coding hours! 🚀
