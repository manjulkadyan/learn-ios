# UI Runtime Lab

A standalone Apple-SDK-only companion for lessons 093–096 and workshop **ui-runtime-lab**. The app has four surfaces: KVO/input routing, Core Animation interruption, custom baseline/RTL layout and focus, and scene routes/bounded execution. Fixtures use synthetic strings and geometry. There are no remote packages, network calls, credentials, client dependencies, signing team, durable writes, or automatic learner completion.

The application target is **UIRuntimeLab**, with shared scheme **UIRuntimeLab**, bundle ID **org.example.UIRuntimeLab**, iPhone/iPad destinations, and iOS **17.0** deployment target. It uses **Swift 5 language mode**. Author verification used **Xcode 27.1 (27A9275)**, **Apple Swift 6.4**, and **iOS Simulator SDK 27.1**. These are installed toolchain facts, not assertions about the latest available releases or a Swift 6 migration.

## Build this target

Open `UIRuntimeLab.xcodeproj` in Xcode and select the shared scheme and an installed iPhone/iPad Simulator. The project contains its own @main App, explicit Info.plist, scene manifest, URL scheme, source membership, and packaging settings. Signing is disabled; no signed-device installation or distribution is provided.

From this lab directory:

```sh
xcodebuild -project UIRuntimeLab.xcodeproj -scheme UIRuntimeLab -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/UIRuntimeLab-093-096-20261102-derived CODE_SIGNING_ALLOWED=NO build
```

The ordinary command failed in this authoring sandbox because the compiler's macro helper could not initialize a nested sandbox. With this installed SDK, SwiftUI @State also invokes that helper. The following command lets it run within the existing outer workspace sandbox; no project or production settings are altered:

```sh
xcodebuild -project UIRuntimeLab.xcodeproj -scheme UIRuntimeLab -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/UIRuntimeLab-093-096-20261102-derived CODE_SIGNING_ALLOWED=NO 'OTHER_SWIFT_FLAGS=-Xfrontend -disable-sandbox' build
```

All outputs use the unique /private/tmp/UIRuntimeLab-093-096-20261102 prefix. The generic destination creates a simulator app without booting or running a simulator. It does not validate interaction, installed URL delivery, multiwindow restoration, expiration, or frame performance. This lab is independent of the shared reader; the parent author owns manifest/path/coverage/mock-round integration and global checks.

## Execute the shared-source host checks

```sh
xcrun swiftc -swift-version 5 -warnings-as-errors -module-cache-path /private/tmp/UIRuntimeLab-093-096-20261102-host-cache Shared/FlowMath.swift Shared/LabRoute.swift Validation/HostChecks.swift -o /private/tmp/UIRuntimeLab-093-096-20261102-host-checks
/private/tmp/UIRuntimeLab-093-096-20261102-host-checks
xcrun swiftc -swift-version 5 -warnings-as-errors -module-cache-path /private/tmp/UIRuntimeLab-093-096-20261102-kvo-cache Shared/CounterRecord.swift Validation/KVOChecks.swift -o /private/tmp/UIRuntimeLab-093-096-20261102-kvo-checks
/private/tmp/UIRuntimeLab-093-096-20261102-kvo-checks
PYTHONDONTWRITEBYTECODE=1 python3 Validation/check-content.py
plutil -lint App/Info.plist UIRuntimeLab.xcodeproj/project.pbxproj
xmllint --noout UIRuntimeLab.xcodeproj/xcshareddata/xcschemes/UIRuntimeLab.xcscheme
```

Geometry checks compile the app's exact FlowMath source and assert independent expected logical origins/heights for mixed baselines, forced break, wrapping, empty, oversize, zero-width, and changed metric behavior, grouped into seven scenarios. SwiftUI owns RTL placement reflection; host checks do not exercise it. Route checks use the app's exact parser/reducer and assert two accepted URLs, cold external-intent/restoration precedence, recognized/unknown restoration, warm replacement, and nine rejected URL forms. Invalid cold intent yields root; invalid warm intent preserves current selection. They do not test OS delivery.

