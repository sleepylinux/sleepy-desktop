#!/usr/bin/env python3
"""Follow locally referenced QML/JS components from one root and audit only that graph."""

from __future__ import annotations

import pathlib
import json
import re
import sys


RUNTIME_IDENTITY = re.compile(r"\bcaelestia(?:[-_ ]shell)?\b", re.IGNORECASE)
SHELL_INTERPRETER = re.compile(
    r'["\'](?:ba|da|fi|z)?sh["\']\s*,\s*["\']-[cC]["\']', re.IGNORECASE
)
CREDENTIAL_ARGV = re.compile(
    r'(?:command\s*:|execDetached\s*\()[\s\S]{0,500}'
    r'["\'](?:password|passwd|psk|secret|token)["\']', re.IGNORECASE
)
SLEEPY_IMPORT = re.compile(r'^\s*import\s+(Sleepy(?:\.[A-Za-z_][A-Za-z0-9_]*)?)\b', re.MULTILINE)
REVIEWED_NATIVE_MODULES = {
    "Sleepy",
    "Sleepy.Blobs",
    "Sleepy.Components",
    "Sleepy.Config",
    "Sleepy.Images",
    "Sleepy.Models",
    "Sleepy.Services",
    "Sleepy.Settings",
}
IMPORT = re.compile(
    r'^\s*import\s+(?:"([^"]+)"|(qs(?:\.[A-Za-z_][A-Za-z0-9_]*)+))'
    r'(?:\s+\d+(?:\.\d+)?)?(?:\s+as\s+([A-Za-z_][A-Za-z0-9_]*))?', re.MULTILINE)
JS_IMPORT = re.compile(
    r'^\s*import\s+"([^"]+\.js)"\s+as\s+([A-Za-z_][A-Za-z0-9_]*)', re.MULTILINE)


def component_references(text: str) -> tuple[set[str], set[tuple[str, str]]]:
    qualified = set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\.([A-Z][A-Za-z0-9_]*)\b", text))
    unqualified = set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\s*\{", text))
    return unqualified, qualified


def resolve_graph(root: pathlib.Path) -> tuple[pathlib.Path, list[pathlib.Path], list[str]]:
    repo_src = next((parent for parent in root.parents if parent.name == "src"), root.parent)
    pending = [root.resolve()]
    seen: set[pathlib.Path] = set()
    failures: list[str] = []
    while pending:
        current = pending.pop()
        if current in seen or not current.is_file():
            continue
        if not current.is_relative_to(repo_src):
            failures.append(f"{current}: local import resolves outside the installed Sleepy tree")
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
    return repo_src, sorted(seen), failures


def main() -> int:
    root = pathlib.Path(sys.argv[1]).resolve()
    _repo_src, graph, failures = resolve_graph(root)
    manifest_path = _repo_src.parent / "tests/parity-manifest.json"
    if manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        entries = {entry["path"]: entry for entry in manifest["entries"]}
        root_text = root.read_text(encoding="utf-8")
        direct_names, _ = component_references(root_text)
        for path in graph:
            if path.stem not in direct_names:
                continue
            relative = str(path.relative_to(_repo_src.parent))
            entry = entries.get(relative)
            if entry is None or entry["disposition"] == "drop-with-reason" or entry["sleepyOwner"] == "none":
                failures.append(f"{relative}: directly instantiated production root is missing or declared dropped in parity manifest")
    for path in graph:
        text = path.read_text(encoding="utf-8")
        display = str(path)
        if match := RUNTIME_IDENTITY.search(text):
            failures.append(f"{display}: forbidden runtime identity: {match.group(0)}")
        if match := SHELL_INTERPRETER.search(text):
            failures.append(f"{display}: shell interpreter command is forbidden: {match.group(0)}")
        if match := CREDENTIAL_ARGV.search(text):
            failures.append(f"{display}: credential-bearing argv is forbidden: {match.group(0)}")
        for native_import in SLEEPY_IMPORT.findall(text):
            if native_import not in REVIEWED_NATIVE_MODULES:
                failures.append(f"{display}: unreviewed native module import: {native_import}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"PASS: audited {len(graph)} reachable active-graph files from {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
