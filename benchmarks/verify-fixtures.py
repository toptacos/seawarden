#!/usr/bin/env python3
"""Validate benchmark fixture shape and internal consistency."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "fixtures"
REQUIRED = {
    "connect_seconds",
    "db_backup_seconds",
    "files_sync_seconds",
    "total_seconds",
    "db_gzip_bytes",
    "files_logical_bytes",
    "files_delta_bytes",
}


def main() -> int:
    files = sorted(ROOT.glob("*.json"))
    if not files:
        print("no fixtures", file=sys.stderr)
        return 1
    for path in files:
        data = json.loads(path.read_text())
        missing = REQUIRED - set(data)
        if missing:
            print(f"{path.name}: missing {missing}", file=sys.stderr)
            return 1
        parts = data["connect_seconds"] + data["db_backup_seconds"] + data["files_sync_seconds"]
        if data["total_seconds"] < parts:
            print(f"{path.name}: total_seconds < sum of phases", file=sys.stderr)
            return 1
        if data["files_delta_bytes"] >= data["files_logical_bytes"]:
            print(f"{path.name}: delta should be << logical for warm runs", file=sys.stderr)
            return 1
        print(f"ok {path.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