KVO checks compile the app's exact CounterRecord source and assert synchronous .initial/.new values and idempotent invalidation on macOS. Objective-C interoperability is required; this is not Linux Swift or UIKit runtime evidence. CoreGraphics is explicitly imported for host geometry types/conformances. Content validation reads only the assigned banks, existing 001–084 prerequisite identities, client anchor lines, and bounded lab files. It checks depth, safe balanced HTML, quiz answers, references, interview rubric/followups/pitfalls, and existing paths without writing shared course output.

## Pending interaction notebook

Run these installation/link commands only with a functioning booted simulator. They were **not executed successfully** during authoring:

```sh
xcrun simctl install booted /private/tmp/UIRuntimeLab-093-096-20261102-derived/Build/Products/Debug-iphonesimulator/UIRuntimeLab.app
xcrun simctl launch booted org.example.UIRuntimeLab
xcrun simctl openurl booted 'uiruntime://item/alpha'
xcrun simctl terminate booted org.example.UIRuntimeLab
xcrun simctl openurl booted 'uiruntime://item/beta'
```

Record a destination, fixture, input sequence, observed result, and remaining uncertainty for each row. Nothing in this table is a pre-completed learner result.

| Surface | Source behavior | Runtime acceptance still pending |
| --- | --- | --- |
| KVO registration | Strong model/token ownership, weak callback, initial delivery, visibility-scoped invalidation/re-registration | Increment, leave/return, exactly one active registration, replace-model extension |
| Input routing | Empty overlay passes touches, Reset uses nil-target responder resolution | Underlying button activation, controller action resolution, keyboard/VoiceOver alternatives |
| Gesture dependency | Single requires double to fail; pad is diagnostic | Single adds one, successful double adds ten only, cancellation/competition observations |
| Core Animation | Destination model written without actions; named animation samples presentation first | Rapid retarget, nil presentation, freeze versus finish extension, resize clamp, departure |
| Reduced Motion | Endpoint updates without adding travel | Same final meaning and reachable controls with setting enabled |
| Custom Layout | Current measurement signature, first-baseline row math, forced break, logical positions with framework-owned RTL reflection | Native RTL placement, actual font/localization/Dynamic Type dimensions, nonzero parent origin, overflow |
| Scroll | Vertical form plus native horizontal choices, no blanket drag | Axis-specific and diagonal gestures; no trapped page scrolling |
| Editing/assistive focus | Distinct Field cases, submit/Previous/Next/Done, separate error focus | Software keyboard, hardware Tab/Shift-Tab, VoiceOver announcement/order/activation |
| Lifecycle | One delegate adaptor, WindowGroup roots, scene-local phase/route | Initial/changed phases, temporary inactive transition, supported two-window independence |
| Routes/restoration | Strict custom scheme and typed scene path, no later onAppear override | Installed cold/warm delivery, actual SceneStorage restore, versioned-envelope extension |
| Bounded checkpoint | Background identifier, invalid handling, generation-guarded completion/expiration, cancel/replace retirement | Actual background transition/expiration, scene-root teardown, no stale completion |

## Mechanism and availability boundaries

