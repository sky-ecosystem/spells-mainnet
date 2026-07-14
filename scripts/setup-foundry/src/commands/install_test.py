import unittest
from unittest import mock

from test_support import load_module


class InstallHandlerTests(unittest.TestCase):
    def test_only_orchestrates_high_level_steps(self):
        module = load_module("commands.install")
        selection = object()
        destination = object()
        calls = []

        def record(name, result=None):
            return mock.Mock(
                side_effect=lambda *args: calls.append((name, args)) or result
            )

        with mock.patch.multiple(
            module,
            create=True,
            validate_environment=record("validate"),
            collect_source_metadata=record("metadata", ("commit", "sha256")),
            select_release=record("select", selection),
            foundry_destination=record("destination", destination),
            report_selection=record("report_selection"),
            install_selected_release=record("install"),
            report_installation_summary=record("report_summary"),
            report_installation_path_status=record("path_status", 2),
        ):
            self.assertEqual(module.handle(), 2)

        self.assertEqual(
            calls,
            [
                ("validate", ()),
                ("metadata", (module.TOOL_ROOT,)),
                ("select", ()),
                ("destination", ()),
                ("report_selection", (selection, "commit", "sha256")),
                ("install", (selection, destination)),
                ("report_summary", (selection, "commit", "sha256")),
                ("path_status", (destination,)),
            ],
        )
