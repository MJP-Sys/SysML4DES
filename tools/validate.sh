#!/usr/bin/env bash
# Validate every model with the OMG SysML v2 pilot implementation.
# Needs: Java 17+, and SYSML_PILOT pointing at the directory holding
# jupyter-sysml-kernel-<version>-all.jar and sysml.library
# (tools/get-pilot.sh downloads it).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SYSML_PILOT:?set SYSML_PILOT (see tools/get-pilot.sh)}"
JAR=$(ls "$SYSML_PILOT"/jupyter-sysml-kernel-*-all.jar | head -1)
LIB="$SYSML_PILOT/sysml.library"
run() { java -cp "$JAR" tools/Validate.java "$LIB" "$@" 2>&1 | grep -v -e '^Picked up' -e 'SLF4J' -e '^Reading ' -e '^log4j:' ; return "${PIPESTATUS[0]}"; }

status=0
echo "== Models that must pass (strict: warnings fail) =="
run --strict $(find models -name '*.sysml' ! -path '*/00-restriction/*InPart.sysml' | sort) || status=1
echo
echo "== Negative tests that must be rejected =="
run --expect-fail models/00-restriction/*InPart.sysml || status=1
exit $status
