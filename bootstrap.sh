#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPS="$ROOT/.deps"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir)
            DEPS="${2:?--install-dir requires a directory}"
            shift 2
            ;;
        *)

            printf 'Unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

DEPS=$(realpath -m -- "${1:-$ROOT/.deps}")
SWIPL_VERSION=9.3.34
SWIPL="$DEPS/swipl/bin/swipl"

swipl_works() {
    "$1" --on-error=status -q \
        -g "current_prolog_flag(version, V), V >= 90300, use_module(library(janus)), use_module(library(pcre)), use_module(library(clpr)), halt" \
        -t 'halt(1)' >/dev/null 2>&1
}

SWIPL_PATH="$SWIPL"
if ! swipl_works "$SWIPL_PATH"; then
    SWIPL_PATH=$(command -v swipl || true)
    if ! swipl_works "$SWIPL_PATH"; then
        SWIPL_PATH=""
    fi
fi

printf 'Installing dependencies:\n'
if [[ -n "$SWIPL_PATH" ]]; then
    printf '  Reusing SWI-Prolog: %s\n' "$SWIPL_PATH"
    "$SWIPL_PATH" --version
else
    printf '  No usable SWI-Prolog found; building %s (including Janus, PCRE, and CLP(R)): %s/swipl\n' "$SWIPL_VERSION" "$DEPS"
    printf '  Downloaded sources and build files: %s/src and %s/build\n' "$DEPS" "$DEPS"
fi
printf '  PeTTa (default branch on first install; existing checkout reused): %s/PeTTa\n' "$DEPS"
printf 'System packages and shell configuration will not be changed.\n\n'

if [[ -n "$SWIPL_PATH" ]]; then
    # Keep run.sh's default path usable when reusing an external installation.
    if [[ "$SWIPL_PATH" != "$SWIPL" ]]; then
        mkdir -p "$DEPS/swipl/bin"
        ln -sf -- "$(realpath -- "$SWIPL_PATH")" "$SWIPL"
    fi
else
    mkdir -p "$DEPS/src"

    # Include the package submodules: PeTTa requires Janus and PCRE.
    if [[ ! -d "$DEPS/src/swipl-$SWIPL_VERSION" ]]; then
        git clone --branch "V$SWIPL_VERSION" --depth 1 \
            https://github.com/SWI-Prolog/swipl-devel.git "$DEPS/src/swipl-$SWIPL_VERSION"
    fi
    git -C "$DEPS/src/swipl-$SWIPL_VERSION" submodule update --init --recursive --depth 1 --jobs 4

    cmake -S "$DEPS/src/swipl-$SWIPL_VERSION" -B "$DEPS/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$DEPS/swipl" \
        -DSWIPL_PACKAGES_GUI=OFF \
        -DSWIPL_PACKAGES_JAVA=OFF \
        -DSWIPL_PACKAGES_ODBC=OFF \
        -DSWIPL_PACKAGES_BDB=OFF \
        -DUSE_TCMALLOC=OFF \
        -DINSTALL_DOCUMENTATION=OFF \
        -DBUILD_TESTING=OFF
    cmake --build "$DEPS/build" --parallel "${JOBS:-4}"
    cmake --install "$DEPS/build"
fi

if [[ ! -d "$DEPS/PeTTa" ]]; then
    git clone --filter=blob:none \
        https://github.com/trueagi-io/PeTTa.git "$DEPS/PeTTa"
fi

swipl_works "$SWIPL"

printf '\nDependencies ready in %s\n' "$DEPS"
printf 'Run from the repository root:\n'
printf '  PETTA_DIR=%q SWIPL=%q bash run.sh lib_pclp.metta sample.pclp --silent\n' \
    "$DEPS/PeTTa" "$SWIPL"