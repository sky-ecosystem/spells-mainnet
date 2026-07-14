import unittest
from unittest import mock

from test_support import load_module


class VerifyHandlerTests(unittest.TestCase):
    def test_only_orchestrates_high_level_steps(self):
        verify = load_module("commands.verify")
        selection = object()
        paths = object()
        calls = []

        def record(name, result=None):
            return mock.Mock(
                side_effect=lambda *args: calls.append((name, args)) or result
            )

        with mock.patch.multiple(
            verify,
            validate_environment=record("validate"),
            collect_source_metadata=record("metadata", ("commit", "sha256")),
            select_release=record("select", selection),
            report_selection=record("report_selection"),
            resolve_path_binaries=record("resolve", paths),
            verify_binary_paths=record("attest", "v2.0.0"),
            validate_installed_release=record("policy", "eligible"),
            run_binary_versions=record("versions"),
            report_verification_summary=record("summary"),
        ):
            self.assertEqual(verify.handle(), 0)

        self.assertEqual(
            calls,
            [
                ("validate", ()),
                ("metadata", (verify.TOOL_ROOT,)),
                ("select", ()),
                ("report_selection", (selection, "commit", "sha256")),
                ("resolve", ()),
                ("attest", (paths,)),
                ("policy", ("v2.0.0", selection)),
                ("versions", (paths,)),
                ("summary", (selection, "commit", "sha256", "v2.0.0", "eligible")),
            ],
        )
