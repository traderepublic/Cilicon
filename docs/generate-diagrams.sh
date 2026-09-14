#!/usr/bin/env bash
# generate-diagrams.sh — Regenerate all architecture diagrams from source.
#
# Prerequisites (macOS):
#   brew install structurizr-cli plantuml
#
# Usage:
#   ./docs/generate-diagrams.sh

set -euo pipefail

# PlantUML silently clips PNG output at PLANTUML_LIMIT_SIZE (default 4096px)
# in whichever dimension overflows, instead of scaling or erroring. Raise it.
export PLANTUML_LIMIT_SIZE=16384

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSL="$SCRIPT_DIR/structurizr/system.dsl"
DIAGRAMS="$SCRIPT_DIR/diagrams"

structurizr-cli export \
    -workspace "$DSL" \
    -format plantuml \
    -output "$DIAGRAMS" 1>&2

plantuml -tpng "$DIAGRAMS"/*.puml 1>&2

# Structured output: JSON to stdout for agent composability.
# Example:
#   {"status":"ok","diagrams_dir":"docs/diagrams","files":[{"path":"docs/diagrams/system-context.png","bytes":48213}]}
printf '{"status":"ok","diagrams_dir":"%s","files":[' "$DIAGRAMS"
first=1
for f in "$DIAGRAMS"/*.png; do
    [ -e "$f" ] || continue
    bytes=$(wc -c < "$f" | tr -d ' ')
    if [ $first -eq 1 ]; then first=0; else printf ','; fi
    printf '{"path":"%s","bytes":%s}' "$f" "$bytes"
done
printf ']}\n'
