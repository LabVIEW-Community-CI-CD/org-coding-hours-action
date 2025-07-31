# Org Coding Hours Action

This composite GitHub Action calculates coding hours across one or more repositories, aggregates the per‑contributor statistics, generates JSON reports, builds a simple KPI website, and publishes both the metrics and the site to dedicated branches. The action encapsulates the logic from the `Org Coding Hours` workflow in the LabVIEW icon editor project.

## Inputs

| Name | Required | Default | Description |
|-----|---------|---------|-------------|
| `repos` | Yes | – | A space‑separated list of repositories in `owner/name` form. Each repository is cloned and processed by the `git‑hours` CLI. |
| `window_start` | No | – | Optional start date (`YYYY‑MM‑DD`) passed to `git‑hours -since` to limit the reporting window. |
| `metrics_branch` | No | `metrics` | The branch where the JSON reports are committed. |
| `pages_branch` | No | `gh-pages` | The branch where the generated KPI website is committed (enables GitHub Pages). |

## Outputs

This action does not currently expose explicit outputs. Instead it writes per‑repository and aggregated JSON files into a `reports/` directory, builds a static site in `site/`, commits the reports to the `metrics_branch`, and commits the site to the `pages_branch`. The commit history on those branches serves as the record of your organization’s coding hours.

## Example workflow

To invoke this action from a workflow, ensure that your workflow has write permissions to contents and that your repository settings enable publishing from the specified `pages_branch` (typically `gh-pages`).

```yaml
name: Org Coding Hours Report

on:
  workflow_dispatch:
    inputs:
      repos:
        description: 'Space‑separated list of repositories'
        required: true
      window_start:
        description: 'Optional start date YYYY‑MM‑DD'
        required: false

permissions:
  contents: write

jobs:
  org-report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Org Coding Hours Action
        uses: ./org-coding-hours-action
        with:
          repos: ${{ github.event.inputs.repos }}
          window_start: ${{ github.event.inputs.window_start }}
```

This workflow triggers manually through the GitHub UI. When run, it computes coding hours across the specified repositories, writes JSON reports to the `metrics` branch, and publishes the KPI website to the `gh-pages` branch.

### Using in other repositories

To run the action from another repository, reference it by its owner, repository name, and a tag:

```yaml
- name: Run Org Coding Hours Action
  uses: other-org/org-coding-hours-action@v1
  with:
    repos: owner1/repo1 owner2/repo2
```

Replace `other-org` with the organization that hosts this action.
## Continuous Integration

The repository includes a workflow at `.github/workflows/ci.yml` that compiles the Python helper scripts and runs [actionlint](https://github.com/rhysd/actionlint) on every push and pull request.

## Notes

* The action installs a specific version of `git‑hours` (v0.1.2) using Go 1.24 and executes a Python helper script. If you want to update the version, modify the clone command in `action.yml` accordingly.
* Both branches (`metrics_branch` and `pages_branch`) are created automatically if they do not exist. Subsequent runs will update the existing branches without force‑pushing unless a non‑fast‑forward update is required.

## Development and Release

A workflow at `.github/workflows/release.yml` compiles the Python helper scripts on each push and pull request. When a GitHub release is created, the same workflow uploads the action files as assets so they can be downloaded with the release.
The CI workflow at `.github/workflows/ci.yml` runs the same checks on every push and pull request.
