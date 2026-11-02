# SwiftLanguageLab

A standalone host SwiftPM companion for Across the Stack. Every account, topic,
payload, and file here is synthetic. No remote packages, service calls, app target,
company modules, or credentials are required. The manifest requires Swift tools
6.0 or later and selects Swift 6 language mode. Author verification used Apple
Swift 6.4 on an arm64 macOS host; the minimum toolchain and Linux were not run.
The macOS platform declaration is a deployment floor, not a toolchain version.

## Run with isolated caches

From the course directory, run the following in zsh or bash. Keep this shell open
to reuse the same unique cache directory. It lives in `/private/tmp`; SwiftPM and
compiler caches do not need to write to your home directory. `-j 2` constrains
parallel compiler jobs. Disabling the SwiftPM sandbox is for this local,
dependency-free fixture package in a constrained host environment.

```sh
cd labs/SwiftLanguageLab
swift --version
lab_cache=$(mktemp -d /private/tmp/swift-language-lab-build.XXXXXX)
lab_swift() {
  local lab_command="$1"
  shift
  CLANG_MODULE_CACHE_PATH="$lab_cache/clang" \
  SWIFTPM_MODULECACHE_OVERRIDE="$lab_cache/swift" \
  swift "$lab_command" --disable-sandbox \
    --scratch-path "$lab_cache/build" \
    --cache-path "$lab_cache/package-cache" \
    --config-path "$lab_cache/config" \
    --security-path "$lab_cache/security" \
    -j 2 -Xswiftc -module-cache-path -Xswiftc "$lab_cache/swift" "$@"
}
lab_swift test
lab_swift run swift-workbench all
lab_swift test --filter LanguageTests
lab_swift test --filter LatestLoaderTests
lab_swift test --filter SharedRefreshTests
lab_swift test --filter FoundationTests
```

The executable also accepts `language`, `gates`, and `foundation` individually.
Read the Swift Testing summary after the XCTest compatibility preamble: an
“Executed 0 tests” XCTest line does not mean these `@Test` functions were skipped.
Record your own toolchain, command, exit status, and final summary. A compiler
error is different from a failed `#expect`; a hung event observer usually means
the test did not create or release its prerequisite event. Observers are test
coordination helpers, not general cancellable waits or deadline APIs.

## Instructor contracts and learner changes

`Sources/SwiftLanguageLab/LanguageExamples.swift` exposes collection, value,
reference, and generic examples. `Tests/SwiftLanguageLabTests/LanguageTests.swift`
imports the public library without `@testable`. Copying `ReadingPlan` preserves
independent array values; copying `CounterEnvelope` preserves the shared class
identity. The distinction is observable behavior, not a claim about measured
allocations. `compactMap` deliberately drops invalid numeric text.

To learn from a failure, temporarily expect `[10, 0, -2]` in
`transformationsHaveDifferentFailureContracts`, run the language suite, and read
the diagnostic comparing the actual `[10, -2]` result. Then restore the
expectation. This is a deliberately wrong expectation, not a feature request.
For a real exercise, add a duplicate-topic reading and independently calculate
the new total. Change both the fixture and its intended expected value, run the
focused suite, and explain why order and membership assertions both matter.

`CompletionGate` is single-use: wait for start, then call `succeed` or `fail` once.
Cooperative gates resume with `CancellationError`; ignoring gates require an
explicit release even after cancellation. Resolution signals continuation
delivery, not necessarily completion of the task consuming it. Join a
`LoadHandle` or await a caller task before inspecting terminal state.

`LatestLoader` retains owner tasks. Freshness includes account, account epoch,
and request generation. Both success and error share the same commit guard.
Changing account invalidates visible state even for A to B to A. Cancelled work
continues consuming capacity until it exits; capacity rejection leaves state
unchanged. This model records visible phases, not session 020's durable or
memory-cache return/error contract. There is no TTL, cache hit, retry, or network.

`SharedRefresh` gives each caller its own continuation. Cancelling one waiter
does not cancel another; cancelling the last requests underlying cancellation.
An abandoned ignoring flight remains counted until completion. A joining
caller's gate is unused. Actor handling order decides a simultaneous
cancellation/completion race: completion can win and deliver a result. The
tests establish an ordered cancellation by awaiting that caller's termination
before releasing the surviving flight. One refresher instance represents one
scope; it has no account-switch API or authentication policy.

`FoundationFixtures` fixes locale, calendar, timezone, Unicode, and file inputs.
Each file test creates its own UUID directory and defers cleanup of only that
directory. Missing, corrupt, unsupported-version, unreadable, and write-failed
outcomes are distinct. A throwing injected writer preserves the previous
snapshot; a directory at `snapshot.json` exercises a real filesystem failure
without depending on chmod, root privileges, or a full disk. Atomic replacement
does not coordinate multiple logical writers. NumberFormatter fixtures do not
establish strict full-input validation or a money arithmetic policy.

## Evidence boundary

The supplied tests verify instructor examples. They do not complete learner
exercises, update course progress, certify expertise, or demonstrate app/UI,
device file protection, backup, Instruments, or real authentication behavior.
The three workshops in `content/practice-host.json` explain the intended
learning changes and acceptance evidence. Keep your observations separate from
the worked answers and from any future native/device verification.
