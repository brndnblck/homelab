#!/usr/bin/env python3
"""Set managed SAB options while the container is stopped, preserving its INI."""

import os
import re
import subprocess
from pathlib import Path


def configure(text: str, reserve: str) -> str:
    if not re.fullmatch(r"[1-9][0-9]*G", reserve):
        raise ValueError("SAB_DOWNLOAD_FREE must be a positive whole number of GiB, e.g. 150G")
    lines = text.splitlines(keepends=True)
    start = lines.index("[misc]\n") + 1
    end = next((i for i in range(start, len(lines)) if lines[i].startswith("[")), len(lines))
    options = {"download_free": reserve, "port": "8085"}
    for name, value in options.items():
        positions = [i for i in range(start, end) if re.match(rf"^\s*{name}\s*=", lines[i])]
        if len(positions) > 1:
            raise ValueError(f"Duplicate SAB option: {name}")
        if positions:
            lines[positions[0]] = f"{name} = {value}\n"
        else:
            lines.insert(end, f"{name} = {value}\n")
            end += 1
    return "".join(lines)


def main() -> None:
    state = subprocess.run(
        [
            "podman",
            "inspect",
            "--format",
            "{{.State.Running}}",
            "container-sabnzbd.service",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if state.returncode == 0 and state.stdout.strip() == "true":
        raise RuntimeError("Stop SABnzbd before changing its configuration")
    path = Path("/var/services/sabnzbd/sabnzbd.ini")
    # SAB creates the rest of a fresh configuration on first start.
    original = path.read_text() if path.exists() else "[misc]\n"
    updated = configure(original, os.environ["SAB_DOWNLOAD_FREE"])
    if original == updated:
        return
    temporary = path.with_suffix(".ini.tmp")
    with temporary.open("w") as output:
        output.write(updated)
        output.flush()
        os.fsync(output.fileno())
    os.chmod(temporary, 0o600)
    os.chown(temporary, 911, 911)
    temporary.replace(path)


if __name__ == "__main__":
    main()
