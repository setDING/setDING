#!/usr/bin/env bash
# Fails if an executable or library in a Linux bundle requires an x86 ISA level
# above x86-64-v2 (GNU property "x86 ISA needed"). Such a binary only starts on
# newer CPUs and fails elsewhere with "CPU ISA level is lower than required"
# (ADR-0019).
#
#   tool/release/check-isa.sh <bundle-dir>
set -euo pipefail

bundle="${1:?usage: check-isa.sh <bundle-dir>}"
failed=0

while IFS= read -r -d '' file; do
  head -c 4 "$file" | grep -q $'^\x7fELF' || continue
  needed="$(readelf -n "$file" 2>/dev/null | sed -n 's/.*x86 ISA needed: *//p' | head -n 1)"
  if [[ "$needed" == *x86-64-v3* || "$needed" == *x86-64-v4* ]]; then
    echo "error: ${file#"$bundle"/} requires x86 ISA: $needed" >&2
    failed=1
  fi
done < <(find "$bundle" -type f -print0)

if [ "$failed" -ne 0 ]; then
  echo "error: the bundle does not run on every x86-64 CPU; build it with 'make release-linux'" >&2
  exit 1
fi
echo "ISA check passed: no binary in $bundle requires more than x86-64-v2"
