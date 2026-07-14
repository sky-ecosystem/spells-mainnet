#!/usr/bin/env python3

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / "scripts" / "setup-foundry" / "setup-foundry.py"
BINARIES = ("forge", "cast", "anvil", "chisel")


FAKE_GH = r'''#!__PYTHON__
import io
import json
import os
import sys
import tarfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

args = sys.argv[1:]
log = Path(os.environ["TEST_LOG"])
now = datetime.now(timezone.utc)
published = {
    "recent_one": (now - timedelta(days=1)).isoformat().replace("+00:00", "Z"),
    "recent_two": (now - timedelta(days=2)).isoformat().replace("+00:00", "Z"),
    "selected": (now - timedelta(days=30)).isoformat().replace("+00:00", "Z"),
    "older": (now - timedelta(days=60)).isoformat().replace("+00:00", "Z"),
    "prerelease": (now - timedelta(days=90)).isoformat().replace("+00:00", "Z"),
}
with (log / "gh").open("a") as handle:
    handle.write(" ".join(args) + "\n")

if args[:2] == ["auth", "status"]:
    sys.exit(int(os.environ.get("TEST_AUTH_STATUS", "0")))

if args and args[0] == "api":
    endpoint = next((arg for arg in args[1:] if arg.startswith("repos/")), "")
    if endpoint == "repos/foundry-rs/foundry/releases?per_page=100":
        if os.environ.get("TEST_NO_ELIGIBLE") == "1":
            releases = [
                {"tag_name": "v2.2.0", "published_at": published["recent_one"], "html_url": "https://example.test/v2.2.0", "draft": False, "prerelease": False},
            ]
        else:
            releases = [
                {"tag_name": "v2.2.0", "published_at": published["recent_one"], "html_url": "https://example.test/v2.2.0", "draft": False, "prerelease": False},
                {"tag_name": "v1.9.0", "published_at": published["older"], "html_url": "https://example.test/v1.9.0", "draft": False, "prerelease": False},
                {"tag_name": "v2.1.0", "published_at": published["recent_two"], "html_url": "https://example.test/v2.1.0", "draft": False, "prerelease": False},
                {"tag_name": "v2.0.0", "published_at": published["selected"], "html_url": "https://example.test/v2.0.0", "draft": False, "prerelease": False},
                {"tag_name": "v3.0.0-rc1", "published_at": published["prerelease"], "html_url": "https://example.test/v3.0.0-rc1", "draft": False, "prerelease": True},
                {"tag_name": "v9.0.0", "published_at": published["selected"], "html_url": "https://example.test/v9.0.0", "draft": True, "prerelease": False},
            ]
        print(json.dumps([releases]))
        sys.exit(0)
    prefix = "repos/foundry-rs/foundry/releases/tags/"
    if endpoint.startswith(prefix):
        tag = endpoint[len(prefix):]
        metadata = {
            "v2.2.0": (published["recent_one"], False, False),
            "v2.1.0": (published["recent_two"], False, False),
            "v2.0.0": (published["selected"], False, False),
            "v1.9.0": (published["older"], False, False),
            "v1.8.0-rc1": (published["prerelease"], False, True),
        }
        if tag not in metadata:
            sys.exit(1)
        published, draft, prerelease = metadata[tag]
        print(json.dumps({"tag_name": tag, "published_at": published, "draft": draft, "prerelease": prerelease}))
        sys.exit(0)

if args[:2] == ["release", "download"]:
    tag = args[2]
    asset = args[args.index("--pattern") + 1]
    directory = Path(args[args.index("--dir") + 1])
    (log / "download-version").write_text(tag + "\n")
    archive = directory / asset
    if os.environ.get("TEST_INVALID_ARCHIVE") == "1":
        archive.write_bytes(b"not a tar archive")
        sys.exit(0)
    variant = os.environ.get("TEST_ARCHIVE_VARIANT", "valid")
    with tarfile.open(archive, "w:gz") as output:
        names = list(("forge", "cast", "anvil", "chisel"))
        if variant == "missing":
            names.remove("chisel")
        for name in names:
            payload = ("#!" + sys.executable + "\n"
                       "import os, sys\n"
                       "from pathlib import Path\n"
                       "with (Path(os.environ['TEST_LOG']) / 'versions').open('a') as f: f.write('" + name + "\\n')\n"
                       "sys.exit(17) if os.environ.get('TEST_VERSION_FAIL') == '" + name + "' else None\n"
                       "print('" + name + " Version: 2.0.0')\n").encode()
            info = tarfile.TarInfo(name)
            info.mode = 0o755
            info.size = len(payload)
            output.addfile(info, io.BytesIO(payload))
        if variant == "traversal":
            payload = b"escape"
            info = tarfile.TarInfo("../escape")
            info.size = len(payload)
            output.addfile(info, io.BytesIO(payload))
        elif variant == "nonregular":
            info = tarfile.TarInfo("extra-link")
            info.type = tarfile.SYMTYPE
            info.linkname = "forge"
            output.addfile(info)
        elif variant == "unexpected":
            payload = b"readme"
            info = tarfile.TarInfo("README.md")
            info.size = len(payload)
            output.addfile(info, io.BytesIO(payload))
    sys.exit(0)

if args[:2] == ["attestation", "verify"]:
    subject = Path(args[2])
    name = subject.name
    if os.environ.get("TEST_ATTEST_FAIL") == name:
        sys.exit(int(os.environ.get("TEST_ATTEST_STATUS", "1")))
    if name.startswith("foundry_v") and name.endswith(".tar.gz"):
        tag = name[len("foundry_"):].split("_", 1)[0]
        tag = os.environ.get("TEST_ASSET_TAG", tag)
    else:
        tag = os.environ.get("TEST_INSTALLED_TAG", "v2.0.0")
        if os.environ.get("TEST_MIXED_BINARY") == name:
            tag = "v1.9.0"
    signer = os.environ.get(
        "TEST_SIGNER",
        "https://github.com/foundry-rs/foundry/.github/workflows/release.yml@refs/tags/" + tag,
    )
    source = os.environ.get("TEST_SOURCE", "https://github.com/foundry-rs/foundry")
    print(json.dumps([{"verificationResult": {"statement": {"subject": [{"name": name}]}, "signature": {"certificate": {"buildSignerURI": signer, "sourceRepositoryURI": source}}}}]))
    sys.exit(0)

sys.exit(64)
'''


