#!/usr/bin/env bash
set -euo pipefail

# Usage: hardcode-security.sh <release_chart_dir> <values_security_yaml>
# Reads all top-level keys from the security values file,
# hardcodes them into templates and removes from values.yaml.
# Handles both toYaml blocks and inline {{ .Values.<key> }} scalars.
# No script changes needed when adding/removing keys.

if [ $# -ne 2 ]; then
  echo "Usage: $0 <release_chart_dir> <values_security_yaml>" >&2
  exit 1
fi

CHART_DIR="$1"
SEC_FILE="$2"
VALUES="$CHART_DIR/values.yaml"

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Get all top-level keys from security file
KEYS=$(yq 'keys | .[]' "$SEC_FILE")

for tmpl in "$CHART_DIR"/templates/*.yaml; do
  [ -f "$tmpl" ] || continue

  cp "$tmpl" "$tmpl.tmp"
  for key in $KEYS; do
    VALUE=$(yq ".${key}" "$SEC_FILE")

    if grep -qE "toYaml \.Values\.${key}([^a-zA-Z0-9_]|\$)" "$tmpl.tmp"; then
      # Parse nindent/indent value from the template line
      indent_num=$(grep -E "toYaml \.Values\.${key}([^a-zA-Z0-9_]|\$)" "$tmpl.tmp" \
        | sed -n 's/.*[|] *n\?indent \([0-9]*\).*/\1/p' | head -1)

      if [ -z "$indent_num" ]; then
        # Fall back to leading whitespace of the template line
        indent=$(grep -E "toYaml \.Values\.${key}([^a-zA-Z0-9_]|\$)" "$tmpl.tmp" \
          | sed 's/\(^ *\).*/\1/' | head -1)
      else
        indent=$(printf '%*s' "$indent_num" '')
      fi

      yq ".${key}" "$SEC_FILE" | sed "s/^/${indent}/" > "$TMPFILE"

      while IFS= read -r line; do
        if [[ "$line" == *"toYaml .Values.${key}"* ]]; then
          cat "$TMPFILE"
        else
          printf '%s\n' "$line"
        fi
      done < "$tmpl.tmp" > "$tmpl.tmp2"
      mv "$tmpl.tmp2" "$tmpl.tmp"

    elif grep -qE "\.Values\.${key}([^a-zA-Z0-9_]|\$)" "$tmpl.tmp"; then
      # Scalar value: inline replace {{ .Values.<key> }} with literal value
      while IFS= read -r line; do
        while [[ "$line" =~ (.*)\{\{-?[[:space:]]*\.Values\.${key}[[:space:]]*-?\}\}(.*) ]]; do
          line="${BASH_REMATCH[1]}${VALUE}${BASH_REMATCH[2]}"
        done
        printf '%s\n' "$line"
      done < "$tmpl.tmp" > "$tmpl.tmp2"
      mv "$tmpl.tmp2" "$tmpl.tmp"
    fi
  done

  mv "$tmpl.tmp" "$tmpl"
done

# Remove all hardcoded keys from values.yaml
DEL_EXPR=""
for key in $KEYS; do
  DEL_EXPR="${DEL_EXPR} | del(.${key})"
done
DEL_EXPR="${DEL_EXPR#" | "}"
yq "${DEL_EXPR}" "$VALUES" > "$VALUES.tmp"
mv "$VALUES.tmp" "$VALUES"

# Remove files matching .releaseignore patterns
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASEIGNORE="$SCRIPT_DIR/../.releaseignore"
if [ -f "$RELEASEIGNORE" ]; then
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in \#*) continue;; esac
    for f in $(find "$CHART_DIR" -name "$pattern" 2>/dev/null); do
      rm -f "$f" && echo "Removed (releaseignore): $f"
    done
  done < "$RELEASEIGNORE"
fi
