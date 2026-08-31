#!/usr/bin/env python3
"""Follow locally referenced QML/JS components from one root and audit only that graph."""

from __future__ import annotations

import pathlib
import re
import sys


FORBIDDEN = (
    r"import\s+Quickshell\.Hyprland\b",
    r"import\s+Quickshell\.Bluetooth\b",
    r"import\s+Quickshell\.Services\.(?:Pipewire|Mpris|Notifications|UPower|SystemTray)\b",
    r"\b(?:Process|FileView|FileSystemModel|PersistentProperties)\s*\{",
    r"\bexecDetached\b",
    r"import\s+Sleepy\.(?:Services|Models)\b",
    r"\b(?:DBus|DBusInterface|DBusService)\b|org\.freedesktop",
    r"\b(?:hyprctl|nmcli|bluetoothctl|wpctl|playerctl|brightnessctl|upower|systemctl|loginctl)\b",
)
FORBIDDEN_TASK_PATH = re.compile(
    r"/(?:launcher|dashboard|sidebar|notifications|nexus|lock|session|background|areapicker|utilities|drawers)/"
)
HANDWRITTEN_COMMAND_KEY = re.compile(
    r'(?:^|[,{])\s*(?:["\'](?:family|domain|type)["\']|(?:family|domain|type))\s*:',
    re.MULTILINE,
)
IMPORT = re.compile(
    r'^\s*import\s+(?:"([^"]+)"|(qs(?:\.[A-Za-z_][A-Za-z0-9_]*)+))'
    r'(?:\s+\d+(?:\.\d+)?)?(?:\s+as\s+([A-Za-z_][A-Za-z0-9_]*))?', re.MULTILINE)
JS_IMPORT = re.compile(
    r'^\s*import\s+"([^"]+\.js)"\s+as\s+([A-Za-z_][A-Za-z0-9_]*)', re.MULTILINE)


def component_references(text: str) -> tuple[set[str], set[tuple[str, str]]]:
    qualified = set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\.([A-Z][A-Za-z0-9_]*)\b", text))
    unqualified = set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\s*\{", text))
    return unqualified, qualified


def resolve_graph(root: pathlib.Path) -> list[pathlib.Path]:
    repo_src = next((parent / "src" for parent in root.parents if (parent / "src").is_dir()), None)
    if repo_src is None:
        repo_src = root.parent
    pending = [root.resolve()]
    seen: set[pathlib.Path] = set()
    while pending:
        current = pending.pop()
        if current in seen or not current.is_file():
            continue
        seen.add(current)
        text = current.read_text(encoding="utf-8")
        unqualified, qualified = component_references(text)
        import_dirs: list[pathlib.Path] = [current.parent]
        aliases: dict[str, pathlib.Path] = {}
        for relative, module, alias in IMPORT.findall(text):
            if relative:
                candidate = (current.parent / relative).resolve()
            elif module.startswith("qs."):
                candidate = repo_src.joinpath(*module.split(".")[1:]).resolve()
            else:
                continue
            if candidate.is_file():
                pending.append(candidate)
                continue
            if alias:
                aliases[alias] = candidate
            else:
                import_dirs.append(candidate)
        for relative, _alias in JS_IMPORT.findall(text):
            pending.append((current.parent / relative).resolve())
        for alias, name in qualified:
            directory = aliases.get(alias)
            if directory:
                pending.append(directory / f"{name}.qml")
        for name in unqualified:
            for directory in import_dirs:
                candidate = directory / f"{name}.qml"
                if candidate.is_file():
                    pending.append(candidate)
        # Singleton references do not use component braces.
        for directory in import_dirs:
            if not directory.is_dir():
                continue
            for candidate in directory.glob("[A-Z]*.qml"):
                if re.search(rf"\b{re.escape(candidate.stem)}\b", text):
                    pending.append(candidate)
    return sorted(seen)


def main() -> int:
    root = pathlib.Path(sys.argv[1]).resolve()
    failures: list[str] = []
    graph = resolve_graph(root)
    for path in graph:
        text = path.read_text(encoding="utf-8")
        display = str(path)
        if FORBIDDEN_TASK_PATH.search(display):
            failures.append(f"{display}: forbidden Task 8/10 module is reachable")
        for pattern in FORBIDDEN:
            match = re.search(pattern, text)
            if match:
                failures.append(f"{display}: forbidden reachable token: {match.group(0)}")
        if "/src/core/" in display or display.endswith("/src/shell.qml"):
            if HANDWRITTEN_COMMAND_KEY.search(text):
                failures.append(f"{display}: hand-written command payload in active surface graph")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"PASS: audited {len(graph)} reachable active-graph files from {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