FAKE_GIT = r'''#!/bin/sh
if [ "$1" = "-C" ] && [ "$3 $4" = "rev-parse --show-toplevel" ]; then
    printf '%s\n' "$FIXTURE/repository"
elif [ "$1" = "-C" ] && [ "$3 $4" = "rev-parse HEAD" ]; then
    printf '%s\n' '0123456789abcdef0123456789abcdef01234567'
else
    exit 64
fi
'''


class SetupFoundryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.fixture = Path(self.temporary.name)
        self.home = self.fixture / "home"
        self.fake_bin = self.fixture / "bin"
        self.path_bin = self.fixture / "foundry-bin"
        self.log = self.fixture / "log"
        self.destination = self.home / ".foundry" / "bin"
        for directory in (self.destination, self.fake_bin, self.path_bin, self.log, self.fixture / "repository"):
            directory.mkdir(parents=True, exist_ok=True)
        self.write_executable(self.fake_bin / "gh", FAKE_GH.replace("__PYTHON__", sys.executable))
        self.write_executable(self.fake_bin / "git", FAKE_GIT)
        for binary in BINARIES:
            self.write_binary(self.path_bin / binary, binary)
        self.env = os.environ.copy()
        self.env.update({
            "FIXTURE": str(self.fixture),
            "HOME": str(self.home),
            "TEST_LOG": str(self.log),
        })
        for name in (
            "TEST_ARCHIVE_VARIANT", "TEST_ASSET_TAG", "TEST_ATTEST_FAIL", "TEST_ATTEST_STATUS",
            "TEST_AUTH_STATUS", "TEST_INSTALLED_TAG", "TEST_INVALID_ARCHIVE", "TEST_MIXED_BINARY",
            "TEST_NO_ELIGIBLE", "TEST_SIGNER", "TEST_SOURCE", "TEST_VERSION_FAIL",
        ):
            self.env.pop(name, None)

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def write_executable(path, content):
        path.write_text(textwrap.dedent(content))
        path.chmod(0o755)

    def write_binary(self, path, name):
        self.write_executable(path, f'''\
            #!{sys.executable}
            import os, sys
            from pathlib import Path
            with (Path(os.environ["TEST_LOG"]) / "versions").open("a") as handle:
                handle.write("{name}\\n")
            if os.environ.get("TEST_VERSION_FAIL") == "{name}":
                sys.exit(17)
            print("{name} Version: 2.0.0")
        ''')

    def run_cli(self, command=None, path_mode="foundry"):
        env = self.env.copy()
        prefixes = {
            "foundry": [self.path_bin, self.fake_bin],
            "destination": [self.destination, self.fake_bin],
            "none": [self.fake_bin],
        }[path_mode]
        env["PATH"] = os.pathsep.join(str(path) for path in prefixes) + ":/usr/bin:/bin"
        argv = [sys.executable, str(CLI)]
        if command is not None:
            argv.append(command)
        return subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, check=False)

    def gh_log(self):
        path = self.log / "gh"
        return path.read_text() if path.exists() else ""

    def version_log(self):
        path = self.log / "versions"
        return path.read_text().splitlines() if path.exists() else []

    def test_verify_newest_eligible_toolchain(self):
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.gh_log().count("attestation verify "), 4)
        self.assertEqual(self.version_log(), list(BINARIES))
        self.assertIn("Eligible Foundry release: v2.0.0", result.stdout)
        self.assertIn("Setup CLI SHA-256:", result.stdout)
        self.assertIn("Foundry verification completed successfully", result.stdout)

    def test_verify_rejects_older_release_before_execution(self):
        self.env["TEST_INSTALLED_TAG"] = "v1.9.0"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])
        self.assertIn("does not match newest eligible stable v2.0.0", result.stdout)

    def test_verify_rejects_too_new_release_before_execution(self):
        self.env["TEST_INSTALLED_TAG"] = "v2.1.0"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])
        self.assertIn("seven-day policy", result.stdout)

    def test_verify_rejects_prerelease_before_execution(self):
        self.env["TEST_INSTALLED_TAG"] = "v1.8.0-rc1"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])
        self.assertIn("is not stable", result.stdout)

    def test_verify_reports_version_failure(self):
        self.env["TEST_VERSION_FAIL"] = "cast"
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 1)
        self.assertIn("could not read version from", result.stdout)

    def test_verify_rejects_missing_mixed_and_unattested_toolchains(self):
        (self.path_bin / "chisel").unlink()
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])

        self.write_binary(self.path_bin / "chisel", "chisel")
        self.env["TEST_MIXED_BINARY"] = "cast"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])

        self.env.pop("TEST_MIXED_BINARY")
        self.env["TEST_ATTEST_FAIL"] = "cast"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])

    def test_failure_never_uses_path_warning_exit_code(self):
        self.env.update({"TEST_ATTEST_FAIL": "cast", "TEST_ATTEST_STATUS": "2"})
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(result.returncode, 2)
        self.assertEqual(self.version_log(), [])

    def test_verify_rejects_wrong_attestation_signer_and_source(self):
        self.env["TEST_SIGNER"] = "https://github.com/attacker/project/.github/workflows/release.yml@refs/tags/v2.0.0"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected attestation signer", result.stdout)
        self.assertEqual(self.version_log(), [])

        self.env.pop("TEST_SIGNER")
        self.env["TEST_SOURCE"] = "https://github.com/attacker/project"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected attestation source", result.stdout)
        self.assertEqual(self.version_log(), [])

    def test_prerequisites_require_gh_git_and_authentication(self):
        minimal_bin = self.fixture / "minimal-bin"
        minimal_bin.mkdir()
        (minimal_bin / "git").symlink_to(self.fake_bin / "git")
        env = self.env.copy()
        env["PATH"] = str(minimal_bin)
        result = subprocess.run(
            [sys.executable, str(CLI), "verify"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, check=False,
        )
        self.assertIn("required command not found: gh", result.stdout)

        (minimal_bin / "git").unlink()
        (minimal_bin / "gh").symlink_to(self.fake_bin / "gh")
        result = subprocess.run(
            [sys.executable, str(CLI), "verify"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, check=False,
        )
        self.assertIn("required command not found: git", result.stdout)

        self.env["TEST_AUTH_STATUS"] = "1"
        result = self.run_cli("verify")
        self.assertIn("GitHub CLI is not authenticated for github.com", result.stdout)

    def test_install_filters_multiple_recent_releases_before_selecting_newest_eligible(self):
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual((self.log / "download-version").read_text().strip(), "v2.0.0")
        self.assertTrue(all((self.destination / name).stat().st_mode & 0o777 == 0o755 for name in BINARIES))

    def test_install_without_eligible_release_fails_before_download(self):
        self.env["TEST_NO_ELIGIBLE"] = "1"
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.log / "download-version").exists())
        self.assertIn("no stable Foundry release published at least seven days ago was found", result.stdout)

    def test_install_asset_attestation_failure_blocks_archive_read_and_mutation(self):
        asset = "foundry_v2.0.0_linux_amd64.tar.gz"
        self.env.update({"TEST_ATTEST_FAIL": asset, "TEST_INVALID_ARCHIVE": "1"})
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.destination.is_dir())
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_install_rejects_asset_attestation_tag_mismatch_before_archive_read(self):
        self.env.update({"TEST_ASSET_TAG": "v1.9.0", "TEST_INVALID_ARCHIVE": "1"})
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release asset attestation tag v1.9.0 does not match v2.0.0", result.stdout)
        self.assertNotIn("tar archive", result.stdout)

    def test_install_rejects_unsafe_nonregular_unexpected_and_incomplete_archives(self):
        for variant in ("traversal", "nonregular", "unexpected", "missing"):
            with self.subTest(variant=variant):
                self.env["TEST_ARCHIVE_VARIANT"] = variant
                result = self.run_cli("install", "none")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("archive must contain only regular files named forge, cast, anvil, and chisel", result.stdout)
                self.assertEqual(list(self.destination.iterdir()), [])

    def test_install_outside_path_exits_two_after_verified_success(self):
        result = self.run_cli("install", "none")
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertTrue((self.destination / "forge").is_file())
        self.assertIn("export PATH=", result.stdout)
        self.assertEqual(self.version_log(), list(BINARIES))

    def test_post_mutation_failure_restores_partial_prior_installation(self):
        (self.destination / "forge").write_text("old forge\n")
        (self.destination / "cast").write_text("old cast\n")
        (self.destination / "forge").chmod(0o700)
        (self.destination / "cast").chmod(0o600)
        self.env.update({"TEST_ATTEST_FAIL": "cast", "TEST_ATTEST_STATUS": "42"})
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 42, result.stdout)
        self.assertEqual((self.destination / "forge").read_text(), "old forge\n")
        self.assertEqual(stat.S_IMODE((self.destination / "forge").stat().st_mode), 0o700)
        self.assertEqual((self.destination / "cast").read_text(), "old cast\n")
        self.assertEqual(stat.S_IMODE((self.destination / "cast").stat().st_mode), 0o600)
        self.assertFalse((self.destination / "anvil").exists())
        self.assertFalse((self.destination / "chisel").exists())
        self.assertIn("Previous Foundry installation restored", result.stdout)

    def test_install_preserves_unmanaged_destination_files(self):
        unmanaged = self.destination / ".forge.setup-foundry"
        unmanaged.write_text("keep me\n")
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(unmanaged.read_text(), "keep me\n")

    def test_post_mutation_failure_restores_existing_symlink(self):
        target = self.fixture / "old-forge"
        target.write_text("old forge target\n")
        forge = self.destination / "forge"
        forge.symlink_to(target)
        self.env["TEST_ATTEST_FAIL"] = "cast"
        result = self.run_cli("install", "destination")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(forge.is_symlink())
        self.assertEqual(os.readlink(forge), str(target))

    def test_failure_removes_destination_created_by_install(self):
        shutil.rmtree(self.home / ".foundry")
        self.env["TEST_ATTEST_FAIL"] = "cast"
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.destination.exists())

    def test_install_reuses_destination_symlink_to_directory(self):
        real_destination = self.fixture / "real-bin"
        real_destination.mkdir()
        shutil.rmtree(self.destination)
        self.destination.symlink_to(real_destination, target_is_directory=True)
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(self.destination.is_symlink())
        self.assertTrue((real_destination / "forge").is_file())

    def test_install_rejects_invalid_or_broken_destination(self):
        shutil.rmtree(self.destination)
        self.destination.write_text("not a directory")
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("installation destination is not a directory", result.stdout)

        self.destination.unlink()
        self.destination.symlink_to(self.fixture / "missing")
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("installation destination is not a directory", result.stdout)

    def test_invalid_and_missing_commands_fail_with_usage(self):
        for command in ("invalid", None):
            with self.subTest(command=command):
                result = self.run_cli(command)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Usage:", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
