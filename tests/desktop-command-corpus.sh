#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sdk_root="${SLEEPY_SDK_ROOT:-$(cd "$repo_root/../sleepy-sdk" && pwd -P)}"
schema="$sdk_root/schemas/desktop-command-v3.schema.json"
fixture="$repo_root/tests/fixtures/desktop-command-corpus.json"
builders="$repo_root/src/services/DesktopCommands.js"
services="$repo_root/src/services"

if [[ ! -f "$schema" ]]; then
  printf 'FAIL: desktop command schema is missing: %s\n' "$schema" >&2
  exit 1
fi

python3 - "$schema" "$fixture" "$builders" "$services" <<'PY'
import json
import pathlib
import re
import sys

schema_path, fixture_path, builders_path, services_path = sys.argv[1:5]
schema = json.load(open(schema_path, encoding="utf-8"))
fixtures = json.load(open(fixture_path, encoding="utf-8"))


class ValidationError(Exception):
    pass


def resolve_ref(ref):
    if not ref.startswith("#/"):
        raise ValidationError(f"unsupported external ref {ref}")
    node = schema
    for part in ref[2:].split("/"):
        node = node[part]
    return node


def type_matches(expected, value):
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return (isinstance(value, int) or isinstance(value, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    return True


def validate(node, value, path="$"):
    if "$ref" in node:
        return validate(resolve_ref(node["$ref"]), value, path)
    if "oneOf" in node:
        matches = 0
        errors = []
        for option in node["oneOf"]:
            try:
                validate(option, value, path)
                matches += 1
            except ValidationError as error:
                errors.append(str(error))
        if matches != 1:
            raise ValidationError(f"{path}: expected oneOf match, got {matches}: {errors[:3]}")
    if "const" in node and value != node["const"]:
        raise ValidationError(f"{path}: expected {node['const']!r}, got {value!r}")
    if "enum" in node and value not in node["enum"]:
        raise ValidationError(f"{path}: {value!r} not in enum {node['enum']!r}")
    expected_type = node.get("type")
    if expected_type:
        accepted = expected_type if isinstance(expected_type, list) else [expected_type]
        if not any(type_matches(kind, value) for kind in accepted):
            raise ValidationError(f"{path}: expected type {expected_type!r}, got {type(value).__name__}")
    if isinstance(value, str):
        if "minLength" in node and len(value) < node["minLength"]:
            raise ValidationError(f"{path}: shorter than minLength")
        if "maxLength" in node and len(value) > node["maxLength"]:
            raise ValidationError(f"{path}: longer than maxLength")
        if "pattern" in node and not re.search(node["pattern"], value):
            raise ValidationError(f"{path}: does not match pattern {node['pattern']!r}")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in node and value < node["minimum"]:
            raise ValidationError(f"{path}: less than minimum")
        if "maximum" in node and value > node["maximum"]:
            raise ValidationError(f"{path}: greater than maximum")
    if isinstance(value, list) and "items" in node:
        for index, item in enumerate(value):
            validate(node["items"], item, f"{path}[{index}]")
    if isinstance(value, dict):
        for key in node.get("required", []):
            if key not in value:
                raise ValidationError(f"{path}: missing required key {key}")
        properties = node.get("properties", {})
        if node.get("additionalProperties") is False:
            unknown = sorted(set(value) - set(properties))
            if unknown:
                raise ValidationError(f"{path}: unknown keys {unknown}")
        for key, child in properties.items():
            if key in value:
                validate(child, value[key], f"{path}.{key}")


failures = []
fixture_names = set()
fixture_builders = set()
valid_families = {
    "system", "compositor", "notification", "launcher",
    "appearance", "utility", "session",
}

for index, fixture in enumerate(fixtures):
    prefix = f"fixture[{index}]"
    name = fixture.get("name")
    if not isinstance(name, str) or not name.strip():
        failures.append(f"{prefix}: missing non-empty name")
        continue
    if name in fixture_names:
        failures.append(f"{name}: duplicate fixture name")
    fixture_names.add(name)

    builder = fixture.get("builder")
    if not isinstance(builder, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", builder):
        failures.append(f"{name}: missing valid builder name")
    else:
        fixture_builders.add(builder)

    if not isinstance(fixture.get("args"), list):
        failures.append(f"{name}: args must be an array")
    if "command" not in fixture:
        failures.append(f"{name}: missing explicit command expectation")
        continue

    command = fixture.get("command")
    if command is None:
        continue

    family = fixture.get("family")
    if family not in valid_families:
        failures.append(f"{name}: family must be one of {sorted(valid_families)}")
        continue

    request = {
        "schemaVersion": 3,
        "requestId": "11111111-1111-4111-8111-111111111111",
        "expectedGeneration": 9,
        "command": {
            "family": family,
            "command": command,
        },
    }
    try:
        validate(schema, request)
    except ValidationError as error:
        failures.append(f"{name}: {error}")

helpers = {"stableId", "positiveInteger", "normalized", "systemDomain"}
builder_source = pathlib.Path(builders_path).read_text(encoding="utf-8")
exported_builders = {
    match.group(1)
    for match in re.finditer(r"^function ([A-Za-z_][A-Za-z0-9_]*)\(", builder_source, re.MULTILINE)
} - helpers

active_builders = set()
for qml_path in pathlib.Path(services_path).glob("*.qml"):
    qml_source = qml_path.read_text(encoding="utf-8")
    active_builders.update(
        re.findall(r"DesktopCommands\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", qml_source)
    )

unknown_fixtures = fixture_builders - exported_builders
missing_exports = exported_builders - fixture_builders
missing_active = active_builders - fixture_builders
if unknown_fixtures:
    failures.append(f"fixtures reference unknown builders: {sorted(unknown_fixtures)}")
if missing_exports:
    failures.append(f"exported builders missing from corpus: {sorted(missing_exports)}")
if missing_active:
    failures.append(f"active service builders missing from corpus: {sorted(missing_active)}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    sys.exit(1)

valid_count = sum(1 for fixture in fixtures if fixture.get("command") is not None)
print(f"PASS: {valid_count} desktop command builder fixtures validate against {schema_path}")
PY
