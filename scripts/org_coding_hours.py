#!/usr/bin/env python3

"""
Compute coding hours across multiple GitHub repositories using the git-hours CLI.

This script expects two environment variables:

  REPOS        – a space‑separated list of GitHub repositories in owner/name form.
  WINDOW_START – optional start date (YYYY‑MM‑DD) passed through to git-hours as -since.

For each repository, the script performs a shallow clone, runs git-hours, and collects
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

# Parse environment variables. Split the REPOS string into individual entries.
REPOS = os.getenv("REPOS", "").split()
SINCE = os.getenv("WINDOW_START", "")

# Ensure the user provided at least one repository; otherwise exit with an error.
if not REPOS:
    sys.exit("REPOS env var must list repositories to process")

def run_git_hours(repo: str) -> dict:
    """Clone the given repository and run git-hours (optionally with -since)."""
    with tempfile.TemporaryDirectory() as temp:
        # Shallow clone (depth=1) for efficiency; only fetch the latest history.
        subprocess.run(
            ["git", "clone", "--depth", "1", f"https://github.com/{repo}.git", temp],
            check=True,
        )
        cmd = ["git-hours"]
        if SINCE:
            cmd.extend(["-since", SINCE])
        out = subprocess.check_output(cmd, cwd=temp, text=True)
        return json.loads(out)

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
        name = repo.replace('/', '_')
        (reports / f"git-hours-{name}-{date}.json").write_text(json.dumps(data, indent=2))
    # Write aggregated report.
    (reports / f"git-hours-aggregated-{date}.json").write_text(json.dumps(agg, indent=2))
    # Output aggregated JSON to console for reference.
    print(json.dumps(agg, indent=2))

if __name__ == "__main__":
    main()