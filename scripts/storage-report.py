#!/usr/bin/env python3
"""Read-only disk and completed-download checks. Never modify or remove media."""

import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


def request(url: str, headers: dict[str, str] | None = None) -> dict:
    with urllib.request.urlopen(
        urllib.request.Request(url, headers=headers or {}), timeout=30
    ) as response:
        return json.load(response)


def folder_bytes(folder: Path) -> int:
    return sum(
        entry.stat().st_size
        for entry in folder.rglob("*")
        if not entry.is_symlink() and entry.is_file()
    )


def classify(folders: list[dict], tracked: set[str], now: float, grace: float) -> list[dict]:
    return [
        {
            **folder,
            "reason": "awaiting_import" if folder["name"] in tracked else "untracked",
        }
        for folder in folders
        if now - folder["modified"] >= grace and folder["bytes"] > 0
    ]


def report() -> dict:
    result: dict = {"time": time.time(), "alerts": [], "folders": []}
    free = shutil.disk_usage("/var/downloads").free
    result["free_bytes"] = free
    if free < int(os.environ["DISK_ALERT_GIB"]) * 1024**3:
        result["alerts"].append(f"Local disk low: {free / 1024**3:.1f} GiB free")
    tracked: set[str] = set()
    try:
        key = ET.parse("/var/services/lidarr/config.xml").findtext("ApiKey")
        if not key:
            raise ValueError("Missing Lidarr API key")
        page = 1
        while True:
            queue = request(
                f"http://127.0.0.1:8082/api/v1/queue?page={page}&pageSize=200"
                "&includeUnknownArtistItems=true",
                {"X-Api-Key": key},
            )
            for record in queue["records"]:
                parts = Path(record.get("outputPath", "")).parts
                if parts[:4] == ("/", "downloads", "complete", "music") and len(parts) > 4:
                    tracked.add(parts[4])
            if page * 200 >= queue["totalRecords"]:
                break
            page += 1
    except (OSError, ValueError, KeyError, ET.ParseError):
        result["alerts"].append("Lidarr queue check failed; backlog status is unknown")
        return result
    folders = [
        {
            "name": folder.name,
            "bytes": folder_bytes(folder),
            "modified": folder.stat().st_mtime,
        }
        for folder in Path("/var/downloads/complete/music").iterdir()
        if folder.is_dir() and not folder.is_symlink()
    ]
    result["folders"] = classify(
        folders, tracked, result["time"], int(os.environ["BACKLOG_HOURS"]) * 3600
    )
    if result["folders"]:
        size = sum(folder["bytes"] for folder in result["folders"]) / 1024**3
        oldest = max((result["time"] - folder["modified"]) / 3600 for folder in result["folders"])
        result["alerts"].append(
            f"Music backlog: {len(result['folders'])} folders, {size:.1f} GiB, "
            f"oldest {oldest:.0f} hours"
        )
    ini = Path("/var/services/sabnzbd/sabnzbd.ini").read_text()
    key_match = re.search(r"^api_key\s*=\s*(.+)$", ini, re.MULTILINE)
    if not key_match:
        result["alerts"].append("SABnzbd API key unavailable")
        return result
    try:
        params = urllib.parse.urlencode(
            {
                "mode": "get_config",
                "section": "misc",
                "keyword": "download_free",
                "output": "json",
                "apikey": key_match[1].strip(),
            }
        )
        reserve = request(f"http://127.0.0.1:8085/api?{params}")["config"]["misc"]["download_free"]
        if str(reserve) != os.environ["SAB_DOWNLOAD_FREE"]:
            result["alerts"].append("SABnzbd free-space reserve differs from managed configuration")
    except (OSError, ValueError, KeyError):
        # Do not log HTTP exceptions, which can contain the credential-bearing URL.
        result["alerts"].append("SABnzbd reserve check failed")
    return result


def main() -> None:
    result = report()
    path = Path("/var/lib/homelab/storage-report.json")
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n")
    temporary.replace(path)
    for alert in result["alerts"]:
        print(alert, file=sys.stderr)
    webhook = os.environ.get("ALERT_WEBHOOK", "")
    if result["alerts"] and webhook:
        if not webhook.startswith("https://"):
            raise ValueError("ALERT_WEBHOOK must use HTTPS")
        payload = json.dumps({"text": "Homelab: " + "; ".join(result["alerts"])}).encode()
        try:
            with urllib.request.urlopen(
                urllib.request.Request(
                    webhook,
                    data=payload,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                ),
                timeout=15,
            ):
                pass
        except (OSError, ValueError):
            print("Alert webhook delivery failed", file=sys.stderr)
    sys.exit(bool(result["alerts"]))


if __name__ == "__main__":
    main()
