"""Exercise the actual backup/restore shell scripts with real tar and SQLite files.

Only service management, mount discovery and SELinux labeling use controlled substitutes.
macOS also substitutes flock; Linux uses the real filesystem lock.
"""

import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SYSTEMCTL = """#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ["FIXTURE"])
args = sys.argv[1:]
with (root / "calls").open("a") as output:
    output.write(" ".join(args) + "\\n")
units = json.loads((root / "running").read_text())
if args[0] == "list-units":
    for unit in units:
        print(unit, "loaded active running test")
elif args[0] == "stop":
    units = [unit for unit in units if unit not in args[1:]]
elif args[0] == "start":
    units = sorted(set(units + args[1:]))
(root / "running").write_text(json.dumps(units))
"""


class StateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="homelab-state-test-")
        self.root = Path(self.temporary.name)
        self.services = self.root / "var/services"
        self.services.mkdir(parents=True)
        self.backups = self.root / "mnt/services/homelab-backups"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.scripts = self.root / "var/scripts"
        self.scripts.mkdir(parents=True)
        for source in (ROOT / "scripts").glob("*.sh"):
            text = source.read_text()
            text = text.replace("/usr/bin/sh", shutil.which("sh"))
            for prefix in ("/var/scripts", "/var/services", "/var/mnt", "/mnt/services", "/run"):
                text = text.replace(prefix, str(self.root) + prefix)
            (self.scripts / source.name).write_text(text)
        self.executable("systemctl", SYSTEMCTL)
        self.executable("podman", '#!/bin/sh\nprintf \'%s\\n\' "$*" >>"$FIXTURE/podman-calls"\n')
        self.executable("findmnt", "#!/bin/sh\nprintf 'cifs //nas.lan/services\\n'\n")
        self.executable("restorecon", "#!/bin/sh\nexit 0\n")
        if not shutil.which("flock"):
            self.executable("flock", "#!/bin/sh\nexit 0\n")
        self.tar = shutil.which("gtar") or shutil.which("tar")
        (self.bin / "tar").symlink_to(self.tar)
        if not shutil.which("sha256sum") and shutil.which("gsha256sum"):
            (self.bin / "sha256sum").symlink_to(shutil.which("gsha256sum"))
        (self.root / "run").mkdir()
        (self.root / "running").write_text(json.dumps(["container-lidarr.service"]))
        self.environment = {
            **os.environ,
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "FIXTURE": str(self.root),
            "BACKUP_KEEP": "1",
        }
        self.database = self.services / "lidarr.db"
        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.execute("CREATE TABLE albums (title TEXT)")
            connection.execute("INSERT INTO albums VALUES ('Gish')")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def executable(self, name: str, text: str) -> None:
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def run_script(
        self, name: str, *arguments: str, answer: str = ""
    ) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["sh", str(self.scripts / name), *arguments],
            env=self.environment,
            input=answer,
            text=True,
            capture_output=True,
        )

    def backup(self) -> Path:
        result = self.run_script("backup.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        return self.backups / (self.backups / "latest").read_text().strip()

    def test_snapshot_restore_and_retention(self) -> None:
        first = self.backup()
        second = self.backup()
        self.assertFalse(first.exists())
        self.assertTrue((second / "complete").is_file())
        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.execute("DELETE FROM albums")
        result = self.run_script("restore.sh", second.name, answer="yes\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        with closing(sqlite3.connect(self.database)) as connection:
            self.assertEqual(connection.execute("SELECT title FROM albums").fetchall(), [("Gish",)])
        self.assertEqual(
            json.loads((self.root / "running").read_text()), ["container-lidarr.service"]
        )
        self.assertTrue(list((self.root / "var").glob("services.before-*")))
        calls = (self.root / "calls").read_text()
        self.assertEqual(calls.count("stop container-lidarr.service"), 3)
        self.assertEqual(calls.count("start container-lidarr.service"), 3)
        self.assertEqual(
            (self.root / "podman-calls").read_text().splitlines(),
            ["stop --ignore --time 60 container-lidarr.service"] * 3,
        )

    def test_failed_archive_restarts_services_and_is_not_published(self) -> None:
        (self.bin / "tar").unlink()
        self.executable("tar", "#!/bin/sh\nexit 42\n")
        result = self.run_script("backup.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Creating consistent snapshot", result.stdout)
        self.assertIn("stop container-lidarr.service", (self.root / "calls").read_text())
        self.assertFalse((self.backups / "latest").exists())
        self.assertFalse(list(self.backups.glob("*/complete")))
        self.assertEqual(
            json.loads((self.root / "running").read_text()), ["container-lidarr.service"]
        )

    def test_corrupt_snapshot_rejected_before_stopping_services(self) -> None:
        snapshot = self.backup()
        (snapshot / "services.tar").write_bytes(b"corrupt archive")
        (self.root / "calls").write_text("")
        result = self.run_script("restore.sh", snapshot.name, answer="yes\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("stop ", (self.root / "calls").read_text())

    def test_container_shutdown_failure_does_not_publish_snapshot(self) -> None:
        self.executable("podman", "#!/bin/sh\nexit 42\n")
        result = self.run_script("backup.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Creating consistent snapshot", result.stdout)
        self.assertFalse((self.backups / "latest").exists())
        self.assertEqual(
            json.loads((self.root / "running").read_text()), ["container-lidarr.service"]
        )

    def test_wrong_mount_aborts_without_stopping_services(self) -> None:
        self.executable("findmnt", "#!/bin/sh\nprintf 'xfs /dev/sda4\\n'\n")
        result = self.run_script("backup.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected //nas.lan/services mounted as CIFS", result.stderr)
        self.assertFalse((self.root / "calls").exists())
        self.assertFalse(self.backups.exists())


if __name__ == "__main__":
    unittest.main()
