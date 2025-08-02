from __future__ import annotations

import json
import pathlib
from typing import Union


def build_site(aggregated_path: Union[str, pathlib.Path]) -> None:
    """Generate basic static site artifacts for aggregated report.

    Parameters
    ----------
    aggregated_path:
        Path to the aggregated JSON report produced by the action.
    """
    aggregated_path = pathlib.Path(aggregated_path)
    data = json.loads(aggregated_path.read_text())

    site = pathlib.Path("site")
    (site / "data").mkdir(parents=True, exist_ok=True)

    # Write placeholder index.html
    (site / "index.html").write_text("<html><body>git-hours</body></html>")

    # Write latest JSON
    (site / "git-hours-latest.json").write_text(json.dumps(data))

    # Copy original aggregated file into data directory
    (site / "data" / aggregated_path.name).write_text(json.dumps(data))

