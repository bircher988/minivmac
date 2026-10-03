#!/usr/bin/env bash
# build_browser.sh - builds the browser Macs of this branch: Mini vMac compiled to
# WebAssembly with Emscripten, one build per machine (the model is fixed at build time).
#
#   ./build_browser.sh [-o <dir>] [128k|512k|plus]...    (no machine: all three)
#
# Writes <dir>/MinivMac-<machine>.js and .wasm (default dir: out/browser). The build
# runs in a temporary copy of src/ and setup/, so cfg/ and the Makefile of this tree
# stay as they are. Needs the Emscripten SDK (EMSDK_ENV=..., default ~/emsdk).
#
# The speed is fixed to 1x (-speed z), the sound is on, the emulator's own magnify is
# off (the page scales the screen). See BROWSER.md for what the page has to provide.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMSDK_ENV="${EMSDK_ENV:-$HOME/emsdk/emsdk_env.sh}"
OUT="$SRC/out/browser"
if [ "${1:-}" = "-o" ]; then
    OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
    shift 2
fi

die() { echo "build_browser: $*" >&2; exit 1; }
[ -f "$EMSDK_ENV" ] || die "no Emscripten SDK: $EMSDK_ENV (set EMSDK_ENV=...)"
# shellcheck disable=SC1090
source "$EMSDK_ENV" >/dev/null 2>&1
command -v emcc >/dev/null || die "emcc not found after sourcing $EMSDK_ENV"

machines=("$@")
[ ${#machines[@]} -gt 0 ] || machines=(128k 512k plus)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r "$SRC/src" "$SRC/setup" "$WORK/"
mkdir -p "$WORK/cfg" "$WORK/bld" "$OUT"
cd "$WORK"
gcc -o setup_t setup/tool.c

for machine in "${machines[@]}"; do
    case "$machine" in
        128k) model=(-m 128K -mem 128K) ;;
        512k) model=(-m 128K -mem 512K) ;;
        plus) model=(-m Plus -mem 2M) ;; # 4 MB (two banks) does not work in wasm32
        *) die "unknown machine '$machine' (128k, 512k or plus)" ;;
    esac
    rm -f cfg/* Makefile setup.sh
    ./setup_t -t lx86 -api sd2 "${model[@]}" -speed z -as 0 -magnify 0 -sound 1 -n MinivMac > setup.sh
    sh setup.sh > /dev/null
    sources=$(grep -oE "bld/[A-Za-z0-9]+\.o" Makefile | sort -u | sed 's|bld/\(.*\)\.o|src/\1.c|')
    # shellcheck disable=SC2086
    emcc -O2 -Icfg -Isrc $sources \
        -sUSE_SDL=2 -sASYNCIFY -sASYNCIFY_STACK_SIZE=65536 \
        -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=64MB \
        -sFORCE_FILESYSTEM=1 -sEXPORTED_RUNTIME_METHODS=FS,ccall \
        -sINVOKE_RUN=1 -sEXIT_RUNTIME=0 -sMODULARIZE=0 \
        -o "$OUT/MinivMac-$machine.js"
    echo "build_browser: $machine -> $OUT/MinivMac-$machine.js, .wasm"
done
