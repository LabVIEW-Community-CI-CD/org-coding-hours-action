import json
import os
import pathlib
import sys
os.environ.setdefault("REPOS", "dummy/repo")

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from org_coding_hours import aggregate
from build_site import build_site

import importlib
import datetime


def test_aggregate_basic():
    res1 = {
        "alice@example.com": {"hours": 1, "commits": 2},
        "bob@example.com": {"hours": 2, "commits": 1},
        "total": {"hours": 3, "commits": 3},
    }
    res2 = {
        "alice@example.com": {"hours": 4, "commits": 1},
        "carol@example.com": {"hours": 3, "commits": 2},
        "total": {"hours": 7, "commits": 3},
    }
    agg = aggregate([res1, res2])
    assert agg["alice@example.com"] == {"hours": 5, "commits": 3}
    assert agg["bob@example.com"] == {"hours": 2, "commits": 1}
    assert agg["carol@example.com"] == {"hours": 3, "commits": 2}
    assert agg["total"] == {"hours": 10, "commits": 6}


def test_aggregate_empty():
    assert aggregate([]) == {"total": {"hours": 0, "commits": 0}}


def test_build_site(tmp_path, monkeypatch):
    data = {"total": {"hours": 5, "commits": 3}, "alice@example.com": {"hours": 5, "commits": 3}}
    agg_path = tmp_path / "git-hours-aggregated-test.json"
    agg_path.write_text(json.dumps(data))

    monkeypatch.chdir(tmp_path)
    build_site(agg_path)

    site = tmp_path / "site"
    assert (site / "index.html").exists()
    latest = site / "git-hours-latest.json"
    assert latest.exists()
    assert json.load(latest.open()) == data
    copied = site / "data" / agg_path.name
    assert copied.exists()


def _run_main(monkeypatch, tmp_path, repos):
    """Helper to run org_coding_hours.main with patched environment."""
    monkeypatch.setenv("REPOS", " ".join(repos))
    output_file = tmp_path / "out.txt"
    monkeypatch.setenv("GITHUB_OUTPUT", str(output_file))
    monkeypatch.chdir(tmp_path)

    import org_coding_hours as oc
    oc = importlib.reload(oc)
    monkeypatch.setattr(oc, "run_git_hours", lambda repo: {"total": {"hours": 1, "commits": 1}})

    class FixedDate(datetime.date):
        @classmethod
        def today(cls):
            return cls(2024, 1, 1)

    monkeypatch.setattr(oc.datetime, "date", FixedDate)

    oc.main()
    return output_file.read_text().strip()


def test_output_path_single_repo(tmp_path, monkeypatch):
    line = _run_main(monkeypatch, tmp_path, ["owner/repo"])
    expected = "reports/git-hours-owner_repo-2024-01-01.json"
    assert line == f"aggregated_report={expected}"


def test_output_path_multiple_repos(tmp_path, monkeypatch):
    line = _run_main(monkeypatch, tmp_path, ["foo/bar", "baz/qux"])
    expected = "reports/git-hours-aggregated-2024-01-01.json"
    assert line == f"aggregated_report={expected}"


def _run_main_subprocess(monkeypatch, tmp_path, repos):
    """Run org_coding_hours.main intercepting subprocess calls."""
    monkeypatch.setenv("REPOS", " ".join(repos))
    output_file = tmp_path / "out.txt"
    monkeypatch.setenv("GITHUB_OUTPUT", str(output_file))
    monkeypatch.chdir(tmp_path)

    import org_coding_hours as oc
    oc = importlib.reload(oc)

    clone_dir = {}

    def fake_run(cmd, check):
        assert cmd[0] == "git" and cmd[1] == "clone"
        clone_dir["path"] = cmd[-1]

    def fake_check_output(cmd, cwd, text):
        assert cmd[0] == "git-hours"
        assert cwd == clone_dir["path"]
        return json.dumps({"user@example.com": {"hours": 1, "commits": 1}, "total": {"hours": 1, "commits": 1}})

    monkeypatch.setattr(oc.subprocess, "run", fake_run)
    monkeypatch.setattr(oc.subprocess, "check_output", fake_check_output)

    class FixedDate(datetime.date):
        @classmethod
        def today(cls):
            return cls(2024, 1, 1)

    monkeypatch.setattr(oc.datetime, "date", FixedDate)

    oc.main()
    return output_file.read_text().strip()


def test_main_single_repo(monkeypatch, tmp_path):
    line = _run_main_subprocess(monkeypatch, tmp_path, ["owner/repo"])
    expected = "reports/git-hours-owner_repo-2024-01-01.json"
    assert line == f"aggregated_report={expected}"


def test_main_multiple_repos(monkeypatch, tmp_path):
    line = _run_main_subprocess(monkeypatch, tmp_path, ["foo/bar", "baz/qux"])
    expected = "reports/git-hours-aggregated-2024-01-01.json"
    assert line == f"aggregated_report={expected}"

