#!/usr/bin/env python3

"""
Compute coding hours across multiple GitHub repositories using the git-hours CLI.

This script expects environment variables:
  REPOS         – space-separated list of GitHub repositories in owner/name form.
  WINDOW_START  – optional start date (YYYY-MM-DD) for the reporting window.
  METRICS_BRANCH – optional branch name for committing JSON reports.
  PAGES_BRANCH   – optional branch name for committing the dashboard site (requires METRICS_BRANCH).
  
For each repository, the script performs a full clone, runs git-hours, and collects
the per-contributor statistics. All results are aggregated into a single report that
sums hours and commits across repositories. Per-repository and aggregated JSON files
are written into a 'reports' directory. If configured, the script will also commit the
reports to the specified branch(es) and generate an HTML dashboard site.
"""

import json
import os
import pathlib
import subprocess
import tempfile
import datetime
import sys
import re
import shutil

# Parse environment variables.
REPOS = os.getenv("REPOS", "").split()
SINCE = os.getenv("WINDOW_START", "")
METRICS_BRANCH = os.getenv("METRICS_BRANCH", "")
PAGES_BRANCH = os.getenv("PAGES_BRANCH", "")

# Ensure at least one repository was provided.
if not REPOS or REPOS == [""]:
    sys.exit("REPOS env var must list repositories to process")

def run_git_hours(repo: str) -> dict:
    """Clone the given repository and run git-hours (optionally with -since)."""
    with tempfile.TemporaryDirectory() as temp:
        # Clone the repository (full history for analysis). Use token for private repos if available.
        token = os.getenv("GITHUB_TOKEN")
        url = f"https://github.com/{repo}.git"
        if token:
            url = f"https://x-access-token:{token}@github.com/{repo}.git"
        subprocess.run(["git", "clone", "--quiet", url, temp], check=True)
        cmd = ["git-hours"]
        if SINCE:
            cmd.extend(["-since", SINCE])
        output = subprocess.check_output(cmd, cwd=temp, text=True)
        return json.loads(output)

def slugify(text: str) -> str:
    """Return a string safe for artifact names (e.g., replace slashes and spaces)."""
    text = text.replace("/", "_")
    return re.sub(r"[^0-9A-Za-z._-]+", "_", text)

def aggregate(results: list[dict]) -> dict:
    """Aggregate per-contributor results across multiple repositories."""
    agg = {"total": {"hours": 0, "commits": 0}}
    for data in results:
        for email, rec in data.items():
            if email == "total":
                continue
            entry = agg.setdefault(email, {"hours": 0, "commits": 0})
            entry["hours"] += rec["hours"]
            entry["commits"] += rec["commits"]
            agg["total"]["hours"] += rec["hours"]
            agg["total"]["commits"] += rec["commits"]
    return agg

def commit_to_branch(branch: str, source_path: pathlib.Path):
    """Commit the contents of source_path to the specified branch of the current repo (creating branch if needed)."""
    token = os.getenv("GITHUB_TOKEN")
    repo_slug = os.getenv("GITHUB_REPOSITORY")
    if not token or not repo_slug:
        raise RuntimeError("GITHUB_TOKEN or GITHUB_REPOSITORY not set; cannot push to branch")
    url = f"https://x-access-token:{token}@github.com/{repo_slug}.git"
    tmp_dir = tempfile.mkdtemp()
    # Clone the repository (shallow clone of default branch)
    subprocess.run(["git", "clone", "--depth", "1", url, tmp_dir], check=True)
    repo_path = pathlib.Path(tmp_dir)
    # Fetch the target branch if it exists
    subprocess.run(["git", "fetch", "origin", branch], cwd=repo_path, check=False)
    branch_existed = True
    try:
        # Checkout the branch (or create tracking branch if remote exists)
        subprocess.run(["git", "checkout", "-B", branch, f"origin/{branch}"], cwd=repo_path, check=True)
    except subprocess.CalledProcessError:
        # Branch does not exist on remote; create a new orphan branch
        subprocess.run(["git", "checkout", "--orphan", branch], cwd=repo_path, check=True)
        branch_existed = False
    # If new branch, remove all existing files from working tree
    if not branch_existed:
        for item in repo_path.iterdir():
            if item.name == ".git":
                continue
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
    # Copy contents of source_path into the repo working directory
    source_path = pathlib.Path(source_path)
    if source_path.is_dir():
        for root, _, files in os.walk(source_path):
            rel_root = pathlib.Path(root).relative_to(source_path)
            dest_root = repo_path / rel_root
            dest_root.mkdir(exist_ok=True)
            for name in files:
                src_file = pathlib.Path(root) / name
                dest_file = dest_root / name
                shutil.copy2(src_file, dest_file)
    else:
        shutil.copy2(source_path, repo_path / source_path.name)
    # Commit and push changes
    subprocess.run(["git", "add", "."], cwd=repo_path, check=True)
    subprocess.run(["git", "config", "user.name", "github-actions"], cwd=repo_path, check=True)
    subprocess.run(["git", "config", "user.email", "actions@users.noreply.github.com"], cwd=repo_path, check=True)
    # If no changes (e.g., identical files), skip commit to avoid errors
    diff_result = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=repo_path)
    if diff_result.returncode == 0:
        print(f"No changes to commit for branch '{branch}'")
    else:
        subprocess.run(["git", "commit", "-m", f"Update {branch} data"], cwd=repo_path, check=True)
        subprocess.run(["git", "push", "-u", "origin", branch], cwd=repo_path, check=True)

