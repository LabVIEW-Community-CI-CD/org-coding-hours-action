import json
import pathlib
import subprocess
import datetime
import runpy


def test_cli_entry_point(tmp_path, monkeypatch):
    script = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "org_coding_hours.py"
    monkeypatch.setenv("REPOS", "owner/repo")
    output_file = tmp_path / "out.txt"
    monkeypatch.setenv("GITHUB_OUTPUT", str(output_file))
    monkeypatch.chdir(tmp_path)

    seen = {}

    def fake_run(cmd, check):
        seen["clone"] = cmd

    def fake_check_output(cmd, cwd, text):
        seen["git_hours_cmd"] = cmd
        return json.dumps({"total": {"hours": 1, "commits": 1}})

    monkeypatch.setattr(subprocess, "run", fake_run)
    monkeypatch.setattr(subprocess, "check_output", fake_check_output)

    class FixedDate(datetime.date):
        @classmethod
        def today(cls):
            return cls(2024, 1, 1)

    monkeypatch.setattr(datetime, "date", FixedDate)

    runpy.run_path(str(script), run_name="__main__")

    assert seen["git_hours_cmd"] == ["git-hours"]

    lines = output_file.read_text().splitlines()
    out = dict(line.split("=", 1) for line in lines)
    assert out["aggregated_report"] == "reports/git-hours-owner_repo-2024-01-01.json"
    assert out["repo_slug"] == "owner_repo"