- KVO uses NSObject/@objc dynamic and Objective-C runtime behavior; @Published/@Observable are not interchangeable registrations. The app confines all count writers to UIKit's main thread, and its callback asserts that contract. Observation itself supplies no actor/scheduler guarantee.
- A hit point belongs to the receiver's local coordinate space. Clear pixels are not default touch transparency. The lab returns nil for only its own empty wrapper hit; it does not infer stable private SwiftUI sublayer topology.
- The model layer stores lasting destinations. Presentation is optional, read-only, and a close approximation of visible animation, not a synchronized display capture. CATransaction suppresses implicit actions without forbidding explicit animations. Layer work is decorative; it has no responder/accessibility control semantics.
- Layout and layout-value keys require iOS 16; the entire target requires iOS 17. AccessibilityFocusState is iOS 15+, and the initial/two-value onChange use is iOS 17+. Arrangement caching does not eliminate text measurement. Internal first-baseline rows do not implement explicit container first/last alignment guides.
- FlowMath produces unmirrored logical coordinates. SwiftUI Layout automatically flips subview x placement in RTL; neither a numeric anchor nor the helper opts out. The fixture changes the container environment. Oversize children retain their logical origin and overflow the width budget. Same-axis nested scroll consumption/fling coordination and a public UIKit bridge are intentionally absent.
- App/WindowGroup/SceneStorage/UIApplicationDelegateAdaptor/scenePhase are iOS 14+ contracts. The view-level phase is scene-specific; App-level phase is aggregate. Controller/view appearance is not process launch/termination.
- CheckpointRunner sleeps synthetically for two seconds and writes no data. The task is cooperatively cancelled; a generation rejects old completion/expiration. Its execution extension is finite, can be unavailable, and must be ended. No fixed background duration or forced expiration is promised.

## Author verification — 2 November 2026

Actual commands above were run in this lab directory with caches/artifacts under the unique /private/tmp prefix.

| Check | Actual result |
| --- | --- |
| Ordinary xcodebuild | Exit **65**, nested macro-helper sandbox failure; log /private/tmp/UIRuntimeLab-093-096-20261102-build.log |
| Macro-helper build | Exit **0**, **BUILD SUCCEEDED**; final post-QA RTL-corrected source log /private/tmp/UIRuntimeLab-093-096-20261102-build-rtl-corrected.log |
| Geometry/routes compile and execution | Exit **0** with warnings as errors; `PASS: 7 logical geometry scenarios; restoration/cold/warm policy and 9 rejected URL fixtures; native RTL unobserved` |
| KVO compile and execution | Exit **0** with warnings as errors; `PASS: synchronous initial/new KVO values and idempotent invalidation on macOS` |
| Scoped content validator | Exit **0**; four lessons exceed 1,300 prose words excluding code, eight answers meet 100–220 words, workshop exceeds 900 words, all linked files and client lines exist |
| Plist/project lint | Exit **0**, both files OK |
| Shared scheme XML parse | Exit **0**, well-formed |
| `xcrun simctl list devices available` | Exit **1**, CoreSimulatorService invalid/refused and device-set initialization failure; log /private/tmp/UIRuntimeLab-093-096-20261102-simulator.log |

The simulator product was compiled and linked for arm64/x86_64; `file` and `xcrun lipo -archs` on /private/tmp/UIRuntimeLab-093-096-20261102-derived/Build/Products/Debug-iphonesimulator/UIRuntimeLab.app/UIRuntimeLab confirmed both architectures (exit 0). No simulator install/launch/interaction or physical-device run occurred. Xcode emits a nonblocking AppIntents extraction warning because this app has no AppIntents dependency; no intents are claimed. No frame trace, GPU/energy/memory measurement, signed artifact, persistence guarantee, or production migration was obtained. Initial host compilation revealed the need for an explicit CoreGraphics import; the final shared source includes it and passes.

The workspace root is not a Git repository, so attempted read-only Git status/diff checks were unavailable and are not claimed as passing. Authored scope is tracked by the apply_patch paths, explicit workshop inventory, and scoped validator.

### Independent QA correction: automatic RTL placement

