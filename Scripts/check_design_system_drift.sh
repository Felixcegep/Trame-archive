#!/bin/bash
set -u

# Review-oriented Trame drift audit. It is intentionally report-only unless
# --strict is supplied; existing production UI is inventory, not a rewrite.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOT="$REPO_ROOT/GymTracker"
ALLOWLIST_PATH="${DESIGN_SYSTEM_DRIFT_ALLOWLIST:-$REPO_ROOT/Scripts/design_system_drift_allowlist.txt}"
STRICT=0

usage() {
  cat <<'EOF'
Usage: ./Scripts/check_design_system_drift.sh [--strict]

  (default)  Report unsuppressed production SwiftUI drift and exit 0.
  --strict   Report the same findings, then exit 1 when any remain.
  -h, --help Show this help.

The scan excludes centralized design-system Swift, tests, generated code, and
vendor/dependency trees. Reviewed exceptions belong in
Scripts/design_system_drift_allowlist.txt; see
Documentation/Design/DesignSystemDriftAudit.md.
EOF
}

for argument in "$@"; do
  case "$argument" in
    --strict) STRICT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $argument" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! -d "$SCAN_ROOT" ]]; then
  echo "Design-system drift audit: missing scan root: $SCAN_ROOT" >&2
  exit 2
fi

HAS_RG=0
if command -v rg >/dev/null 2>&1; then
  HAS_RG=1
elif ! command -v grep >/dev/null 2>&1; then
  echo "Design-system drift audit: requires rg or grep" >&2
  exit 2
fi

RULE_NAMES=(
  "arbitrary-color-red"
  "arbitrary-color-hex"
  "arbitrary-radius"
  "arbitrary-system-font"
  "direct-system-image"
  "direct-animation"
)
RULE_PATTERNS=(
  'Color[[:space:]]*\([[:space:]]*red[[:space:]]*:'
  'Color[[:space:]]*\([[:space:]]*hex[[:space:]]*:'
  '\.cornerRadius[[:space:]]*\('
  '\.font[[:space:]]*\([[:space:]]*\.system[[:space:]]*\([[:space:]]*size[[:space:]]*:'
  'Image[[:space:]]*\([[:space:]]*systemName[[:space:]]*:'
  '\.animation[[:space:]]*\('
)

is_excluded_path() {
  case "$1" in
    GymTracker/Core/DesignSystem/*|GymTrackerTests/*|GymTrackerUITEST/*|*/Generated/*|*/Vendor/*|*/Pods/*|*/Carthage/*|*/DerivedData/*|*/Preview\ Content/*)
      return 0
      ;;
  esac
  return 1
}

# Allowlist rows are: path-glob|rule-name|extended-regex|reason
# The reason is documentation for reviewers and is not interpreted.
is_allowlisted() {
  local relative_path="$1"
  local rule_name="$2"
  local source_line="$3"
  local path_glob rule_pattern line_regex reason

  [[ -f "$ALLOWLIST_PATH" ]] || return 1
  while IFS='|' read -r path_glob rule_pattern line_regex reason; do
    [[ -z "$path_glob" || "${path_glob#\#}" != "$path_glob" ]] && continue
    [[ "$path_glob" == "*" || -z "$line_regex" ]] && continue
    if [[ "$relative_path" == $path_glob && "$rule_name" == "$rule_pattern" && "$source_line" =~ $line_regex ]]; then
      return 0
    fi
  done < "$ALLOWLIST_PATH"
  return 1
}

search_matches() {
  local pattern="$1"
  local source_file="$2"
  if [[ "$HAS_RG" -eq 1 ]]; then
    rg --line-number --no-heading --color never -- "$pattern" "$source_file" || true
  else
    grep -nE -- "$pattern" "$source_file" || true
  fi
}

file_list=""
if [[ "$HAS_RG" -eq 1 ]]; then
  file_list="$(rg --files "$SCAN_ROOT" -g '*.swift' || true)"
else
  file_list="$(find "$SCAN_ROOT" -type f -name '*.swift' -print)"
fi

finding_file="$(mktemp "${TMPDIR:-/tmp}/gymtracker-design-drift.XXXXXX")"
trap 'rm -f "$finding_file"' EXIT

counts=(0 0 0 0 0 0)
total=0
while IFS= read -r source_file; do
  [[ -z "$source_file" ]] && continue
  relative_path="${source_file#$REPO_ROOT/}"
  is_excluded_path "$relative_path" && continue

  for index in "${!RULE_NAMES[@]}"; do
    while IFS=: read -r line_number source_line; do
      [[ -z "$line_number" ]] && continue
      [[ "$source_line" =~ ^[[:space:]]*// ]] && continue
      if is_allowlisted "$relative_path" "${RULE_NAMES[$index]}" "$source_line"; then
        continue
      fi
      printf '%s\t%s\t%s\t%s\n' "${RULE_NAMES[$index]}" "$relative_path" "$line_number" "$source_line" >> "$finding_file"
      counts[$index]=$((counts[$index] + 1))
      total=$((total + 1))
    done < <(search_matches "${RULE_PATTERNS[$index]}" "$source_file")
  done
done <<< "$file_list"

mode="report-only"
[[ "$STRICT" -eq 1 ]] && mode="strict"
echo "Design-system drift audit ($mode)"
echo "Scope: production Swift under GymTracker (design-system, tests, generated, and vendor paths excluded)"
echo "Allowlist: ${ALLOWLIST_PATH#$REPO_ROOT/}"
echo
echo "Findings: $total"
for index in "${!RULE_NAMES[@]}"; do
  printf '  %-24s %d\n' "${RULE_NAMES[$index]}" "${counts[$index]}"
done

if [[ "$total" -gt 0 ]]; then
  echo
  echo "Actionable findings (file:line: source):"
  while IFS=$'\t' read -r rule_name relative_path line_number source_line; do
    printf '%s %s:%s: %s\n' "$rule_name" "$relative_path" "$line_number" "$source_line"
  done < "$finding_file"
fi

if [[ "$STRICT" -eq 1 && "$total" -gt 0 ]]; then
  exit 1
fi
exit 0
