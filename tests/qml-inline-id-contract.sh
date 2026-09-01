#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [[ $# -gt 1 ]]; then
    printf 'FAIL: QML inline-id contract accepts at most one source root\n' >&2
    exit 1
fi
source_root="${1:-$repo_root/src}"

python3 - "$source_root" <<'PY'
from pathlib import Path
import re
import sys

source_root = Path(sys.argv[1])
token_pattern = re.compile(
    r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|`(?:\\.|[^`\\])*`|'
    r"[A-Za-z_][A-Za-z0-9_]*|[{}:;,.()\[\]=]"
)
identifier_pattern = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def mask_comments(source: str) -> str:
    result = list(source)
    index = 0
    state = "code"
    quote = ""
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if current == "/" and following == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "line-comment"
                continue
            if current == "/" and following == "*":
                result[index] = result[index + 1] = " "
                index += 2
                state = "block-comment"
                continue
            if current in ('"', "'", "`"):
                quote = current
                index += 1
                state = "string"
                continue
        elif state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                result[index] = " "
            index += 1
            continue
        elif state == "block-comment":
            result[index] = " "
            if current == "*" and following == "/":
                result[index + 1] = " "
                index += 2
                state = "code"
                continue
            index += 1
            continue
        else:
            if current == "\\":
                if index + 1 < len(source):
                    index += 2
                    continue
            elif current == quote:
                state = "code"
            index += 1
            continue
        index += 1
    return "".join(result)


def line_number(source: str, position: int) -> int:
    return source.count("\n", 0, position) + 1


def is_identifier(token: str) -> bool:
    return identifier_pattern.fullmatch(token) is not None


def qml_contexts(tokens):
    contexts = []
    stack = []
    for index, (token, _) in enumerate(tokens):
        contexts.append(stack[-1] if stack else None)
        if token == "{":
            previous = tokens[index - 1][0] if index else ""
            qml_object = is_identifier(previous) and previous not in {
                "return",
                "else",
                "try",
                "finally",
                "do",
            }
            stack.append("qml" if qml_object else "javascript")
        elif token == "}" and stack:
            stack.pop()
    return contexts


def is_qml_id_member(source: str, tokens, contexts, index: int) -> bool:
    if (
        tokens[index][0] != "id"
        or index + 2 >= len(tokens)
        or tokens[index + 1][0] != ":"
        or not is_identifier(tokens[index + 2][0])
        or contexts[index] != "qml"
    ):
        return False
    if index + 3 < len(tokens) and tokens[index + 3][0] == ".":
        return False
    position = tokens[index][1]
    line_start = source.rfind("\n", 0, position) + 1
    declaration_prefix = source[line_start:position]
    return re.search(r"\bproperty\b", declaration_prefix) is None


failures = []
for qml_file in sorted(source_root.rglob("*.qml")):
    source = qml_file.read_text(encoding="utf-8")
    masked_source = mask_comments(source)
    tokens = [(match.group(), match.start()) for match in token_pattern.finditer(masked_source)]
    contexts = qml_contexts(tokens)
    inline_components = []
    for index in range(len(tokens) - 4):
        if tokens[index][0] != "component" or tokens[index + 2][0] != ":":
            continue
        try:
            open_index = next(
                candidate
                for candidate in range(index + 3, len(tokens))
                if tokens[candidate][0] == "{"
            )
        except StopIteration:
            continue
        depth = 0
        close_index = None
        root_id = None
        root_id_position = None
        for candidate in range(open_index, len(tokens)):
            token = tokens[candidate][0]
            if token == "{":
                depth += 1
            elif token == "}":
                depth -= 1
                if depth == 0:
                    close_index = candidate
                    break
            elif depth == 1 and is_qml_id_member(
                masked_source, tokens, contexts, candidate
            ):
                root_id = tokens[candidate + 2][0]
                root_id_position = tokens[candidate + 2][1]
        if close_index is not None:
            inline_components.append(
                (open_index, close_index, root_id, root_id_position)
            )

    inline_token_indexes = set()
    for open_index, close_index, _, _ in inline_components:
        inline_token_indexes.update(range(open_index, close_index + 1))

    outer_ids = {}
    for index in range(len(tokens) - 2):
        if index in inline_token_indexes:
            continue
        if is_qml_id_member(masked_source, tokens, contexts, index):
            outer_ids.setdefault(tokens[index + 2][0], []).append(tokens[index + 2][1])

    for _, _, root_id, root_id_position in inline_components:
        if root_id is None or root_id not in outer_ids:
            continue
        first_outer_position = outer_ids[root_id][0]
        failures.append(
            f"{qml_file}:{line_number(source, root_id_position)}: inline component id "
            f"{root_id!r} duplicates document id at line "
            f"{line_number(source, first_outer_position)}"
        )

if failures:
    print("FAIL: Qt 6.11 rejects inline component ids duplicated in their QML document", file=sys.stderr)
    for failure in failures:
        print(failure, file=sys.stderr)
    raise SystemExit(1)

print("PASS: inline component ids do not collide with enclosing QML document ids")
PY
