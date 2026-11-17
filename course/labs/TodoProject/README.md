# TodoProject: local task logic and separate native integration

Original synthetic Pocket Tasks companion for sessions 113–116 and workshop
`todo-project`. No company source, packages, accounts, secrets or remote services.
The shared logic is executable offline. The native SwiftUI entry is real adapter
source; no native app bundle or runtime success is claimed by the host test.

## Requirements and files

- Host: Swift 6 language mode, Foundation, macOS with the available Swift toolchain;
  runner uses zsh. The author used arm64 macOS 26.6.2 (25G83), Apple Swift 6.4.2
  (`swiftlang-6.4.2.1.9`, clang 2100.4.1.1). Older compiler/OS combinations were not run.
- Native: Xcode with an iOS Simulator SDK, a separate iOS 17+ App target,
  Swift 6 language mode and real Observation macro expansion. Author Xcode:
  27.2 (27B52); available iOS Simulator SDK: 27.2.
- `Core/Todo.swift`: validated value identity and original-array move boundaries.
- `Core/TodoStore.swift`: one-owner versioned JSON file, explicit v1 conversion,
  current validation and non-destructive load.
- `Core/TodoViewModel.swift`: main-actor commands, candidate-before-publication,
  dirty state, save retry and blocked mutations after failed load.
- `Checks/TodoChecks.swift`: host entry and behavior assertions, not app membership.
- `Native/TodoApp.swift`: actual SwiftUI app, list/editor, focus and accessibility.

## Run shared behavior

From the `ios-learning` workspace:

```sh
zsh course/labs/TodoProject/run-checks.sh
```

The runner creates a unique `/private/tmp/todo-project.XXXXXX` directory for the
binary, module cache and synthetic files. It prints the location and retains it.
It calls `swiftc -swift-version 6 -D TODO_HOST -module-cache-path ...` on all three
Core files and the host entry, then runs the binary with that scratch directory.
No learner completion is recorded. Inspect the directory before manually removing
that exact run's disposable output.

`TODO_HOST` excludes only the Observation import/macro annotations from the shared
view model. The command and store implementation remains the same. This switch is
necessary here because the managed sandbox blocks the compiler's macro subprocess.
It must not be used to claim Observation invalidation or native app verification.
The separate macro-enabled typecheck described below checks the native source.

## Author evidence — 17 November 2026

Executed `zsh course/labs/TodoProject/run-checks.sh` without the conditional host
switch first. It failed at macro expansion, reporting
`sandbox-exec: sandbox_apply: Operation not permitted` and an unavailable
`ObservationMacros.ObservableMacro` implementation/malformed plugin response.
No successful executable was produced by that attempt.

After adding the conditional host switch, executed the same command successfully,
exit 0, scratch `/private/tmp/todo-project.b1NcxG`:

```text
PASS Todo: identity, validation, ordered moves, stale edits, save retry, load protection, disk round trip, migration, future/corrupt/duplicate rejection
```

Actual checks cover whitespace/empty/overlong/combined-emoji titles, equal titles
with distinct IDs, duplicate IDs, noncontiguous and end moves, invalid offset and
duplicate-command non-mutation, ID-based toggle, deleted-task stale edits, derived
count, injected failed saves, refusal to reload dirty memory, latest-snapshot save
retry, blocked changes after failed read, explicit successful read recovery, real
temporary disk round trip, v1 ID/completion/title conversion, unchanged old bytes
before explicit save, v2 reload, unsupported versions, corrupt JSON preservation,
decoded duplicate IDs and invalid decoded titles.

Injected faults verify response policy; they are not real disk-full, permission,
protected-data or interruption tests. The tests execute shared main-actor logic
without Observation; neither UI invalidation nor screen interaction is checked.

Executed separately:

```sh
zsh course/labs/TodoProject/typecheck-ios.sh
```

This invokes `xcrun swiftc -typecheck -swift-version 6 -sdk ... -target
arm64-apple-ios17.0-simulator -module-cache-path ...` on Core and Native source,
without `TODO_HOST`. Scratch `/private/tmp/todo-ios.dczCrF`. It exited 1 at the
Observation macro subprocess with the same sandbox/plugin error. It did not
produce an app bundle. The ordinary script retains that integration check for a
suitable environment.

A separate integration check on 17 November passed with Swift 6 language mode,
Apple Swift 6.4.2 and the iOS 27.2 Simulator SDK, targeting iOS 17. It added
`-Xfrontend -disable-sandbox` so the compiler's macro helper runs inside the
existing outer workspace sandbox. It included all three Core files and the
native App source, without `TODO_HOST`, and exited 0 without diagnostics.
The script exposes this optional configuration:

```sh
IOS_COURSE_MACRO_HELPER=1 zsh course/labs/TodoProject/typecheck-ios.sh
```

This establishes macro-enabled source typechecking in that configuration. It
does not establish linking, an app bundle, a simulator launch, Observation
invalidation at runtime or an interaction/accessibility result.

## Create an isolated Xcode target

1. Create a unique directory with `mktemp -d /private/tmp/my-todo-native.XXXXXX`.
   In Xcode choose New Project → iOS → App, SwiftUI and Swift. Name TodoScratch,
   fictional organization `example.invalid.learning`, save in that directory.
2. Choose no team for simulator practice. Set deployment to iOS 17+ and Swift
   language version to Swift 6. Device signing is separate and is not required here.
3. Remove generated App and ContentView membership, then copy the three Core files
   and `Native/TodoApp.swift` into the scratch target with target membership enabled.
   Exclude `Checks/TodoChecks.swift`; there must be exactly one `@main` entry.
4. Do not define `TODO_HOST` in this target. Build the actual Observation source for
   an available simulator; record target, SDK, destination and result.
5. Run and observe add, invalid Save, Cancel, valid rename, completion, reorder,
   delete, and relaunch of the same installation. The scratch app uses its own
   Application Support/TodoScratch/tasks.json file. It does not request permissions.

## Format, policy and independent practice

Version one: `{"version":1,"tasks":[{"id":"UUID","name":"Pack bag","done":true}]}`.
Version two: `{"version":2,"items":[{"id":"UUID","title":"Pack bag","isComplete":true}]}`.
Load never writes; v1 conversion preserves IDs, completion and order and normalizes
old names. The native pending-save action writes the accepted current values.
Current titles must already be canonical. Unknown versions and invalid records
block edits/saves, retaining bytes. Repair a copy and explicitly retry loading.

Valid commands update memory before save. On write failure, keep memory dirty and
retry; reload is blocked while dirty. The Bool command result means accepted
domain change, not successful durability. A synchronous, small, single-owner store
is the contract; atomic replacement is not multiwriter coordination or a complete
crash-durability promise. No reset or automatic file-repair UI is supplied.

In a personal copy, implement Incomplete Only with deletion mapped from the exact
visible snapshot and reorder disabled while filtering, or duplicate-task with a
fresh UUID and a declared completion policy. Add a new stale-selection or failed-
save case and run it. Supplied checks and a copied answer do not complete practice.

Native checks still pending: linked target build, app bundle, simulator
journeys, keyboard/focus, VoiceOver, large Dynamic Type, row identity continuity,
relaunch, migration UI, file protection, real storage failures/interruption,
multiple windows and device installation. Observe labels and current completion
value separately from the edit action; identifiers alone do not establish
accessibility. No client app build, release, signing or broad visual verification
occurred.
