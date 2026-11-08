#!/usr/bin/env python3
"""Render real provisioning inputs without evaluating credentials as shell code."""

import re
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r"\{\{([A-Z_]+)\}\}")


def values(dummy: bool) -> dict[str, str]:
    result = {}
    for line in (ROOT / "default.env").read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        if dummy:
            value = "validation-only"
        elif value.startswith("op://"):
            value = subprocess.check_output(["op", "read", value], text=True).rstrip("\n")
        if key == "CORE_PASSWORD":
            value = subprocess.check_output(
                ["openssl", "passwd", "-6", "-stdin"], input=value + "\n", text=True
            ).strip()
        if dummy and key == "CORE_SSH":
            value = (
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            )
        result[key] = value
    return result


def render(destination: Path, tokens: dict[str, str]) -> None:
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination.chmod(0o700)
    for directory in ("scripts", "profile", "config"):
        shutil.copytree(ROOT / directory, destination / directory, dirs_exist_ok=True)
    templates = [
        *ROOT.glob("*.template"),
        *ROOT.glob("services/*.template"),
        *ROOT.glob("security/*.template"),
    ]
    for template in templates:
        relative = template.relative_to(ROOT).with_suffix("")
        output = destination / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        # YAML-quoted credentials need YAML escaping, not sed or shell escaping.
        text = template.read_text()
        if relative == Path("users.yaml"):
            for key in ("CORE_PASSWORD", "CORE_SSH"):
                text = text.replace(
                    '"{{' + key + '}}"', yaml.safe_dump(tokens[key], default_style='"').strip()
                )
        text = TOKEN.sub(lambda match: tokens[match[1]], text)
        output.write_text(text)
        output.chmod(0o600)
    merged = {}
    for name in ("users", "storage", "systemd"):
        document = yaml.safe_load((destination / f"{name}.yaml").read_text())
        if merged.keys() & document.keys():
            raise ValueError(f"Duplicate top-level provisioning keys in {name}")
        merged.update(document)
    (destination / "merged.yaml").write_text(yaml.safe_dump(merged, sort_keys=False))
    (destination / "merged.yaml").chmod(0o600)


if __name__ == "__main__":
    render(Path(sys.argv[1]), values("--dummy" in sys.argv[2:]))
