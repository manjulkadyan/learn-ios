#!/bin/zsh
set -eu
set -o pipefail
lab_dir=${0:A:h}
scratch_dir=$(mktemp -d /private/tmp/todo-project.XXXXXX)
print -r -- "Scratch: $scratch_dir"
swiftc -swift-version 6 -D TODO_HOST -module-cache-path "$scratch_dir/module-cache" \
  "$lab_dir"/Core/*.swift "$lab_dir/Checks/TodoChecks.swift" -o "$scratch_dir/todo-checks"
"$scratch_dir/todo-checks" "$scratch_dir"
