#!/bin/sh
set -eu
cd "$(dirname "$0")"
export CLANG_MODULE_CACHE_PATH=/private/tmp/architecture-clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/architecture-swift-cache
swift --version
swift test --scratch-path /private/tmp/architecture-project-host \
  --cache-path /private/tmp/architecture-project-cache --disable-sandbox
