#!/usr/bin/env python3

"""
Build a simple HTML KPI site from the aggregated git-hours report.

The script locates the latest aggregated report in the reports/ directory, writes it
into the site/data folder, creates a copy named git-hours-latest.json, and generates
an index.html page with a bar chart (using Chart.js) and a sortable table.
"""

import json
import datetime
import pathlib
import html
import textwrap
import shutil

def find_latest_aggregated(reports_dir: pathlib.Path) -> pathlib.Path:
    """Return the most recently modified aggregated report file."""
    candidates = sorted(reports_dir.glob("git-hours-aggregated-*.json"))
    if not candidates:
        raise FileNotFoundError("No aggregated report found in reports/")
    # Pick the newest file based on modification time.
    return max(candidates, key=lambda p: p.stat().st_mtime)

def build_site(agg_path: pathlib.Path):
    """Generate the KPI site based on the aggregated JSON file."""
    data = json.load(agg_path.open())
    total = data["total"]
    # Build a list of contributor labels, excluding the 'total' entry.
    labels = [html.escape(k) for k in data if k != "total"]
    # Build the rows for the detail table.
    rows = "\n".join(
        f"<tr><td>{l}</td><td>{data[l]['hours']}</td><td>{data[l]['commits']}</td></tr>"
        for l in labels
    )
    # Current UTC timestamp.
    updated = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    # Compose the page HTML. Use Simple.css and Chart.js via CDN for styling and charts.
    page = f"""
    <!doctype html><html lang='en'><head>
      <meta charset='utf-8'>
      <title>Organization Coding Hours</title>
      <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/simpledotcss/simple.min.css'>
      <script src='https://cdn.jsdelivr.net/npm/sortable-tablesort/sortable.min.js' defer></script>
      <script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
      <style>canvas{{max-height:400px}}</style>
    </head><body><main>
      <h1>Organization Coding Hours</h1>
      <p><em>Last updated {updated}</em></p>

      <h2>Totals</h2>
      <ul>
        <li><strong>Hours</strong>: {total['hours']}</li>
        <li><strong>Commits</strong>: {total['commits']}</li>
        <li><strong>Contributors</strong>: {len(data) - 1}</li>
      </ul>

      <h2>Hours per contributor</h2>
      <canvas id='hoursChart'></canvas>

      <h2>Detail table</h2>
      <table class='sortable'>
        <thead><tr><th>Contributor</th><th>Hours</th><th>Commits</th></tr></thead>
        <tbody>{rows}</tbody>
      </table>

      <p>Historical JSON snapshots live in <code>/data</code>.</p>

      <script>
        fetch('git-hours-latest.json')
          .then(r => r.json())
          .then(d => {{
            const labels = Object.keys(d).filter(k => k !== 'total');
            const hours  = labels.map(l => d[l].hours);
            new Chart(document.getElementById('hoursChart'), {{
              type: 'bar',
              data: {{ labels, datasets:[{{label:'Hours',data:hours}}] }},
              options: {{
                responsive:true, maintainAspectRatio:false,
                plugins:{{legend:{{display:false}}}},
                scales:{{y:{{beginAtZero:true}}}}
              }}
            }});
          }});
      </script>
    </main></body></html>
    """
    # Prepare the site directory structure.
    site_dir = pathlib.Path("site")
    data_dir = site_dir / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    # Copy the aggregated JSON into data/ with its original name and as git-hours-latest.json at the root.
    shutil.copy(agg_path, data_dir / agg_path.name)
    shutil.copy(agg_path, site_dir / "git-hours-latest.json")
    # Write the index.html page.
    (site_dir / "index.html").write_text(textwrap.dedent(page))

def main():
    reports_dir = pathlib.Path("reports")
    agg_path = find_latest_aggregated(reports_dir)
    build_site(agg_path)

if __name__ == "__main__":
    main()
