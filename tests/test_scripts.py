import json
import os
import pathlib
import sys

import pytest

os.environ.setdefault("REPOS", "dummy/repo")

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from org_coding_hours import aggregate, slugify

import importlib
import datetime
import runpy
import subprocess


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
    lines = output_file.read_text().splitlines()
    return dict(line.split('=', 1) for line in lines)


def test_output_path_single_repo(tmp_path, monkeypatch):
    out = _run_main(monkeypatch, tmp_path, ["owner/repo"])
    expected = "reports/git-hours-owner_repo-2024-01-01.json"
    assert out["aggregated_report"] == expected
    assert out["repo_slug"] == "owner_repo"


def test_output_path_multiple_repos(tmp_path, monkeypatch):
    out = _run_main(monkeypatch, tmp_path, ["foo/bar", "baz/qux"])
    expected = "reports/git-hours-aggregated-2024-01-01.json"
    assert out["aggregated_report"] == expected
    assert out["repo_slug"] == "foo_bar-baz_qux"


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
    lines = output_file.read_text().splitlines()
    return dict(line.split('=', 1) for line in lines)


def test_main_single_repo(monkeypatch, tmp_path):
    out = _run_main_subprocess(monkeypatch, tmp_path, ["owner/repo"])
    expected = "reports/git-hours-owner_repo-2024-01-01.json"
    assert out["aggregated_report"] == expected
    assert out["repo_slug"] == "owner_repo"


def test_main_multiple_repos(monkeypatch, tmp_path):
    out = _run_main_subprocess(monkeypatch, tmp_path, ["foo/bar", "baz/qux"])
    expected = "reports/git-hours-aggregated-2024-01-01.json"
    assert out["aggregated_report"] == expected
    assert out["repo_slug"] == "foo_bar-baz_qux"


def test_clone_uses_token(monkeypatch, tmp_path):
    monkeypatch.setenv("REPOS", "owner/private")
    monkeypatch.setenv("GITHUB_TOKEN", "secret")
    output_file = tmp_path / "out.txt"
    monkeypatch.setenv("GITHUB_OUTPUT", str(output_file))
    monkeypatch.chdir(tmp_path)

    import org_coding_hours as oc
    oc = importlib.reload(oc)

    seen = {}

    def fake_run(cmd, check):
        seen["url"] = cmd[2]

    def fake_check_output(cmd, cwd, text):
        return json.dumps({"total": {"hours": 1, "commits": 1}})

    monkeypatch.setattr(oc.subprocess, "run", fake_run)
    monkeypatch.setattr(oc.subprocess, "check_output", fake_check_output)

    class FixedDate(datetime.date):
        @classmethod
        def today(cls):
            return cls(2024, 1, 1)

    monkeypatch.setattr(oc.datetime, "date", FixedDate)

    oc.main()
    assert "x-access-token" in seen["url"]


def test_run_git_hours_defaults(monkeypatch):
    monkeypatch.setenv("REPOS", "owner/repo")
    monkeypatch.delenv("WINDOW_START", raising=False)

    import org_coding_hours as oc
    oc = importlib.reload(oc)

    monkeypatch.setattr(oc.subprocess, "run", lambda *a, **k: None)
    seen = {}

    def fake_check_output(cmd, cwd, text):
        seen["cmd"] = cmd
        return json.dumps({"total": {"hours": 1, "commits": 1}})

    monkeypatch.setattr(oc.subprocess, "check_output", fake_check_output)

    oc.run_git_hours("owner/repo")
    assert seen["cmd"] == ["git-hours"]


def test_run_git_hours_respects_window_start(monkeypatch):
    monkeypatch.setenv("REPOS", "owner/repo")
    monkeypatch.setenv("WINDOW_START", "2023-01-01")

    import org_coding_hours as oc
    oc = importlib.reload(oc)

    monkeypatch.setattr(oc.subprocess, "run", lambda *a, **k: None)
    seen = {}

    def fake_check_output(cmd, cwd, text):
        seen["cmd"] = cmd
        return json.dumps({"total": {"hours": 1, "commits": 1}})

    monkeypatch.setattr(oc.subprocess, "check_output", fake_check_output)

    oc.run_git_hours("owner/repo")
    assert seen["cmd"] == ["git-hours", "-since", "2023-01-01"]


@pytest.mark.parametrize(
    "text,expected",
    [
        ("foo/bar baz", "foo_bar_baz"),
        ("hello world", "hello_world"),
        ("foo/bar", "foo_bar"),
        ("foo@bar#baz", "foo_bar_baz"),
        ("foo@bar/baz qux", "foo_bar_baz_qux"),
    ],
)
def test_slugify_edge_cases(text, expected):
    assert slugify(text) == expected


def test_missing_repos_env(monkeypatch):
    monkeypatch.delenv("REPOS", raising=False)
    sys.modules.pop("org_coding_hours", None)
    with pytest.raises(SystemExit) as exc:
        import org_coding_hours  # noqa: F401
    assert str(exc.value) == "REPOS env var must list repositories to process"


def test_script_entrypoint(monkeypatch, tmp_path):
    monkeypatch.setenv("REPOS", "owner/repo")
    output_file = tmp_path / "out.txt"
    monkeypatch.setenv("GITHUB_OUTPUT", str(output_file))
    monkeypatch.chdir(tmp_path)

    def fake_run(cmd, check):
        assert cmd[0] == "git" and cmd[1] == "clone"

    def fake_check_output(cmd, cwd, text):
        assert cmd[0] == "git-hours"
        return json.dumps({"total": {"hours": 1, "commits": 1}})

    monkeypatch.setattr(subprocess, "run", fake_run)
    monkeypatch.setattr(subprocess, "check_output", fake_check_output)

    class FixedDate(datetime.date):
        @classmethod
        def today(cls):
            return cls(2024, 1, 1)

    monkeypatch.setattr(datetime, "date", FixedDate)

    runpy.run_path(
        str(pathlib.Path(__file__).resolve().parents[1] / "scripts" / "org_coding_hours.py"),
        run_name="__main__",
    )

    lines = output_file.read_text().splitlines()
    out = dict(line.split("=", 1) for line in lines)
    assert out["aggregated_report"] == "reports/git-hours-owner_repo-2024-01-01.json"
    assert out["repo_slug"] == "owner_repo"

