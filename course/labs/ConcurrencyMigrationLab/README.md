# ConcurrencyMigrationLab

Bounded companion to lessons 089–092 and workshop `swift6-migration-lab`.
No remote dependencies, client modifications, simulator target, account data or learner completion state.

## Requirements and contracts

- Package tools 6.2+, Swift 6 language mode, macOS 15+ (the manual clock uses `Synchronization.Mutex`). Author checks used Apple Swift 6.4 (`swiftlang-6.4.0.34.1`), arm64 macOS host. The manifest explicitly chooses nonisolated default inference for library and tests.
- The diagnostic matrix requires Swift 6.2+ for default isolation, caller-execution settings, `@concurrent`, and isolated conformances. Older compilers are reported as skipped, not passing. Swift 5 mode is selected explicitly for one warning-staging case.
- Syntax availability, package manifest APIs, SDK availability and deployment requirements are independent. Clock/Duration language APIs date to Swift 5.7; Apple's concrete clocks commonly require iOS 16/macOS 13. Noncopyable structs/enums and ownership modifiers originated in Swift 5.9; later generic/protocol capabilities require newer compilers. This package tests its declared 6.2+ minimum only with the installed 6.4 compiler.
- `DemandChannel` is a zero-buffer rendezvous actor. It holds at most one pending sender and receiver and rejects overlapping blocked operations. Its throwing `send`/`next` contract is deliberately narrower than Apple AsyncAlgorithms. Receipt does not acknowledge downstream processing. Matching wins over later cancellation; finish is idempotent. Ordinary upstream failure needs a separate owner policy.
- Harness observation methods require a corresponding registration event; they do not handle arbitrary production cancellation/closed waits. Do not use them as general lifecycle APIs.
- `ManualClock` moves only forward, ignores tolerance, and resumes removed continuations outside its storage lock. It provides deterministic deadlines, not hardware timer precision. No lock spans suspension.
- `OwnedInt` keeps its pointer private; borrowed reads precede one consuming extraction. `retainedRoundTrip` is synchronous and one-shot. Repeating native callbacks need documented unregister/quiescence and exactly one final release. No dangling-pointer or double-free fixture is executed.

## Run and collect independent evidence

From this directory:

```sh
sh verify-host.sh
python3 verify-diagnostics.py
python3 verify-examples.py
python3 verify-content.py
```

`verify-host.sh` records toolchain and Swift Testing output. It expands to:

```sh
lab_output=$(mktemp -d /private/tmp/concurrency-host-089-XXXXXXXX)
export TMPDIR="$lab_output"
export CLANG_MODULE_CACHE_PATH="$lab_output/clang-cache"
export SWIFT_MODULECACHE_PATH="$lab_output/module-cache"
swift test --disable-sandbox \
  --scratch-path "$lab_output/build" --cache-path "$lab_output/cache" \
  --config-path "$lab_output/config" --security-path "$lab_output/security" \
  -Xswiftc -module-cache-path -Xswiftc "$lab_output/module-cache"
```

SwiftPM's process sandbox is disabled for this scratch package because the workspace environment already restricts writes. All author-created caches and outputs are redirected to a unique temporary root. The first author attempt without manifest cache environment variables failed because SwiftPM attempted an unwritable user cache; the command above resolved that environment issue. Xcode discovery emitted filesystem-event/cache-directory warnings; compilation and tests then completed successfully.

The compiler runner uses `swiftc -parse-as-library -c`, explicit language/settings flags, and a unique `-module-cache-path`. It checks expected exit status plus diagnostic category and writes each stderr and `results.json`. Invalid fixtures are compiled only. `verify-examples.py` compiles complete lesson snippets separately with `swiftc -disable-sandbox`; a protocol declaration is supplied where the worked answer explicitly requires it. The first snippet run failed only at TaskLocal macro expansion because its compiler subprocess attempted an unavailable nested sandbox; using the compiler's documented `-disable-sandbox` flag resolved that environment requirement. `verify-content.py` audits only the assigned unit/banks, excluding preformatted code from teaching-word counts. The parent owns the global reader/build integration.

## Actual author verification — 2 November 2026

- `sh verify-host.sh`: PASS, 13 Swift Testing tests in one suite. Evidence `/private/tmp/concurrency-host-089-mZVx2Uc9/toolchain.txt` and `tests.txt`. XCTest also prints zero tests because this package uses Swift Testing; the subsequent 13-test result is the relevant count.
- Tests cover producer-first/consumer-first demand, canceled sender/receiver replacement, idempotent close and new-send rejection, overlapping blocked-call rejection, cancellation before registration, match before later cancellation, exact virtual deadline and canceled-sleeper removal, task-local inheritance/nested restoration, region transfer, isolated batching, bounded pointer values and a weak retain-balance observation.
- `python3 verify-diagnostics.py`: PASS, 14 settings/contract cases. Evidence `/private/tmp/concurrency-diagnostics-089-yif8f92q/results.json` plus per-case stderr. The first run expected an overlapping-access wording for exclusivity; the compiler correctly rejected the fixture as inout aliasing, and the assertion was updated to that observed category before the passing rerun.
- Matrix: Swift 5 complete warning; Swift 6 mutable-global error; nonisolated/MainActor default pass/error; caller feature off/on error/pass; explicit concurrent error with feature on; transfer valid/invalid; isolated conformance valid/invalid; ownership valid/consumed reuse invalid; inout alias invalid.
- `python3 verify-content.py`: PASS after the final Java 11 analogy correction. Teaching words excluding pre blocks: 089 = 1,566; 090 = 1,534; 091 = 1,657; 092 = 1,710; workshop = 1,477. All eight model answers are 167–178 words by the audit's tokenizer. Also checked section/quiz counts, safe tags/attributes, lower-numbered prerequisites, reference URLs, client anchor lines and explicit lab files.
- `python3 verify-examples.py`: PASS, 14 separately compiled complete lesson/worked-answer snippets. Evidence `/private/tmp/concurrency-examples-089-l6zhzjz7/results.json` plus sources and stderr. The intentionally invalid mutable-global example is covered by the diagnostic matrix instead. These are compilation checks; behavioral runtime evidence comes from the 13 host tests, not from executing every prose snippet.

## Reference audit and remaining verification

Official proposal texts were fetched and inspected for SE-0461, SE-0466, SE-0470, SE-0430, SE-0313, SE-0329, SE-0311, SE-0390 and SE-0377. Apple's Swift AsyncAlgorithms channel guide and Kotlin shared-mutable-state documentation were also inspected. References point to official projects rather than copied chapters. Compiler observations independently check the selected changing syntax/settings. Apple API pages are reference links; this lab does not claim a full native availability matrix was executed.

Client instructions were read first. Read-only anchors were inspected in `PackageTargetSettings.swift`, `OwnedViewModel.swift`, `NavBarButtonStyle.swift`, `Ssl+Extensions.swift`, and `UIDevice+Extensions.swift`. They establish declared configuration and source structure, not runtime behavior, production migration or effective generated-target settings.

Pending: actual Swift 6.2 and other supported compiler runs; native simulator/device builds and lifecycle interaction; representative responsiveness/energy/memory recordings; sanitizer/foreign-ABI validation; a pinned AsyncAlgorithms dependency integration; vendor callback queue, error and quiescence audits; client build/settings resolution; organizational rollout and recovery review. No production measurements, signing, distribution, learner completion or certification is claimed. Existing actor/continuation/stale-result labs are untouched; this lab adds different contracts.
