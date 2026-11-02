# RuntimeLab

Finite, synthetic host probes for lessons 085–088 and workshop `runtime-scheduling-lab`.
No client imports, accounts, remote dependencies, or production changes.

## Run and inspect

From the shared workspace:

```sh
zsh ios-learning/course/labs/RuntimeLab/run-checks.sh
```

The runner creates a unique `/private/tmp/runtime-lab.XXXXXX` directory. SwiftPM
scratch, package cache, configuration, security and compiler module caches use it;
the synthetic file fixture also lives there. The fixture is removed after its
checks; build evidence remains available for inspection. Remove that one directory
when finished. The script is invoked with zsh and needs no executable-bit change.

Requirements: SwiftPM tools 6.2+, Swift 6 language checking, macOS 15+ and a matching
Apple SDK. `@concurrent` needs the 6.2 compiler feature; `Synchronization.Mutex`
needs supported runtime availability. Apple documents Mutex at iOS 18/macOS 15;
OSAllocatedUnfairLock at iOS 16/macOS 13. A newer compiler does not raise an app's
deployment target automatically. Only the recorded host/toolchain was executed.

`Targets/DisplayDriver.swift` is excluded from the executable target. It requires a
separate iOS 15+ UIKit scratch target and an owner calling `stop()` at its chosen
visibility boundary. The display link retains its target; deinit alone cannot
break that cycle. The synthetic accumulated frame intervals are illustrative
visual steps, not a wall-clock stopwatch or missed-frame measurement.

## What the executable checks

- A due custom-mode Timer remains unhandled in default mode, then fires once in
  its named mode. Both host loop runs have finite bounds.
- Forty serial queue blocks preserve their submission order; a post-barrier read
  observes the prior write on a custom concurrent queue.
- A pre-submission-cancelled work item performs no side effect. This is not a test
  of interrupting an already-running block.
- A user-data-add dispatch source delivers its aggregate value, then runs its
  cancellation handler; its self-capturing event handler is cleared afterward.
- A consumer submitted before its producer still follows its dependency and
  explicitly recovers from a stored failure. A separate pre-cancelled operation
  finishes without running its body.
- NSLock, Mutex and OSAllocatedUnfairLock each retain 2,000 concurrent increments.
  A thrown NSLock-protected closure unlocks, permitting a subsequent snapshot.
- A window of two CPU children returns indexed values `[6, 9, 0, 6]`. A gate makes
  cancellation-before-computation explicit and is always released.
- The OperationQueue-backed synchronous file adapter returns exact fixture bytes
  and propagates a real missing-file error. It does not interrupt an in-flight
  `Data(contentsOf:)`; it checks cancellation before enqueue and after completion.

All blocking waits are finite synchronous CLI probes; no wait depends on the main
queue. No deliberate hang, lock reacquisition or unsafe data race is executed.
The bounded task group limits child admission; its entire input array remains
retained. The file adapter limits executing operations, not unbounded backlog.

## Author verification — 2 November 2026

Host: arm64 macOS 26.6.2 (25G83). Compiler: Apple Swift 6.4
(`swiftlang-6.4.0.34.1`, clang `2100.3.34.1`); macOS SDK 27.0.

Executed from the workspace, with all cache/output paths under the unique author
directory:

```sh
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/runtime-author.agdQKw/module-cache \
CLANG_MODULE_CACHE_PATH=/private/tmp/runtime-author.agdQKw/clang-cache \
RUNTIME_LAB_TMP=/private/tmp/runtime-author.agdQKw \
swift run --package-path ios-learning/course/labs/RuntimeLab \
  --scratch-path /private/tmp/runtime-author.agdQKw/build \
  --cache-path /private/tmp/runtime-author.agdQKw/cache \
  --config-path /private/tmp/runtime-author.agdQKw/config \
  --security-path /private/tmp/runtime-author.agdQKw/security \
  --disable-sandbox --jobs 2 runtime-lab
```

