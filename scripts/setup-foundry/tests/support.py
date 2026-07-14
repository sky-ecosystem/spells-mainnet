"""Shared subprocess fixtures for Foundry setup tests."""

import os
import subprocess
import sys
import tempfile
import textwrap
import importlib.util
from importlib import import_module
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLI = ROOT / "scripts" / "setup-foundry" / "setup-foundry.py"
BINARIES = ("forge", "cast", "anvil", "chisel")


def load_module(name):
    return import_module(f"src.{name}")


def load_cli_module():
    spec = importlib.util.spec_from_file_location("setup_foundry_entrypoint", CLI)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FAKE_GH = r"""#!__PYTHON__
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
    if os.environ.get("TEST_DOWNLOAD_STATUS"):
        sys.exit(int(os.environ["TEST_DOWNLOAD_STATUS"]))
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
"""


FAKE_GIT = r"""#!/bin/sh
if [ "$1" = "-C" ] && [ "$3 $4" = "rev-parse --show-toplevel" ]; then
    printf '%s\n' "$FIXTURE/repository"
elif [ "$1" = "-C" ] && [ "$3 $4" = "rev-parse HEAD" ]; then
    printf '%s\n' '0123456789abcdef0123456789abcdef01234567'
else
    exit 64
fi
"""


class FoundryFixture:
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.fixture = Path(self.temporary.name)
        self.home = self.fixture / "home"
        self.fake_bin = self.fixture / "bin"
        self.path_bin = self.fixture / "foundry-bin"
        self.log = self.fixture / "log"
        self.destination = self.home / ".foundry" / "bin"
        for directory in (
            self.destination,
            self.fake_bin,
            self.path_bin,
            self.log,
            self.fixture / "repository",
        ):
            directory.mkdir(parents=True, exist_ok=True)
        self.write_executable(
            self.fake_bin / "gh", FAKE_GH.replace("__PYTHON__", sys.executable)
        )
        self.write_executable(self.fake_bin / "git", FAKE_GIT)
        for binary in BINARIES:
            self.write_binary(self.path_bin / binary, binary)
        self.env = os.environ.copy()
        self.env.update(
            {
                "FIXTURE": str(self.fixture),
                "HOME": str(self.home),
                "TEST_LOG": str(self.log),
            }
        )
        for name in (
            "TEST_ARCHIVE_VARIANT",
            "TEST_ASSET_TAG",
            "TEST_ATTEST_FAIL",
            "TEST_ATTEST_STATUS",
            "TEST_AUTH_STATUS",
            "TEST_INSTALLED_TAG",
            "TEST_INVALID_ARCHIVE",
            "TEST_MIXED_BINARY",
            "TEST_NO_ELIGIBLE",
            "TEST_SIGNER",
            "TEST_SOURCE",
            "TEST_VERSION_FAIL",
            "TEST_DOWNLOAD_STATUS",
        ):
            self.env.pop(name, None)

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def write_executable(path, content):
        path.write_text(textwrap.dedent(content))
        path.chmod(0o755)

    def write_binary(self, path, name):
        self.write_executable(
            path,
            f'''\
            #!{sys.executable}
            import os, sys
            from pathlib import Path
            with (Path(os.environ["TEST_LOG"]) / "versions").open("a") as handle:
                handle.write("{name}\\n")
            if os.environ.get("TEST_VERSION_FAIL") == "{name}":
                sys.exit(17)
            print("{name} Version: 2.0.0")
        ''',
        )

    def run_cli(self, command=None, path_mode="foundry"):
        return self.run_command(
            [sys.executable, str(CLI)], command=command, path_mode=path_mode
        )

    def run_command(self, argv, command=None, path_mode="foundry", cwd=None):
        env = self.env.copy()
        prefixes = {
            "foundry": [self.path_bin, self.fake_bin],
            "destination": [self.destination, self.fake_bin],
            "none": [self.fake_bin],
        }[path_mode]
        env["PATH"] = os.pathsep.join(str(path) for path in prefixes) + ":/usr/bin:/bin"
        if command is not None:
            argv.append(command)
        return subprocess.run(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            cwd=cwd,
            check=False,
        )

    def gh_log(self):
        path = self.log / "gh"
        return path.read_text() if path.exists() else ""

    def version_log(self):
        path = self.log / "versions"
        return path.read_text().splitlines() if path.exists() else []

    @staticmethod
    def load_cli_module():
        return load_cli_module()
