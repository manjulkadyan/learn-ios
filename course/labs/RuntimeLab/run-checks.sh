#!/bin/zsh
set -eu
runtime_lab_dir=${0:A:h}
runtime_cache_root=$(mktemp -d /private/tmp/runtime-lab.XXXXXX)
print "Runtime lab output/cache: $runtime_cache_root"
swift --version
SWIFTPM_MODULECACHE_OVERRIDE="$runtime_cache_root/module-cache" \
CLANG_MODULE_CACHE_PATH="$runtime_cache_root/clang-cache" \
RUNTIME_LAB_TMP="$runtime_cache_root" \
swift run --package-path "$runtime_lab_dir" \
  --scratch-path "$runtime_cache_root/build" \
  --cache-path "$runtime_cache_root/cache" \
  --config-path "$runtime_cache_root/config" \
  --security-path "$runtime_cache_root/security" \
  --disable-sandbox --jobs 2 runtime-lab
