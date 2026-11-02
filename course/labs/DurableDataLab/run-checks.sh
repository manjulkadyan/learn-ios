#!/usr/bin/env bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lab_run="$(mktemp -d /private/tmp/DurableDataLab.XXXXXX)"
mkdir -p "$lab_run/tmp" "$lab_run/module-cache"
export TMPDIR="$lab_run/tmp"
export CLANG_MODULE_CACHE_PATH="$lab_run/module-cache"
export SWIFT_MODULECACHE_PATH="$lab_run/module-cache"
printf 'Isolated verification root: %s\n' "$lab_run"
swift --version
common=(-parse-as-library -swift-version 6 -warnings-as-errors -module-cache-path "$lab_run/module-cache")
python3 "$lab_root/ValidateContent.py"
swiftc "${common[@]}" "$lab_root/DurableStore.swift" "$lab_root/MockAuth.swift" "$lab_root/HostChecks.swift" -o "$lab_run/host-checks"
"$lab_run/host-checks" "$lab_run/host-fixtures"
swiftc "${common[@]}" "$lab_root/DurableStore.swift" "$lab_root/RestartProbe.swift" -o "$lab_run/restart-probe"
"$lab_run/restart-probe" seed "$lab_run/restart-fixtures"
"$lab_run/restart-probe" replay "$lab_run/restart-fixtures"
swiftc "${common[@]}" "$lab_root/CoreDataMigration.swift" -o "$lab_run/coredata-checks"
"$lab_run/coredata-checks" "$lab_run/coredata-fixtures"
macro_flags=()
if [[ "${DURABLE_ALLOW_MACRO_HELPER:-0}" == "1" ]]; then
    # Only the compiler's nested helper sandbox; outer workspace sandbox remains.
    macro_flags=(-Xfrontend -disable-sandbox)
fi
swiftc "${common[@]}" "${macro_flags[@]}" "$lab_root/SwiftDataMigration.swift" -o "$lab_run/swiftdata-checks"
"$lab_run/swiftdata-checks" "$lab_run/swiftdata-fixtures/store.sqlite"
swiftc "${common[@]}" "$lab_root/ProtectedDataExercise.swift" "$lab_root/KeychainChecks.swift" -o "$lab_run/keychain-checks"
"$lab_run/keychain-checks"
swiftc "${common[@]}" "$lab_root/NativeTransaction.swift" "$lab_root/NativeChecks.swift" -o "$lab_run/native-checks"
"$lab_run/native-checks"
ios_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
printf 'iOS type-check SDK: %s\n' "$ios_sdk"
swiftc -typecheck -swift-version 6 -warnings-as-errors -target arm64-apple-ios17.0 -sdk "$ios_sdk" \
    -module-cache-path "$lab_run/module-cache-ios" "$lab_root/ProtectedDataExercise.swift"
printf 'PASS iOS seam type-check; no simulator/device launch or Keychain writes\n'