def main():
    """Main entry point: run git-hours for each repo, aggregate results, and handle outputs."""
    results = {}
    for repo in REPOS:
        print(f"Processing {repo}")
        results[repo] = run_git_hours(repo)
    agg = aggregate(list(results.values()))
    date = datetime.date.today().isoformat()
    reports_dir = pathlib.Path("reports")
    reports_dir.mkdir(exist_ok=True)
    # Write per-repository JSON reports
    for repo, data in results.items():
        name = slugify(repo)
        report_path = reports_dir / f"git-hours-{name}-{date}.json"
        report_path.write_text(json.dumps(data, indent=2))
    # Write aggregated JSON report
    aggregated_path = reports_dir / f"git-hours-aggregated-{date}.json"
    aggregated_path.write_text(json.dumps(agg, indent=2))
    # Determine output file path for aggregated_report output
    repo_slugs = [slugify(r) for r in REPOS]
    repo_slug = "-".join(repo_slugs)
    if len(REPOS) == 1:
        output_path = reports_dir / f"git-hours-{repo_slug}-{date}.json"
    else:
        output_path = aggregated_path
    # Set action outputs if running inside GitHub Actions
    github_output = os.getenv("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as fh:
            print(f"aggregated_report={output_path}", file=fh)
            print(f"repo_slug={repo_slug}", file=fh)
    # Print aggregated JSON to the console (for reference in logs)
    print(json.dumps(agg, indent=2))
    # If branch publishing is configured, push reports and site to the specified branches
    if METRICS_BRANCH:
        print(f"Pushing reports to branch '{METRICS_BRANCH}'...")
        commit_to_branch(METRICS_BRANCH, reports_dir)
    if METRICS_BRANCH and PAGES_BRANCH:
        print(f"Generating site and publishing to branch '{PAGES_BRANCH}'...")
        # Build the dashboard site under 'site/' directory
        site_dir = pathlib.Path("site")
        site_dir.mkdir(exist_ok=True)
        (site_dir / "data").mkdir(exist_ok=True)
        # Copy aggregated JSON to site directory (latest and in data for archival)
        shutil.copy(aggregated_path, site_dir / "git-hours-latest.json")
        shutil.copy(aggregated_path, site_dir / "data" / aggregated_path.name)
        # Create a simple HTML dashboard page
        total_hours = agg["total"]["hours"]
        total_commits = agg["total"]["commits"]
        repo_count = len(REPOS)
        contributors = [(email, data["hours"], data["commits"]) for email, data in agg.items() if email != "total"]
        contributors.sort(key=lambda x: x[1], reverse=True)
        rows_html = "".join(f"<tr><td>{email}</td><td>{hours}</td><td>{commits}</td></tr>" for email, hours, commits in contributors)
        html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>Coding Hours Dashboard</title>
</head>
<body>
<h1>Coding Hours Report</h1>
<p><strong>Total Hours:</strong> {total_hours} &nbsp; <strong>Total Commits:</strong> {total_commits} &nbsp; <strong>Repositories:</strong> {repo_count}</p>
<table border='1' cellpadding='5' cellspacing='0'>
<tr><th>Contributor</th><th>Hours</th><th>Commits</th></tr>
{rows_html}
</table>
</body>
</html>"""
        (site_dir / "index.html").write_text(html_content)
        # Commit and push the site branch
        commit_to_branch(PAGES_BRANCH, site_dir)

if __name__ == "__main__":
    main()
