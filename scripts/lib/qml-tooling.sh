#!/usr/bin/env bash

is_quickshell_import_root() {
  [[ -n "${1:-}" && -f "$1/Quickshell/qmldir" ]]
}

find_quickshell_import_root() {
  local tool_path resolved_path bin_dir prefix candidate import_path
  local -a candidates=()

  if [[ ${SLEEPY_QUICKSHELL_IMPORT_PATH+x} ]]; then
    if is_quickshell_import_root "$SLEEPY_QUICKSHELL_IMPORT_PATH"; then
      printf '%s\n' "$SLEEPY_QUICKSHELL_IMPORT_PATH"
      return 0
    fi
    printf 'FAIL: SLEEPY_QUICKSHELL_IMPORT_PATH does not contain Quickshell/qmldir: %s\n' \
      "$SLEEPY_QUICKSHELL_IMPORT_PATH" >&2
    return 1
  fi

  for import_path in "${QML_IMPORT_PATH:-}" "${QML2_IMPORT_PATH:-}"; do
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] && candidates+=("$candidate")
    done < <(printf '%s' "$import_path" | tr ':' '\n')
  done

  for tool_path in "$@"; do
    [[ -n "$tool_path" && -e "$tool_path" ]] || continue
    resolved_path="$(readlink -f "$tool_path" 2>/dev/null || true)"
    [[ -n "$resolved_path" ]] || continue
    bin_dir="$(dirname "$resolved_path")"
    prefix="$(dirname "$bin_dir")"
    candidates+=(
      "$prefix/lib/qt6/qml"
      "$prefix/lib/qml"
      "$prefix/qml"
    )
  done

  candidates+=(/usr/lib/qt6/qml /usr/local/lib/qt6/qml)
  for candidate in "${candidates[@]}"; do
    if is_quickshell_import_root "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'FAIL: Quickshell is installed but its Qt 6 qmldir was not found; set SLEEPY_QUICKSHELL_IMPORT_PATH\n' >&2
  return 1
}
