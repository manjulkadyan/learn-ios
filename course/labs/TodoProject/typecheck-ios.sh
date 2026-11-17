#!/bin/zsh
set -eu
set -o pipefail
lab_dir=${0:A:h}
scratch_dir=$(mktemp -d /private/tmp/todo-ios.XXXXXX)
sdk_path=$(xcrun --sdk iphonesimulator --show-sdk-path)
print -r -- "Scratch: $scratch_dir; SDK: $sdk_path"
macro_flags=()
if [[ ${IOS_COURSE_MACRO_HELPER:-0} == 1 ]]; then
  # Run the compiler helper inside the existing outer workspace sandbox.
  macro_flags=(-Xfrontend -disable-sandbox)
fi
xcrun swiftc -typecheck -swift-version 6 -sdk "$sdk_path" \
  -target arm64-apple-ios17.0-simulator -module-cache-path "$scratch_dir/module-cache" \
  "${macro_flags[@]}" \
  "$lab_dir"/Core/*.swift "$lab_dir/Native/TodoApp.swift"
print -r -- "PASS iOS source typecheck only; no app bundle or simulator interaction"
