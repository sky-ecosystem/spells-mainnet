"""Safely install an attested Foundry release asset.

The asset is attested before its archive is read. Installation is transactional:
all four installed binaries are attested before execution, failures restore the
previous entries, and incomplete rollback preserves recovery data for manual
restoration.
"""

import os
import platform
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

from .config import BINARIES, QUALIFIED_REPOSITORY
from .releases import attest_path
from .runtime import SetupError, run
from .toolchain import run_binary_versions, verify_binary_paths


def validate_install_platform():
    systems = {"Linux": "linux", "Darwin": "darwin"}
    architectures = {
        "x86_64": "amd64",
        "amd64": "amd64",
        "arm64": "arm64",
        "aarch64": "arm64",
    }
    system, machine = platform.system(), platform.machine()
    if system not in systems:
        raise SetupError(f"unsupported operating system: {system}")
    if machine not in architectures:
        raise SetupError(f"unsupported architecture: {machine}")
    return systems[system], architectures[machine]


def foundry_destination():
    return Path.home() / ".foundry" / "bin"


def foundry_release_asset(selection):
    system, architecture = validate_install_platform()
    return f"foundry_{selection['version']}_{system}_{architecture}.tar.gz"


def download_and_verify_release_asset(selection, asset, temporary_directory):
    archive = temporary_directory / asset
    run(
        [
            "gh",
            "release",
            "download",
            selection["version"],
            "--repo",
            QUALIFIED_REPOSITORY,
            "--pattern",
            asset,
            "--dir",
            str(temporary_directory),
        ],
        f"could not download Foundry release asset {asset}",
    )
    print("\nRelease asset attestation:")
    asset_tag = attest_path(archive)
    if asset_tag != selection["version"]:
        raise SetupError(
            f"release asset attestation tag {asset_tag} does not match {selection['version']}"
        )
    return archive


def extract_release_archive(archive, extracted_directory):
    expected = sorted(BINARIES)
    try:
        with tarfile.open(archive, "r:gz") as source:
            members = source.getmembers()
            if sorted(member.name for member in members) != expected or any(
                not member.isfile() for member in members
            ):
                raise SetupError(
                    "archive must contain only regular files named forge, cast, anvil, and chisel"
                )
            extracted_directory.mkdir()
            for member in members:
                input_file = source.extractfile(member)
                if input_file is None:
                    raise SetupError(f"could not read archive member: {member.name}")
                output_path = extracted_directory / member.name
                with input_file, output_path.open("xb") as output_file:
                    shutil.copyfileobj(input_file, output_file)
                output_path.chmod(0o755)
    except SetupError:
        raise
    except (OSError, tarfile.TarError) as error:
        raise SetupError(f"could not read Foundry release archive: {error}") from error


def path_exists(path):
    return os.path.lexists(path)


def copy_entry(source, destination):
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    else:
        shutil.copy2(source, destination, follow_symlinks=False)


class Installation:
    def __init__(self, destination, backup_directory):
        self.destination = destination
        self.backup_directory = backup_directory
        self.destination_created = False
        self.rollback_required = False

    def prepare(self):
        if path_exists(self.destination):
            if not self.destination.is_dir():
                raise SetupError(
                    f"installation destination is not a directory: {self.destination}"
                )
        else:
            self.destination_created = True
        self.backup_directory.mkdir(mode=0o700)
        for binary in BINARIES:
            current = self.destination / binary
            if not path_exists(current):
                continue
            if not current.is_file() and not current.is_symlink():
                raise SetupError(
                    f"existing Foundry path is not a file or symbolic link: {current}"
                )
            copy_entry(current, self.backup_directory / binary)

    def install(self, extracted_directory):
        self.rollback_required = True
        if self.destination_created:
            self.destination.mkdir(parents=True, mode=0o755)
            self.destination.chmod(0o755)
        for binary in BINARIES:
            descriptor, temporary_name = tempfile.mkstemp(
                dir=self.destination, prefix=f".{binary}.setup-foundry."
            )
            os.close(descriptor)
            temporary = Path(temporary_name)
            try:
                shutil.copyfile(extracted_directory / binary, temporary)
                temporary.chmod(0o755)
                os.replace(temporary, self.destination / binary)
            finally:
                if path_exists(temporary):
                    temporary.unlink()

    def commit(self):
        self.rollback_required = False

    def rollback(self):
        if not self.rollback_required:
            return True
        print(
            "\nInstallation did not complete; restoring the previous Foundry binaries.",
            file=sys.stderr,
        )
        rollback_failed = False
        for binary in BINARIES:
            current, backup = self.destination / binary, self.backup_directory / binary
            try:
                if path_exists(current):
                    current.unlink()
                if path_exists(backup):
                    copy_entry(backup, current)
            except OSError as error:
                print(
                    f"Rollback error: could not restore {current}: {error}",
                    file=sys.stderr,
                )
                rollback_failed = True
        if self.destination_created and path_exists(self.destination):
            try:
                self.destination.rmdir()
            except OSError as error:
                print(
                    f"Rollback error: could not remove newly created directory {self.destination}: {error}",
                    file=sys.stderr,
                )
                rollback_failed = True
        if rollback_failed:
            print(
                f"Error: Foundry rollback was incomplete; inspect {self.destination} before continuing.",
                file=sys.stderr,
            )
            print(f"Backups preserved at: {self.backup_directory}", file=sys.stderr)
        else:
            print("Previous Foundry installation restored.", file=sys.stderr)
        self.rollback_required = False
        return not rollback_failed


def install_and_verify_binaries(
    installation, extracted_directory, destination, expected_tag
):
    installation.install(extracted_directory)
    paths = [destination / binary for binary in BINARIES]
    verify_binary_paths(paths, expected_tag)
    run_binary_versions(paths)
    installation.commit()


def install_selected_release(selection, destination):
    asset = foundry_release_asset(selection)

    # Own this directory explicitly so incomplete rollback can retain recovery data.
    temporary_directory = Path(tempfile.mkdtemp())
    preserve_recovery_data = False
    try:
        extracted_directory = temporary_directory / "extracted"
        backup_directory = temporary_directory / "previous-installation"
        archive = download_and_verify_release_asset(
            selection, asset, temporary_directory
        )
        extract_release_archive(archive, extracted_directory)
        installation = Installation(destination, backup_directory)
        installation.prepare()
        try:
            install_and_verify_binaries(
                installation, extracted_directory, destination, selection["version"]
            )
        except BaseException:
            preserve_recovery_data = not installation.rollback()
            raise
    finally:
        if not preserve_recovery_data:
            shutil.rmtree(temporary_directory)
