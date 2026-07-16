#!/bin/bash

# Shared, per-simulator exclusion for UI-test scripts. Xcode's result bundles
# are not safe when two independent runners target the same simulator.
UI_TEST_LOCK_ROOT="${UI_TEST_LOCK_ROOT:-/private/tmp/GymTrackerUISimulatorLocks}"
UI_TEST_LOCK_DIRS=()

acquire_ui_test_simulator_lock() {
  local simulator_id="$1"
  local owner="$2"
  local lock_dir="$UI_TEST_LOCK_ROOT/$simulator_id.lock"
  local owner_file="$lock_dir/owner"
  local owner_pid=""

  mkdir -p "$UI_TEST_LOCK_ROOT"

  if [[ -d "$lock_dir" && -f "$owner_file" ]]; then
    owner_pid="$(sed -n 's/^pid=//p' "$owner_file" | head -n 1)"
    if [[ "$owner_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$owner_pid" 2>/dev/null; then
      echo "Removing stale UI-test lock for simulator $simulator_id (former PID $owner_pid)."
      rm -rf "$lock_dir"
    fi
  fi

  if ! mkdir "$lock_dir" 2>/dev/null; then
    echo "Simulator $simulator_id is already reserved by another UI-test runner." >&2
    if [[ -f "$owner_file" ]]; then
      sed -n '1,3p' "$owner_file" >&2
    fi
    return 1
  fi

  printf 'pid=%s\nowner=%s\nstarted=%s\n' \
    "$$" "$owner" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$owner_file"
  UI_TEST_LOCK_DIRS+=("$lock_dir")
}

release_ui_test_simulator_locks() {
  local lock_dir
  for lock_dir in "${UI_TEST_LOCK_DIRS[@]:-}"; do
    [[ -d "$lock_dir" ]] && rm -rf "$lock_dir"
  done
  UI_TEST_LOCK_DIRS=()
}
