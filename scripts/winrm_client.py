#!/usr/bin/env python3
"""Upload and run PowerShell scripts through WinRM."""

from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from pathlib import Path
from typing import Any, Mapping, Sequence

from pypsrp.client import Client


PASSWORD_ENV = "EMACS_WINRM_PASSWORD"


def _add_connection_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--host", required=True)
    parser.add_argument("--username", required=True)
    parser.add_argument("--port", type=int, default=5986)
    parser.add_argument("--auth", default="negotiate")
    parser.add_argument(
        "--ssl", action=argparse.BooleanOptionalAction, default=True
    )
    parser.add_argument(
        "--cert-validation", action=argparse.BooleanOptionalAction, default=True
    )
    parser.add_argument("--local-file", type=Path, required=True)
    parser.add_argument("--remote-path")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Upload and run PowerShell scripts through WinRM."
    )
    subparsers = parser.add_subparsers(dest="operation", required=True)

    upload = subparsers.add_parser("upload", help="Upload a PowerShell script")
    _add_connection_arguments(upload)

    run = subparsers.add_parser("run", help="Upload and run a PowerShell script")
    _add_connection_arguments(run)
    run.add_argument(
        "--argument",
        action="append",
        default=[],
        help="Script argument; repeat the option for multiple arguments",
    )
    return parser


def _quote_powershell(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _default_remote_path(local_file: Path) -> str:
    suffix = uuid.uuid4().hex
    return f"C:\\Windows\\Temp\\{local_file.stem}-{suffix}.ps1"


def _emit(payload: Mapping[str, Any], *, stream: Any | None = None) -> None:
    print(json.dumps(payload, ensure_ascii=False), file=stream or sys.stdout)


def _redact(message: str, password: str) -> str:
    return message.replace(password, "***") if password else message


def _client(args: argparse.Namespace, password: str) -> Client:
    return Client(
        args.host,
        username=args.username,
        password=password,
        port=args.port,
        ssl=args.ssl,
        auth=args.auth,
        cert_validation=args.cert_validation,
    )


def main(
    argv: Sequence[str] | None = None,
    *,
    environ: Mapping[str, str] | None = None,
) -> int:
    args = build_parser().parse_args(argv)
    environment = os.environ if environ is None else environ
    password = environment.get(PASSWORD_ENV, "")
    if not password:
        _emit(
            {"ok": False, "error": f"{PASSWORD_ENV} is not set"},
            stream=sys.stderr,
        )
        return 3

    local_file = args.local_file.expanduser().resolve()
    if not local_file.is_file():
        _emit(
            {"ok": False, "error": f"Local file does not exist: {local_file}"},
            stream=sys.stderr,
        )
        return 4

    remote_path = args.remote_path or _default_remote_path(local_file)

    try:
        client = _client(args, password)
        client.copy(str(local_file), remote_path)
        if args.operation == "upload":
            _emit({"ok": True, "operation": "upload", "remote_path": remote_path})
            return 0

        arguments = " ".join(_quote_powershell(value) for value in args.argument)
        command = f"& {_quote_powershell(remote_path)}"
        if arguments:
            command = f"{command} {arguments}"
        output, streams, had_errors = client.execute_ps(command)
        errors = [_redact(str(error), password) for error in streams.error]
        _emit(
            {
                "ok": not had_errors,
                "operation": "run",
                "remote_path": remote_path,
                "stdout": output,
                "stderr": "\n".join(errors),
            },
            stream=sys.stderr if had_errors else sys.stdout,
        )
        return 11 if had_errors else 0
    except Exception as exc:  # pypsrp raises transport-specific exceptions
        _emit(
            {"ok": False, "error": _redact(str(exc), password)},
            stream=sys.stderr,
        )
        return 10


if __name__ == "__main__":
    raise SystemExit(main())