QA identified a P2 double-reflection bug: the first helper manually mirrored x even though SwiftUI Layout already flips subview placement for RTL. Read the official [LayoutSubviews.layoutDirection documentation](https://developer.apple.com/documentation/swiftui/layoutsubviews/layoutdirection), including its DocC JSON fetched to /private/tmp/ui-runtime-ref-layoutdirection-20261102.json. A numeric UnitPoint anchor does not disable the framework's behavior.

Removed the helper's rtl parameter, BaselineFlow's manual direction input/cache field, and the physical-x reflection. BaselineFlow now places unchanged logical positions; the fixture supplies direction through the container environment. Replaced the invalid host physical-mirror assertions with a same-width forced-row-break scenario. Logical x = 0 and 48, baseline offsets, width wrapping, overflow, and route behavior pass on the final shared source. All lesson/objective/quiz/worked-answer/interview/workshop explanations were corrected to separate logical geometry from SwiftUI's placement responsibility.

Re-ran the documented host compilation with warnings as errors and executable: exit 0. Rebuilt the native target with the documented macro-helper command: exit 0, BUILD SUCCEEDED, log /private/tmp/UIRuntimeLab-093-096-20261102-build-rtl-corrected.log. Scoped content validation was re-run after the text corrections. **Native RTL remains unobserved** because no functioning simulator/device interaction was obtained. The old passing manual-mirror arithmetic was not valid evidence of SwiftUI RTL correctness.

## Authored file inventory

The three banks are content/unit-15.json, content/interview-ui-runtime.json, and content/practice-ui-runtime.json. The 15 companion files, all under labs/UIRuntimeLab/, are:

| Directory | Files |
| --- | --- |
| Root | README.md |
| App | Info.plist, DispatchLab.swift, LayerLab.swift, BaselineFlow.swift, LayoutPanel.swift, RuntimeApp.swift |
| Shared | CounterRecord.swift, FlowMath.swift, LabRoute.swift |
| Validation | HostChecks.swift, KVOChecks.swift, check-content.py |
| UIRuntimeLab.xcodeproj | project.pbxproj, xcshareddata/xcschemes/UIRuntimeLab.xcscheme |

## Reference and existing-content audit

Read CONTENT_SPEC.md completely, including the 2 November expansion, and read ios-client/AGENTS.md before client source. Existing lessons 031/032/034 cover layout proposals, basic gestures/focus/animation, and scene ownership. Their stated baseline/RTL/key/cache and specialist interaction boundaries motivated the new implementation rather than another SwiftUI basics tutorial. Existing numbered lessons and labs are unchanged.

Official Apple DocC JSON and archived guides were fetched with `curl -L --fail` and read for Swift KVO, UIView hit testing, recognizer failure, Core Animation trees/explicit animation/transactions/presentation, Layout/cache/keys/assistive focus, scene connection, phase/adaptor, termination, and background execution. Installed SDK compilation independently checked API use. Java 11 dynamic lookup, Android interception/hardware drawing/current nested-scroll phases, Kotlin cooperative cancellation, and the Swift concurrency guide were also fetched and inspected. The old Kotlin and Compose URLs redirected to new documentation paths; lesson references use the inspected current destinations. Reference caches use /private/tmp/ui-runtime-ref-*-20261102.* and are not embedded as external runtime dependencies.

Verified source anchors are token/inner-token replacement in SettingsRedesignView, the specific PassthroughHostingController hit heuristic, signature layer action suppression, booking shimmer animation, FlowLayout measurement/placement, App Clip session connection and activity routing, and the SwiftUI Mezzanine demo WindowGroup/onOpenURL. These are source observations, not client execution or claims of implemented migrations.

Read only the first 236 lines of /Users/manjul.kadyan/Downloads/iOS and App Development.md. Lesson 096 corrects its universal callback-sequence, termination, new-session, and blanket five-second implications. Apple's documented five-second callback budget is retained with its proper scope. The original download, including its embedded base64 tail, was not modified.

## Intentionally remaining

Runtime/assistive input, multiwindow/restoration and actual expiration evidence remain pending. Durable drafts/account epochs/authentication, protected-data recovery, universal links, background scheduling, a UIKit scene-delegate implementation in this SwiftUI app, explicit outer baseline guides, same-axis fling transfer, rich-text/TextKit work, and real render/performance traces are further practice. TextKit belongs to the separate specialist author. Learner extensions and acceptance notebooks remain unfinished by design.

Only content/unit-15.json, content/interview-ui-runtime.json, content/practice-ui-runtime.json, and labs/UIRuntimeLab/ were authored here. No client writes, existing-lab edits, commits, publishing, shared integration changes, or learner-state mutations were performed.
