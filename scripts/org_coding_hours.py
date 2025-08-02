#!/usr/bin/env python3

"""
Compute coding hours across multiple GitHub repositories using the git-hours CLI.

This script expects two environment variables:

  REPOS        – a space‑separated list of GitHub repositories in owner/name form.
  WINDOW_START – optional start date (YYYY‑MM‑DD) passed through to git-hours as -since.

For each repository, the script performs a full clone, runs git-hours, and collects
the per‑contributor statistics. All results are aggregated into a single report that
sums hours and commits across repositories. Per‑repository and aggregated JSON files
are written into a 'reports' directory.
"""

import json
import os
import pathlib
import subprocess
import tempfile
import datetime
import sys
import re

# Parse environment variables. Split the REPOS string into individual entries.
REPOS = os.getenv("REPOS", "").split()
SINCE = os.getenv("WINDOW_START", "")

# Ensure the user provided at least one repository; otherwise exit with an error.
if not REPOS:
    sys.exit("REPOS env var must list repositories to process")

def run_git_hours(repo: str) -> dict:
    """Clone the given repository and run git-hours (optionally with -since)."""
    with tempfile.TemporaryDirectory() as temp:
        # Clone the repository. Fetch the full history so git-hours can analyze
        # all commits. Use GITHUB_TOKEN for authentication if provided.
        token = os.getenv("GITHUB_TOKEN")
        url = f"https://github.com/{repo}.git"
        if token:
            url = f"https://x-access-token:{token}@github.com/{repo}.git"
        subprocess.run([
            "git",
            "clone",
            url,
            temp,
        ], check=True)
        cmd = ["git-hours"]
        if SINCE:
            cmd.extend(["-since", SINCE])
        out = subprocess.check_output(cmd, cwd=temp, text=True)
        return json.loads(out)


def slugify(text: str) -> str:
    """Return a string safe for artifact names."""
    text = text.replace("/", "_")
    return re.sub(r"[^0-9A-Za-z._-]+", "_", text)

def aggregate(results: list[dict]) -> dict:
    """Aggregate per-contributor results across multiple repositories."""
    agg = {"total": {"hours": 0, "commits": 0}}
    for data in results:
        for email, rec in data.items():
            if email == "total":
                continue
            # Create or update the contributor entry.
            entry = agg.setdefault(email, {"hours": 0, "commits": 0})
            entry["hours"] += rec["hours"]
            entry["commits"] += rec["commits"]
            # Update global totals.
            agg["total"]["hours"] += rec["hours"]
            agg["total"]["commits"] += rec["commits"]
    return agg

def main():
    """Main entry point: run git-hours for each repo and write reports."""
    results = {}
    for repo in REPOS:
        print(f"Processing {repo}")
        results[repo] = run_git_hours(repo)
    agg = aggregate(list(results.values()))
    date = datetime.date.today().isoformat()
    reports = pathlib.Path("reports")
    reports.mkdir(exist_ok=True)
    # Write per-repository reports.
    for repo, data in results.items():
        name = slugify(repo)
        (reports / f"git-hours-{name}-{date}.json").write_text(json.dumps(data, indent=2))
    # Write aggregated report.
    agg_path = reports / f"git-hours-aggregated-{date}.json"
    agg_path.write_text(json.dumps(agg, indent=2))

    # Choose which path to expose as the aggregated_report output. When only
    # a single repository is processed, point at that repo's report so callers
    # don't need to handle aggregation separately.
    repo_slugs = [slugify(r) for r in REPOS]
    repo_slug = "-".join(repo_slugs)
    if len(REPOS) == 1:
        output_path = reports / f"git-hours-{repo_slug}-{date}.json"
    else:
        output_path = agg_path

    # If running inside a GitHub Action, expose the path via the output file.
    github_output = os.getenv("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as fh:
            print(f"aggregated_report={output_path}", file=fh)
            print(f"repo_slug={repo_slug}", file=fh)

    # Output aggregated JSON to console for reference.
    print(json.dumps(agg, indent=2))

if __name__ == "__main__":
    main()
