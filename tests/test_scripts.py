import json
import os
import pathlib
import sys
os.environ.setdefault("REPOS", "dummy/repo")

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from org_coding_hours import aggregate
from build_site import build_site


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

