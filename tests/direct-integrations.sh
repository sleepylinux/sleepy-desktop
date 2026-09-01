#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
registry="$repo_root/tests/direct-integrations.json"

python3 - "$repo_root" "$registry" <<'PY'
import importlib.util
import json
import pathlib
import re
import sys

sys.dont_write_bytecode = True

repo = pathlib.Path(sys.argv[1])
registry_path = pathlib.Path(sys.argv[2])
data = json.loads(registry_path.read_text())
expected = {
    "hyprland", "network", "audio", "brightness", "media", "notifications",
    "tray", "power", "clipboard", "screenshot", "applications",
    "appearance", "weather", "vpn",
}
providers = data.get("providers", [])
ids = [provider.get("id") for provider in providers]
if data.get("formatVersion") != 1 or set(ids) != expected or len(ids) != len(expected):
    raise SystemExit(f"FAIL: direct provider ids must be exactly {sorted(expected)}")

required = {
    "owner", "mechanism", "commands", "stateSource", "mutationSource",
    "reconciliation", "secretPolicy", "tests",
}
registered_commands = set()
for provider in providers:
    missing = required - provider.keys()
    if missing:
        raise SystemExit(f"FAIL: provider {provider['id']} is missing {sorted(missing)}")
    if not all(isinstance(provider[key], str) and provider[key] for key in required - {"commands", "tests"}):
        raise SystemExit(f"FAIL: provider {provider['id']} has an empty ownership field")
    if not isinstance(provider["commands"], list) or not isinstance(provider["tests"], list) or not provider["tests"]:
        raise SystemExit(f"FAIL: provider {provider['id']} has invalid commands/tests")
    optional = provider.get("optionalCommands", [])
    if not isinstance(optional, list) or not set(optional).issubset(provider["commands"]):
        raise SystemExit(f"FAIL: provider {provider['id']} has invalid optionalCommands")
    registered_commands.update(provider["commands"])

spec = importlib.util.spec_from_file_location("active_graph", repo / "tests/active-graph.py")
module = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(module)
_, graph, failures = module.resolve_graph(repo / "src/shell.qml")
if failures:
    raise SystemExit("FAIL: active graph cannot be audited: " + "; ".join(failures))

shell_c = re.compile(r'["\'](?:ba|da|fi|z)?sh["\']\s*,\s*["\']-[cC]["\']', re.I)
credential_argv = re.compile(
    r'(?:command\s*:|execDetached\s*\()[\s\S]{0,700}'
    r'["\'](?:password|passwd|psk|secret|token)["\']', re.I)
string_command = re.compile(r'\bcommand\s*:\s*(?!\[|\{)["\'`]')
literal_command = re.compile(r'(?:command\s*:|execDetached\s*\()\s*\[\s*["\']([^"\']+)')

for path in graph:
    text = path.read_text(errors="ignore")
    rel = path.relative_to(repo)
    if match := shell_c.search(text):
        raise SystemExit(f"FAIL: shell interpreter command in {rel}: {match.group(0)}")
    if match := credential_argv.search(text):
        raise SystemExit(f"FAIL: secret-bearing argv in {rel}: {match.group(0)}")
    if match := string_command.search(text):
        raise SystemExit(f"FAIL: command must be an argv array in {rel}: {match.group(0)}")
    for command in literal_command.findall(text):
        if command not in registered_commands:
            raise SystemExit(f"FAIL: unregistered executable in {rel}: {command}")

contracts = {
    "Hypr.qml": "import Quickshell.Hyprland",
    "Nmcli.qml": 'command: ["nmcli"',
    "Audio.qml": "import Quickshell.Services.Pipewire",
    "Brightness.qml": '["brightnessctl"',
    "Players.qml": "import Quickshell.Services.Mpris",
    "Notifs.qml": "import Quickshell.Services.Notifications",
}
for name, marker in contracts.items():
    text = (repo / "src/services" / name).read_text()
    if marker not in text:
        raise SystemExit(f"FAIL: {name} is not connected to its direct provider ({marker})")
    for status in ("available", "busy", "lastError"):
        if not re.search(rf'\bproperty\s+[^\n]+\b{status}\b', text):
            raise SystemExit(f"FAIL: {name} does not expose {status}")
    if not re.search(r'\bfunction\s+refresh\s*\(', text):
        raise SystemExit(f"FAIL: {name} does not expose refresh()")

print(f"PASS: {len(providers)} direct providers are registered and {len(graph)} active files use safe reviewed mechanisms")
PY
