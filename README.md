# Org Coding Hours Action – **v9**

Aggregate coding hours across repositories using the [`git-hours`](https://github.com/Kimmobrunfeldt/git-hours) CLI.

## Quick‑start

Add a step to your GitHub Actions workflow:

```yaml
- name: Generate organization coding hours
  uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v9
  with:
    # Root of the repo to analyse (defaults to `.`)
    workdir: .
```

The action installs **git‑hours v1.5.0**, executes it, and stores a `git-hours.json` artifact you can download or attach to releases.

## Inputs

| Name    | Required | Default | Description                         |
|---------|----------|---------|-------------------------------------|
| workdir | false    | `.`     | Path of the repository to analyse   |
| version | false    | `v1.5.0`| Version of git-hours to install     |

## Outputs

| Name        | Description                          |
|-------------|--------------------------------------|
| report-json | Path to the generated `git-hours.json` |

## Example full workflow

```yaml
name: Org Coding Hours

on:
  push:
    branches: [main]

jobs:
  hours:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate report
        uses: LabVIEW-Community-CI-CD/org-coding-hours-action@v9
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: coding-hours
          path: git-hours.json
```

## License

MIT
