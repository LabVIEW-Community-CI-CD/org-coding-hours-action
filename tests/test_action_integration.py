import json
import os
import subprocess


def test_git_hours_action(tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", str(repo)], check=True)
    env = os.environ.copy()
    env.update({
        "GIT_AUTHOR_NAME": "Test",
        "GIT_AUTHOR_EMAIL": "test@example.com",
        "GIT_COMMITTER_NAME": "Test",
        "GIT_COMMITTER_EMAIL": "test@example.com",
    })
    (repo / "file.txt").write_text("hello")
    subprocess.run(["git", "-C", str(repo), "add", "file.txt"], check=True, env=env)
    subprocess.run(["git", "-C", str(repo), "commit", "-m", "init"], check=True, env=env)

    dummy = tmp_path / "git-hours"
    dummy.write_text(
        "#!/bin/sh\n"
        "while [ $# -gt 0 ]; do\n"
        "  case \"$1\" in\n"
        "    -output) shift; out=$1;;\n"
        "  esac\n"
        "  shift\n"
        "done\n"
        "echo '{\"total\":{\"hours\":1,\"commits\":1}}' > \"$out\"\n"
    )
    dummy.chmod(0o755)

    env_run = os.environ.copy()
    env_run["PATH"] = f"{tmp_path}:{env_run['PATH']}"
    subprocess.run(
        ["git-hours", "-format", "json", "-output", "git-hours.json", str(repo)],
        cwd=tmp_path,
        env=env_run,
        check=True,
    )
    report = tmp_path / "git-hours.json"
    assert report.exists()
    data = json.loads(report.read_text())
    assert data["total"] == {"hours": 1, "commits": 1}
