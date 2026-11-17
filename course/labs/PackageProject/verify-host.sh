#!/bin/bash
set -euo pipefail
task_dir=$(cd -- "$(dirname -- "$0")" && pwd)
export CLANG_MODULE_CACHE_PATH=/private/tmp/ios-learning-package-modules
export SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/ios-learning-package-modules
swift --version
swift test --disable-sandbox --package-path "$task_dir" --scratch-path /private/tmp/ios-learning-package-build --cache-path /private/tmp/ios-learning-package-cache
swift run --disable-sandbox --package-path "$task_dir/Consumer" --scratch-path /private/tmp/ios-learning-consumer-build --cache-path /private/tmp/ios-learning-package-cache CatalogConsumer
