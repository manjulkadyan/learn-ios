# ProfilingLab

Standalone instrumented UIKit target plus Apple-host correctness checks and a raw-record validator. No company dependencies, network, client edits, generated production evidence, or learner completion. Lessons 101–104 and workshop `profiling-evidence-lab` explain the investigation.

## Requirements and controls

- Native project: Xcode with iOS SDK, Swift language mode **5**, deployment minimum **iOS 17**, UIKit. Profile uses **Release / -O / dwarf-with-dsym**. `OSSignposter` is available from iOS 15 / macOS 12.
- Host: Apple Swift compiler, macOS 12+ with Foundation/CoreGraphics/ImageIO/os. Host compilation below uses Swift mode 5; it does not run the iOS UI.
- Records: Node supporting ES modules; no package installation.
- Signing is disabled. Configure signing only in a learner-owned scratch copy for authorized physical-device execution. An unsigned generic simulator build is not interaction evidence.

Prepare creates a synthetic opaque 2048×2048 PNG. The workload creates 6,000 strings with 1,500 first-occurrence rows. `Linear/Indexed`, `Full/Thumb`, `Repeat caption/Cached caption`, and `1/4 workers` are independent axes: change **one** for attribution. Four accepted attempts bound the backlog; a second batch is refused while pending is nonzero.

`Work` measures **worker-entry-to-model-ready**: row construction, projection, decode, file encode/write/read/verification, and image wrapping. It excludes queue wait, main delivery, layout and presentation. `Projection`, `Decode`, `Disk` and baseline `Caption` are nested or narrower intervals. `ModelApplied` is an event before reload; `ShellConstruction` is delegate window/root setup, excluding pre-delegate process preparation and later presentation.

`ProfileOperation.requestCancellation()` sets a lock-protected cooperative flag. It deliberately does **not** call `Operation.cancel()`, which can skip queued main actions and lose terminal accounting. Synchronous decoding/file calls are checked before/after, not forcibly interrupted. Main delivery checks again. A worker success may therefore be followed by suppressed UI publication; worker records do not certify screen outcomes.

## Reproduce the available checks

Run from `/Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course`. All caches, compiled products and generated fixtures go under a new temporary directory. `PROFILE_TMP` is task-specific and does not replace a system environment variable.

```sh
PROFILE_TMP=$(mktemp -d /private/tmp/profiling-check-XXXXXXXX)
swiftc -swift-version 5 -O \
  -module-cache-path "$PROFILE_TMP/swift-cache" \
  labs/ProfilingLab/Core/Workload.swift labs/ProfilingLab/Host/Checks.swift \
  -o "$PROFILE_TMP/host-checks"
"$PROFILE_TMP/host-checks" "$PROFILE_TMP/host-fixtures"
node labs/ProfilingLab/Records/checks.mjs
node labs/ProfilingLab/Records/make-synthetic.mjs > "$PROFILE_TMP/synthetic.json"
node labs/ProfilingLab/Records/validate.mjs "$PROFILE_TMP/synthetic.json" > "$PROFILE_TMP/synthetic-report.json"
python3 labs/ProfilingLab/Validation/check-content.py
xcodebuild -project labs/ProfilingLab/ProfilingLab.xcodeproj \
  -scheme ProfilingLab -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$PROFILE_TMP/derived" \
  -clonedSourcePackagesDirPath "$PROFILE_TMP/packages" \
  CODE_SIGNING_ALLOWED=NO CLANG_MODULE_CACHE_PATH="$PROFILE_TMP/clang-cache" \
  build > "$PROFILE_TMP/native-build.log" 2>&1
xcrun dwarfdump --uuid "$PROFILE_TMP/derived/Build/Products/Release-iphonesimulator/ProfilingLab.app/ProfilingLab"
xcrun dwarfdump --uuid "$PROFILE_TMP/derived/Build/Products/Release-iphonesimulator/ProfilingLab.app.dSYM"
```

The content checker reads only this unit/banks, existing lesson IDs and listed client anchors. It does not run or modify the global builder/reader, manifests, paths, progress or other labs.

## Actual author verification — 2 November 2026

Author working directory was the workspace root; commands above used the equivalent `ios-learning/course/` prefix. Unique output root: `/private/tmp/profiling-author-ZX47jMob`.

