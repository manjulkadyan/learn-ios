#!/bin/sh
set -eu
lab_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
lab_output=$(mktemp -d /private/tmp/concurrency-host-089-XXXXXXXX)
export TMPDIR="$lab_output"
export CLANG_MODULE_CACHE_PATH="$lab_output/clang-cache"
export SWIFT_MODULECACHE_PATH="$lab_output/module-cache"
cd "$lab_root"
swift --version > "$lab_output/toolchain.txt" 2>&1
if swift test --disable-sandbox \
    --scratch-path "$lab_output/build" --cache-path "$lab_output/cache" \
    --config-path "$lab_output/config" --security-path "$lab_output/security" \
    -Xswiftc -module-cache-path -Xswiftc "$lab_output/module-cache" \
    > "$lab_output/tests.txt" 2>&1; then
    cat "$lab_output/toolchain.txt" "$lab_output/tests.txt"
    printf '\nEvidence: %s\n' "$lab_output"
else
    cat "$lab_output/toolchain.txt" "$lab_output/tests.txt"
    printf '\nFailed evidence: %s\n' "$lab_output"
    exit 1
fi
