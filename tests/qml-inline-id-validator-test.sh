#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/sleepy-qml-id-validator.XXXXXX")"
cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/property-id" "$test_root/js-object" "$test_root/real-duplicate" \
    "$test_root/multiline-property-id" "$test_root/multiline-real-duplicate"

cat >"$test_root/property-id/PropertyId.qml" <<'QML'
import QtQuick

Item {
    Item { id: modelData }

    component PropertyOnly: QtObject {
        readonly property string id: modelData.id
    }
}
QML

cat >"$test_root/multiline-property-id/MultilinePropertyId.qml" <<'QML'
import QtQuick

Item {
    Item { id: modelData }

    component PropertyOnly: QtObject {
        readonly property string
            id: modelData
    }
}
QML

cat >"$test_root/js-object/JsObject.qml" <<'QML'
import QtQuick

Item {
    property var rows: [{id: "bluetooth", label: "Bluetooth"}]

    component LabelItem: QtObject {
        id: label
    }
}
QML

cat >"$test_root/multiline-real-duplicate/MultilineRealDuplicate.qml" <<'QML'
import QtQuick

Item {
    Item { id: actualDuplicate }

    component DuplicateItem: QtObject {
        id: actualDuplicate
        readonly property string
            id: modelData
    }
}
QML

cat >"$test_root/real-duplicate/RealDuplicate.qml" <<'QML'
import QtQuick

Item {
    Item { id: actualDuplicate }
    property var rows: [{id: "bluetooth", label: "Bluetooth"}]

    component DuplicateItem: QtObject {
        id: actualDuplicate
        readonly property string id: modelData.id
    }
}
QML

failures=0
run_case() {
    local name="$1"
    local expected_status="$2"
    local source_root="$3"
    local expected_diagnostic="${4:-}"
    local output_file="$test_root/$name.log"
    set +e
    bash "$repo_root/tests/qml-inline-id-contract.sh" "$source_root" \
        >"$output_file" 2>&1
    local status=$?
    set -e
    if [[ $status -ne $expected_status ]]; then
        printf 'FAIL: %s expected validator status %s, observed %s\n' \
            "$name" "$expected_status" "$status" >&2
        sed -n '1,8p' "$output_file" >&2
        failures=$((failures + 1))
    elif [[ -n "$expected_diagnostic" ]] \
            && ! rg -Fq "$expected_diagnostic" "$output_file"; then
        printf 'FAIL: %s did not identify the expected real duplicate %s\n' \
            "$name" "$expected_diagnostic" >&2
        sed -n '1,8p' "$output_file" >&2
        failures=$((failures + 1))
    fi
}

run_case property-named-id 0 "$test_root/property-id"
run_case multiline-property-named-id 0 "$test_root/multiline-property-id"
run_case js-object-literal 0 "$test_root/js-object"
run_case duplicate-with-decoys 1 "$test_root/real-duplicate" "'actualDuplicate'"
run_case multiline-duplicate-with-decoy 1 "$test_root/multiline-real-duplicate" \
    "'actualDuplicate'"

if [[ $failures -ne 0 ]]; then
    printf 'FAIL: QML id validator mishandled %s syntax-context fixture(s)\n' \
        "$failures" >&2
    exit 1
fi

printf 'PASS: QML id validator distinguishes real ids from property and JavaScript decoys\n'