- `xcodebuild -version`: **Xcode 27.1, 27A9275**. `swift --version`: **Apple Swift 6.4**, host target arm64-apple-macosx26.0. Selected language mode remains 5. `node --version`: **v26.12.1**. `xcrun --sdk iphonesimulator --show-sdk-version`: **27.1**.
- `swiftc -swift-version 5 -O -module-cache-path /private/tmp/profiling-author-ZX47jMob/swift-cache ios-learning/course/labs/ProfilingLab/Core/Workload.swift ios-learning/course/labs/ProfilingLab/Host/Checks.swift -o /private/tmp/profiling-author-ZX47jMob/host-checks`: **exit 0**. Compiler emitted a weak-local-variable-never-mutated suggestion for `witness`; it remains `weak var` for the declared Swift 5 contract.
- `/private/tmp/profiling-author-ZX47jMob/host-checks /private/tmp/profiling-author-ZX47jMob/host-fixtures-final`: **exit 0**. PASS for complete ordered parity/empty input, controlled cancellation, full/thumbnail pixel dimensions, corrupt-image rejection, file round-trip/cleanup, callback cycle/release, pressure branches, and four queued cooperative cancellation callbacks draining. No timings were exported by this checker.
- `node ios-learning/course/labs/ProfilingLab/Records/checks.mjs`: **exit 0**. PASS for provenance, cohorts, order, median/p95, malformed/missing durations, correctness failure, mixed revisions, pressure drift, preparation failure, cancellation and timeout denominators.
- `python3 ios-learning/course/labs/ProfilingLab/Validation/check-content.py`: **exit 0**. PASS for this author's schema, safe/balanced HTML, word floors, lower known prerequisites, quizzes, eight interview identities/answers/rubrics, inspected repository line anchors and bounded companion text paths. Builder-compatible teaching counts: **101=1,568; 102=1,690; 103=1,676; 104=1,620; workshop=1,422**. No global builder or reader check was run.
- `node ios-learning/course/labs/ProfilingLab/Records/make-synthetic.mjs > /private/tmp/profiling-author-ZX47jMob/synthetic.json`, then `node ios-learning/course/labs/ProfilingLab/Records/validate.mjs /private/tmp/profiling-author-ZX47jMob/synthetic.json > /private/tmp/profiling-author-ZX47jMob/synthetic-report.json`: **exit 0**. `synthetic: true`, `review_required`; each variant n=20. Fictional baseline median/p95 **89.5/98**, candidate **79.5/88**. Arithmetic fixture values, never device observations.
- `node ios-learning/course/labs/ProfilingLab/Records/validate.mjs /private/tmp/profiling-author-ZX47jMob/incorrect-synthetic.json > /private/tmp/profiling-author-ZX47jMob/incorrect-report.json`: expected **exit 2 / correctness_failure** after changing one independently retained fictional record to `outcome: incorrect, correct: false`. Confirms the CLI rejection path as well as unit-level behavior.
- `xcodebuild -project ios-learning/course/labs/ProfilingLab/ProfilingLab.xcodeproj -scheme ProfilingLab -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/profiling-author-ZX47jMob/derived -clonedSourcePackagesDirPath /private/tmp/profiling-author-ZX47jMob/packages CODE_SIGNING_ALLOWED=NO CLANG_MODULE_CACHE_PATH=/private/tmp/profiling-author-ZX47jMob/clang-cache build`: **exit 0 / BUILD SUCCEEDED** for the final shared-core/operation layout. Output retained in `native-build-final.log`. Simulator artifact contains x86_64 and arm64. Native compiler had no source diagnostics; tooling emitted an App Intents metadata-extraction warning because this target has no AppIntents dependency.
- `xcrun dwarfdump --uuid` on final simulator executable and `.app.dSYM`: UUIDs match for **x86_64 FA9694B0-33F8-305D-94FF-49770B9C803C** and **arm64 ABB14785-1EB3-37C7-8A4C-784972CEE515**. This is symbol-artifact evidence, not captured stacks.

The build log reported unavailable/unresponsive CoreSimulator services and no discovered simulator runtimes. No simulator was launched or interacted with. Those messages did not prevent the generic SDK build. No phone signing, install, Instruments recording, UI automation, native export interaction, device launch/hitch/memory/power observation, production benchmark or rollout was obtained.

## Learner recording and intervention checklist

