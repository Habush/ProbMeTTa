#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PROBMETTA_DIR="$ROOT"
PETTA_DIR="${PETTA_DIR:-$ROOT/.deps/PeTTa}"
SWIPL="${SWIPL:-$ROOT/.deps/swipl/bin/swipl}"

extra=()
if [[ -f "$PETTA_DIR/mork_ffi/target/release/libmork_ffi.so" ]]; then
    export LD_PRELOAD="$PETTA_DIR/mork_ffi/target/release/libmork_ffi.so${LD_PRELOAD:+:$LD_PRELOAD}"
    extra=(mork)
fi

cd "$ROOT"

"$SWIPL" --stack_limit=8g --on-error=status -q \
    -g "getenv('PROBMETTA_DIR', Dir), asserta(library_path(Dir))" \
    -s "$PETTA_DIR/src/main.pl" -- "$@" "${extra[@]}" \
    | sed -u -E '/^(true|\((true|[()[:space:]])*\))$/d'
