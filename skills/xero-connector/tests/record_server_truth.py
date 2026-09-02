#!/usr/bin/env python3
"""Re-record the MCP server's registration surface into references/.

The doc-vs-server tests read that record, so they run on a machine that has
never installed `@xeroapi/xero-mcp-server` — a reader's install, or the
community release. Without it the whole suite collapsed into one setUp skip,
and a suite that only runs where the answer is already known proves nothing
about the copy that ships.

Run this after upgrading the server package. `test_the_record_matches_the
_installed_package` fails until you do, so the record cannot rot quietly.

Offline. Reads local node_modules only. No network, no Xero call.

    python3 tests/record_server_truth.py
"""

# resolver key sk-1i8pdw6 (skills-index lookup; keep)

from __future__ import annotations

import json
import sys
from pathlib import Path

TESTS = Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS))

from test_server_truth import (  # noqa: E402
    RECORD_PATH,
    registered_tools,
    scope_set,
    server_root,
)

NOTE = ("Recorded registration surface of @xeroapi/xero-mcp-server. The doc-vs-server "
        "tests read this when the package is not installed, and check it against the "
        "installed package when it is, so it cannot rot unnoticed. "
        "Regenerate: python3 tests/record_server_truth.py")


def main() -> int:
    root = server_root()
    if root is None:
        print("@xeroapi/xero-mcp-server is not installed, so there is nothing to "
              "record from. Install it first; the committed record is left alone.",
              file=sys.stderr)
        return 1
    package = json.loads((root / "package.json").read_text(encoding="utf-8"))
    tools = sorted(registered_tools(root))
    if not tools:
        print("no CreateXeroTool registrations found — refusing to write an empty "
              "record over a good one", file=sys.stderr)
        return 1
    client_js = (root / "dist" / "clients" / "xero-client.js").read_text(errors="ignore")
    record = {
        "_": NOTE,
        "package": package["name"],
        "version": package["version"],
        "tools": tools,
        "scopes": {v: sorted(scope_set(root, v)) for v in ("V1", "V2")},
        # The override lever the whole read-only install rests on: if the server
        # stopped honouring it, pinning XERO_SCOPES would silently stop working
        # and the connection would fall back to write-capable defaults.
        "reads_xero_scopes_env": "process.env.XERO_SCOPES" in client_js,
    }
    RECORD_PATH.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"recorded {len(tools)} tools from {package['name']}@{package['version']}")
    print(f"  -> {RECORD_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
