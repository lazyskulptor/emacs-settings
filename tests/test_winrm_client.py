import importlib.util
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch


MODULE_PATH = Path(__file__).parents[1] / "scripts" / "winrm_client.py"
SPEC = importlib.util.spec_from_file_location("winrm_client", MODULE_PATH)
assert SPEC and SPEC.loader
winrm_client = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(winrm_client)


class WinRMClientTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.script = Path(self.temp_dir.name) / "sample.ps1"
        self.script.write_text("Write-Output ok\n", encoding="utf-8")

    def _base_args(self, operation: str) -> list[str]:
        return [
            operation,
            "--host",
            "server.example.com",
            "--username",
            "Administrator",
            "--proxy",
            "socks5h://127.0.0.1:1081",
            "--local-file",
            str(self.script),
        ]

    def test_upload_uses_winrm_options_and_copies_file(self) -> None:
        client = Mock()
        stdout = io.StringIO()
        with patch.object(winrm_client, "Client", return_value=client) as client_type:
            with redirect_stdout(stdout):
                result = winrm_client.main(
                    self._base_args("upload")
                    + ["--remote-path", "C:\\Temp\\sample.ps1"],
                    environ={winrm_client.PASSWORD_ENV: "secret"},
                )

        self.assertEqual(result, 0)
        client_type.assert_called_once_with(
            "server.example.com",
            username="Administrator",
            password="secret",
            port=5986,
            ssl=True,
            auth="negotiate",
            cert_validation=True,
            proxy="socks5h://127.0.0.1:1081",
        )
        client.copy.assert_called_once_with(
            str(self.script.resolve()), "C:\\Temp\\sample.ps1"
        )
        self.assertNotIn("secret", stdout.getvalue())

    def test_run_quotes_script_path_and_arguments(self) -> None:
        client = Mock()
        client.execute_ps.return_value = (
            "done",
            SimpleNamespace(error=[]),
            False,
        )
        stdout = io.StringIO()
        with patch.object(winrm_client, "Client", return_value=client):
            with redirect_stdout(stdout):
                result = winrm_client.main(
                    self._base_args("run")
                    + [
                        "--remote-path",
                        "C:\\Temp\\it's.ps1",
                        "--argument",
                        "O'Brien",
                    ],
                    environ={winrm_client.PASSWORD_ENV: "secret"},
                )

        self.assertEqual(result, 0)
        client.execute_ps.assert_called_once_with(
            "& 'C:\\Temp\\it''s.ps1' 'O''Brien'"
        )
        self.assertIn('"stdout": "done"', stdout.getvalue())

    def test_transport_error_redacts_password(self) -> None:
        stderr = io.StringIO()
        with patch.object(
            winrm_client, "Client", side_effect=RuntimeError("bad secret credential")
        ):
            with redirect_stderr(stderr):
                result = winrm_client.main(
                    self._base_args("upload"),
                    environ={winrm_client.PASSWORD_ENV: "secret"},
                )

        self.assertEqual(result, 10)
        self.assertNotIn("secret", stderr.getvalue())
        self.assertIn("bad *** credential", stderr.getvalue())

    def test_remote_error_is_reported_with_nonzero_status(self) -> None:
        client = Mock()
        client.execute_ps.return_value = (
            "",
            SimpleNamespace(error=["failed with secret"]),
            True,
        )
        stderr = io.StringIO()
        with patch.object(winrm_client, "Client", return_value=client):
            with redirect_stderr(stderr):
                result = winrm_client.main(
                    self._base_args("run"),
                    environ={winrm_client.PASSWORD_ENV: "secret"},
                )

        self.assertEqual(result, 11)
        self.assertNotIn("secret", stderr.getvalue())
        self.assertIn("failed with ***", stderr.getvalue())

    def test_missing_password_fails_before_connecting(self) -> None:
        stderr = io.StringIO()
        with patch.object(winrm_client, "Client") as client_type:
            with redirect_stderr(stderr):
                result = winrm_client.main(
                    self._base_args("upload"), environ={}
                )

        self.assertEqual(result, 3)
        client_type.assert_not_called()
        self.assertIn(winrm_client.PASSWORD_ENV, stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
