#!/usr/bin/env python3
"""Check cross-file provisioning references using real rendered inputs."""

import configparser
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

from config import render, values


def validate(directory: Path) -> None:
    document = yaml.safe_load((directory / "merged.yaml").read_text())
    files = {entry["path"]: entry for entry in document["storage"]["files"]}
    units = {entry["name"] for entry in document["systemd"]["units"]}
    for entry in files.values():
        local = entry.get("contents", {}).get("local")
        if local and not (directory / local).is_file():
            raise ValueError(f"Missing provisioned source: {local}")
    for unit in units:
        path = f"/etc/systemd/system/{unit}"
        if path not in files or files[path]["contents"].get("local") != f"services/{unit}":
            raise ValueError(f"Unit is not provisioned: {unit}")
    for name in (directory / "config/services").read_text().splitlines():
        if name and f"container-{name}.service" not in units:
            raise ValueError(f"Initialization references missing unit: {name}")
    for path in (directory / "services").iterdir():
        if f"/etc/systemd/system/{path.name}" not in files:
            raise ValueError(f"Template is not provisioned: {path.name}")
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        parser.read(path)
        section = {".service": "Service", ".timer": "Timer", ".mount": "Mount"}[path.suffix]
        if not parser.has_section("Unit") or not parser.has_section(section):
            raise ValueError(f"Missing required sections: {path.name}")
        if path.suffix == ".timer":
            service = parser.get("Timer", "Unit", fallback=path.with_suffix(".service").name)
            if not (directory / "services" / service).is_file():
                raise ValueError(f"Timer references missing service: {path.name}")
        if path.name.startswith("container-"):
            if parser.get("Service", "Delegate", fallback="") != "yes":
                raise ValueError(f"Missing container cgroup delegation: {path.name}")
            text = path.read_text()
            for share in re.findall(r"-v /mnt/([a-z]+):", text):
                if (
                    f"/var/mnt/{share}"
                    not in parser.get("Unit", "RequiresMountsFor", fallback="").split()
                ):
                    raise ValueError(f"Missing NAS mount dependency: {path.name}: {share}")
                if (
                    f"var-mnt-{share}.mount"
                    not in parser.get("Unit", "BindsTo", fallback="").split()
                ):
                    raise ValueError(f"Missing NAS stop dependency: {path.name}: {share}")
                guard = parser.get("Service", "ExecStartPre", fallback="")
                if "check-shares.sh" not in guard or share not in guard.split():
                    raise ValueError(f"Missing NAS startup guard: {path.name}: {share}")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="homelab-validate-") as temporary:
        directory = Path(temporary)
        render(directory, values(dummy=True))
        validate(directory)
        if "--butane" in sys.argv:
            if not shutil.which("butane"):
                raise RuntimeError("butane is required; install it before running this check")
            subprocess.run(
                [
                    "butane",
                    "--strict",
                    "--files-dir",
                    str(directory),
                    str(directory / "merged.yaml"),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
            )
        if "--systemd" in sys.argv:
            if not shutil.which("systemd-analyze"):
                raise RuntimeError(
                    "Native systemd verification requires a Linux host with systemd-analyze"
                )
            subprocess.run(
                [
                    "systemd-analyze",
                    "verify",
                    "--man=no",
                    *map(str, (directory / "services").iterdir()),
                ],
                check=True,
            )
    print("Provisioning validation passed")


if __name__ == "__main__":
    main()
