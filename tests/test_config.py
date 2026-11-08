import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from config import render, values  # noqa: E402
from validate import validate  # noqa: E402


def load_script(name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, ROOT / f"scripts/{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ProvisioningTests(unittest.TestCase):
    def test_real_inputs_and_missing_restore_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            render(directory, values(dummy=True))
            validate(directory)
            (directory / "scripts/restore.sh").unlink()
            with self.assertRaisesRegex(ValueError, "Missing provisioned source"):
                validate(directory)

    def test_unknown_bootstrap_service_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            render(directory, values(dummy=True))
            (directory / "config/services").write_text("n8n\n")
            with self.assertRaisesRegex(ValueError, "missing unit: n8n"):
                validate(directory)

    def test_media_container_without_mount_guard_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            render(directory, values(dummy=True))
            unit = directory / "services/container-lidarr.service"
            unit.write_text(unit.read_text().replace("BindsTo=var-mnt-music.mount\n", ""))
            with self.assertRaisesRegex(ValueError, "Missing NAS stop dependency"):
                validate(directory)

    def test_yaml_secret_escaping_and_single_document(self) -> None:
        import yaml

        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            tokens = values(dummy=True)
            tokens["CORE_SSH"] = 'ssh-key quote" and \\ slash'
            directory.chmod(0o755)
            render(directory, tokens)
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
            documents = list(yaml.safe_load_all((directory / "merged.yaml").read_text()))
            self.assertEqual(len(documents), 1)
            self.assertEqual(
                documents[0]["passwd"]["users"][0]["ssh_authorized_keys"], [tokens["CORE_SSH"]]
            )

    def test_container_without_cgroup_delegation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            render(directory, values(dummy=True))
            unit = directory / "services/container-lidarr.service"
            unit.write_text(unit.read_text().replace("Delegate=yes\n", ""))
            with self.assertRaisesRegex(ValueError, "Missing container cgroup delegation"):
                validate(directory)


class StorageTests(unittest.TestCase):
    def test_sab_preserves_credentials_and_nested_options(self) -> None:
        configure = load_script("configure-sab").configure
        original = (
            "__version__ = 19\n[misc]\napi_key = private\nport = 8080\n"
            'download_free = ""\n[servers]\n[[news]]\nport = 563\n'
        )
        updated = configure(original, "150G")
        self.assertIn("download_free = 150G\n", updated)
        self.assertIn("port = 8085\n", updated)
        self.assertIn("api_key = private\n", updated)
        self.assertIn("[[news]]\nport = 563\n", updated)
        self.assertEqual(configure(updated, "150G"), updated)
        with self.assertRaises(ValueError):
            configure(original, "0G")

    def test_backlog_grace_period_and_tracking(self) -> None:
        classify = load_script("storage-report").classify
        folders = [
            {"name": "new", "modified": 950, "bytes": 20},
            {"name": "stalled", "modified": 500, "bytes": 30},
            {"name": "orphan", "modified": 100, "bytes": 40},
            {"name": "empty", "modified": 100, "bytes": 0},
        ]
        result = classify(folders, {"stalled"}, 1000, 100)
        self.assertEqual(
            [(row["name"], row["reason"]) for row in result],
            [("stalled", "awaiting_import"), ("orphan", "untracked")],
        )


if __name__ == "__main__":
    unittest.main()