1. Open the project, inspect Profile=Release and effective build settings, choose an available destination. Retain revision and matching binary/dSYM. Use a separately owned signed copy for hardware.
2. For projection choose Linear, Thumb, Cached caption, one worker. Prepare before workload recording. Product > Profile; start Blank plus `os_signposts` and Time Profiler (or installed equivalent). Record one batch, wait for zero pending, stop and save `.trace` outside this source subtree.
3. Expand subsystem `org.example.ProfilingLab`, category `Workload`. Select one Work and Projection child. Record timeline coordinates, thread attribution and inclusive/self stacks. Indexed must preserve the entire ordered expected array. Use a matched minimally instrumented confirmation batch; avoid claiming a saving from complexity alone.
4. For rendering, populate before the fixed gesture. Freeze image/projection/worker controls, compare caption modes with a common installed responsiveness/hitch track. Align missed-deadline evidence with main-thread Caption or competing render/decode stacks. Candidate has no Caption interval; absence is not zero frame time.
5. For memory, freeze other controls, compare Full/Thumb. Mark Allocations generations before/after batch, then after Clear displayed payload. Four images are deliberately retained by the batch array. Separately create the probe cycle, Release owner, and inspect Memory Graph: probe → stored closure → capture context → probe; probe → Data. Break callback cycle and repeat. A stopped graph is not transient-peak evidence.
6. For launch, record from process creation and keep ShellConstruction separate from presented frame and first usable interaction. Record process survival and prepared-file state; force-quit does not flush every OS cache.
7. For scheduling compare actual overlap, batch latency, worker latency, interaction and transient peak. Thermal endpoint fields cannot exclude intermediate drift. Low Power Mode is an admission snapshot; this minimal app does not continuously observe it. Thermal capacity reduction affects later admission, not executing operations. Required work and the host-only speculative seam have different policy contracts.
8. For energy use supported physical-device tools and retain actual units, observation window and display/charging/background conditions. This workload has no radio traffic. Source, fake pressure and a simulator stopwatch cannot provide battery savings.

## Raw-record provenance and decisions

Export after the batch drains using Export raw JSON. Keep the original. Create an annotated copy with actual source `device`/`simulator`, device or host identity, OS build, revision and effective Debug/Release configuration. `native-unannotated` is intentionally rejected. Do not silently rename it synthetic. `cachePolicy` accurately says the file was prepared and OS caches uncontrolled; it is not cold-state evidence.

The synthetic generator is explicitly fictional with blank device/OS fields. Ordinals represent admission; array order represents completion append order. The validator retains failed attempts, checks one revision per variant, separates cohorts by conditions, and uses conventional median plus nearest-rank p95. Error/timeout/incorrect rate uses all attempts; inspect separate cancellation/preparation counts too. A cancelled elapsed value is not successful latency.

`invalid_capture`, `correctness_failure`, `insufficient_samples`, and `review_required` have distinct next actions. `review_required` is descriptive readiness, never release approval. Twenty successes per variant is only a lab minimum, not statistical confidence. Worker-count changes intentionally split cohorts; a scheduling comparison needs its own predeclared matching protocol. Do not average cohort p95 or sum phase p95. Preserve originals and declared invalid-run rules; never retry until a lucky pass.

## References and audit connections

Official Apple documentation was fetched and read on 2 November through its public documentation JSON: OSSignposter/Recording Performance Data, ImageIO thumbnail creation and immediate caching, ProcessInfo thermalState, OperationQueue concurrency limit, launch, memory information and DispatchTime. Kotlin's official cancellation article redirects to `https://kotlinlang.org/docs/coroutines-cancellation.html`; the current article was read for cooperative cancellation. Java 11's official ExecutorService page was read for executor shutdown/cancellation boundaries. Reference URLs live in the lesson/workshop banks, not external copied chapters.

Swift's official Automatic Reference Counting chapter was also read through its public documentation JSON, verifying weak-observer release and class-instance/stored-closure strong cycles. The callback fixture is original lab code, not copied documentation.

Client instructions were read first. Inspected anchors: `Performance.swift:13`, `AppDelegate.swift:264`, `RMImageCache.m:105`, `URLSessionDispatcher.swift:74`, and `StreamingPerformanceBenchmarkTests.swift:40` (wait result at 50). Additional read-only search-list context was inspected. These establish active source connections only; no client profile, migration, defect or measured saving is claimed.

Pending specialist/learner evidence: native layout and Dynamic Type/VoiceOver interaction, actual export/share interaction, image appearance/orientation with non-square and wide-gamut fixtures, first presented/usable frame, gesture hitches, Allocations/Memory Graph captures, representative device peak, sustained thermal and energy observations, complete pressure history, uncertainty analysis, production integration and budget ownership. The supplied square fixture does not exhaust image-quality requirements. Parent owns global integration; no global course build was run by this author.
