#!/usr/bin/env bash
set -euo pipefail

# Vom Speicherort des Skripts zwei Ebenen hoch: docs/scripts -> docs -> Repo-Root
cd "$(dirname "$0")/../.."

# Alle flux-system Verzeichnisse ignorieren und nur YAML-Dateien ausgeben
find . \
  -type d -name flux-system -prune -o \
  -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 \
  | sort -z \
  | while IFS= read -r -d '' file; do
      echo "=============================="
      echo "FILE: $file"
      echo "------------------------------"
      cat "$file"
      echo -e "\n"
    done