The first compile failed because this SDK imports Core Foundation mode constants
and arguments as `CFRunLoopMode`, rather than the older raw CFString spelling.
The probe now uses `.defaultMode` and `CFRunLoopMode(...)`. The next build/run
exited 0 and printed:

```text
PASS: run-loop mode, queue/group/barrier/source/work item, operations, three locks, bounded CPU values, cancellation, file success/error
```

After the final cancellation-before-admission edit, executed:

```sh
zsh ios-learning/course/labs/RuntimeLab/run-checks.sh
```

Result: exit 0, the same full PASS line, fresh caches/build output at
`/private/tmp/runtime-lab.QVlbOc`. No extra runtime claims are derived from elapsed
build time. The runner itself and the current host source were both exercised.

The missing-path probe was then tightened to request an absent sibling file and
assert the propagated `CocoaError.Code.fileReadNoSuchFile`, rather than accepting
an arbitrary read failure. Repeated the exact `swift run` invocation above with
all `/private/tmp/runtime-author.agdQKw` paths replaced by
`/private/tmp/runtime-lab.QVlbOc`: exit 0, full PASS. This is the final host-source
verification; no additional workload measurements were performed.

The excluded UIKit companion was independently typechecked:

```sh
xcrun swiftc -typecheck -swift-version 6 \
  -target arm64-apple-ios15.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.1.sdk \
  -module-cache-path /private/tmp/runtime-author.agdQKw/ios-module-cache \
  ios-learning/course/labs/RuntimeLab/Targets/DisplayDriver.swift
```

Result: exit 0, no diagnostics. This is SDK compilation/typechecking evidence,
not an app build, Simulator launch, frame observation or physical-device run.

Scoped content validation is reproducible without invoking the global builder:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 ios-learning/course/labs/RuntimeLab/Validation/check-content.py
```

It checks only the three assigned banks, reads existing units for prerequisite
identities and reads the four anchored client lines. It excludes code listings
from prose counts and validates safe HTML, exercises, quizzes, interview schema
and explicit bounded artifact paths. No integration files or learner state change.

Result: exit 0. Prose counts: 085 = 1,639; 086 = 1,744; 087 = 1,701;
088 = 1,636; workshop = 1,252. All eight model answers are within 100–220 words.
All four expected anchor lines and all six explicit artifact files passed.

## Reference audit and boundaries

Official Apple documentation JSON was fetched for RunLoop, common mode, Timer,
CADisplayLink, DispatchQueue, DispatchSource, DispatchWorkItem/cancel, Operation,
OperationQueue, NSLock, Mutex and OSAllocatedUnfairLock. Those pages support the
mode/timing, cancellation, nonrecursive/thread-ownership and availability claims.
Swift's official SE-0461 source verifies `@concurrent` implementation in Swift 6.2.
Official Android Looper, Kotlin shared mutable state and Java 11 ReentrantLock
pages were also fetched for analogy boundaries. Links are in the lesson banks.

Verified read-only anchors after reading `ios-client/AGENTS.md`: referral validation
binding line 78 selects RunLoop.main; Cache.swift line 30 creates a serial queue,
with barrier-flagged setters at line 71; SubprocessRunner.swift line 163 extracts
waiters under a lock and line 169 resumes outside; timeslots-provider extensions
line 54 launches detached work before its reduction and later await. Source
inspection is not client runtime evidence.

Package manifests were also checked: ZDBooking, ZDAvailability, ZDCorePlusSentry
and OvernightKit declare the corresponding source targets. The Overnight anchor
is client-repository host tooling, not evidence of an iOS app runtime lock path.

Intentionally unresolved: Swift 6.2/minimum-OS execution, older SDK spelling
compatibility, Linux portability, Thread Sanitizer, custom asynchronous Operation
state machines, full cancellation-registration races, UIKit gesture/display
interaction, simulator/device execution, contention/fairness/starvation traces,
energy and production rollout. Host values are not performance measurements.
Learner extensions remain exercises; no completion or certification is recorded.
Parent owns global course registration/build/coverage validation.
