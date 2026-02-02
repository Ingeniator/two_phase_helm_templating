#!/usr/bin/env bash
set -euo pipefail

# Usage: hardcode-security.sh <release_chart_dir> <values_security_yaml>
# Reads all top-level keys from the security values file,
# hardcodes them into templates and removes from values.yaml.
# Handles both toYaml blocks and inline {{ .Values.<key> }} scalars.
# No script changes needed when adding/removing keys.

CHART_DIR="$1"
SEC_FILE="$2"
DEPLOY="$CHART_DIR/templates/deployment.yaml"
VALUES="$CHART_DIR/values.yaml"

# Get all top-level keys from security file
KEYS=$(yq 'keys | .[]' "$SEC_FILE")

cp "$DEPLOY" "$DEPLOY.tmp"
for key in $KEYS; do
  VALUE=$(yq ".${key}" "$SEC_FILE")

  if grep -q "toYaml .Values\.${key}" "$DEPLOY.tmp"; then
    # Block value: replace toYaml line with indented YAML
    indent=$(grep "toYaml .Values\.${key}" "$DEPLOY.tmp" | sed 's/\(^ *\).*/\1/' | head -1)
    yq ".${key}" "$SEC_FILE" | sed "s/^/${indent}/" > /tmp/hardcode_val.txt

    while IFS= read -r line; do
      if [[ "$line" == *"toYaml .Values.${key}"* ]]; then
        cat /tmp/hardcode_val.txt
      else
        printf '%s\n' "$line"
      fi
    done < "$DEPLOY.tmp" > "$DEPLOY.tmp2"
    mv "$DEPLOY.tmp2" "$DEPLOY.tmp"

  elif grep -q "\.Values\.${key}" "$DEPLOY.tmp"; then
    # Scalar value: inline replace {{ .Values.<key> }} with literal value
    sed "s/{{-\{0,1\} *\.Values\.${key} *-\{0,1\}}}/${VALUE}/g" "$DEPLOY.tmp" > "$DEPLOY.tmp2"
    mv "$DEPLOY.tmp2" "$DEPLOY.tmp"
  fi
done

mv "$DEPLOY.tmp" "$DEPLOY"

# Remove all hardcoded keys from values.yaml
DEL_EXPR=""
for key in $KEYS; do
  DEL_EXPR="${DEL_EXPR} | del(.${key})"
done
DEL_EXPR="${DEL_EXPR#" | "}"
yq "${DEL_EXPR}" "$VALUES" > "$VALUES.tmp"
mv "$VALUES.tmp" "$VALUES"

rm -f /tmp/hardcode_val.txt

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
