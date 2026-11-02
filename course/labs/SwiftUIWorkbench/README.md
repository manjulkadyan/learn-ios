# SwiftUI Workbench

A standalone native practice companion for Across the Stack. Only Apple SDKs and synthetic fixtures are used. The app has four tabs: SwiftUI gallery, live UIKit interoperability, two independent persistence editors, and explicit platform adapters. A small WidgetKit/App Intents extension is built and embedded. Both targets require iOS 17; the project uses Swift 5 language mode with a macro-capable Swift compiler. It has no remote packages, company capabilities, team, secrets, provider configuration, or automatic network calls.

## Open and build

Open this actual project in Xcode:

```sh
open /Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/SwiftUIWorkbench/SwiftUIWorkbench.xcodeproj
```

Choose the shared **SwiftUIWorkbench** scheme and an installed iPhone or iPad Simulator. This is a complete application target, not a Swift package or a snippet to paste into the company client. Signing is disabled for this practice project. Do not choose a physical device expecting this unsigned product to install; signed-device configuration and distribution are outside this lab.

The ordinary simulator command, from this lab directory, is:

```sh
cd /Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/SwiftUIWorkbench
xcodebuild -project SwiftUIWorkbench.xcodeproj -scheme SwiftUIWorkbench -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/SwiftUIWorkbench-DerivedData CODE_SIGNING_ALLOWED=NO build
```

In the authoring sandbox, Swift's nested macro helper sandbox could not initialize. The first ordinary build exited 65 with `sandbox-exec: sandbox_apply: Operation not permitted`, followed by missing macro implementation diagnostics. The following command permits the compiler's macro helper to run inside the existing outer workspace sandbox. It does not change the checked-in project's normal settings:

```sh
xcodebuild -project SwiftUIWorkbench.xcodeproj -scheme SwiftUIWorkbench -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/SwiftUIWorkbench-DerivedData CODE_SIGNING_ALLOWED=NO 'OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -disable-sandbox' build
```

Host checks use the **same parser source** compiled into the app, not an alternative implementation:

```sh
xcrun swiftc -module-cache-path /private/tmp/SwiftUIWorkbench-HostCache App/WorkbenchLink.swift Validation/RouteChecks.swift -o /private/tmp/SwiftUIWorkbench-RouteChecks
/private/tmp/SwiftUIWorkbench-RouteChecks
node Validation/check-content.mjs
plutil -lint App/Info.plist Widget/Info.plist SwiftUIWorkbench.xcodeproj/project.pbxproj
```

The content check reads only this author's workshop JSON and linked files. It validates safe HTML, depth, exercise/quiz structure, official references, explicit existing file paths, and links covering 071–084. It recognizes those session IDs from CONTENT_SPEC.md; it does not claim that another author's new units have already been integrated into the shared manifest or offline reader. Shared integration files are outside this assignment.

## Installation and link checkpoints

These commands require a functioning, already booted Simulator and were **not executed successfully during authoring**:

```sh
xcrun simctl install booted /private/tmp/SwiftUIWorkbench-DerivedData/Build/Products/Debug-iphonesimulator/SwiftUIWorkbench.app
xcrun simctl launch booted org.example.SwiftUIWorkbench
xcrun simctl openurl booted 'workbench://gallery/item/alpha'
xcrun simctl terminate booted org.example.SwiftUIWorkbench
xcrun simctl openurl booted 'workbench://gallery/item/beta'
```

Warm checkpoint: Alpha opens in Gallery when the app is running. Cold checkpoint: Beta opens after termination. The URL scheme is registered in App/Info.plist, and the app-owned router accepts incoming URLs through onOpenURL. Only literal alpha/beta/gamma routes are accepted; query, fragment, user info, port, encoded aliases, extra segments, and unknown IDs are rejected. No universal links, associated domains, App Clip, auth gate, restoration, or multi-window routing is implemented.

## What to try

| Surface | Actual source behavior | Learner checkpoint |
| --- | --- | --- |
| Gallery | Controls, app-owned Observation draft, bindings, custom environment key, ViewModifier, ButtonStyle, named previews | Edit the same draft in Gallery and its sheet; inspect memory-only preview injection |
| Lists and tasks | Form/search/refresh, stable fixture IDs, local cancellable task(id:), onChange | Change task inputs quickly; newest input is the only accepted result |
| Navigation | Tabs, typed stack, split view, sheet, cover, popover, alert, confirmation | Exercise back and cancellation; compare compact and wide destinations |
| Accessibility | Semantic controls, percent slider value, combined descriptive card, flexible large-text fallback | Record VoiceOver traversal and large-text clipping/reachability on actual destinations |
| UIKit | UITableViewDiffableDataSource updates/reconfiguration, refreshed callbacks, dynamic UITextView representable | Rename/reverse/select by ID; compose text without external overwrites |
| Core Data | Programmatic model/SQLite stack, main-context CRUD, background-context insertion/save, automatic merge plus explicit snapshot fetch | Insert/rename/delete, background insert, then relaunch; existing-object merge conflicts need additional tests |
| SwiftData | @Model, container, context, @Query, explicit CRUD saves and rollback | CRUD/relaunch independently; records are not shared with Core Data |
| Notifications | Explicit authorization, five-second local request, retained delegate, same route parser | Test foreground, Home screen, warm/cold response, denied settings; no APNs |
| WebKit | Local HTML only, ephemeral store, narrow main-frame/nonce bridge, cookie completions, script/handler removal | Install, acknowledge, replace document, set/clear cookie, remove web view |
| Authentication | Retained ASWebAuthenticationSession adapter, explicit scene anchor, attempt guards, cancel cleanup | Review only: UI never starts a provider; OAuth state/PKCE/provider validation remain caller work |
| Photos | PhotosPicker, Transferable Data import, thumbnail decode off main, cancellation/current-selection guards | Select A then B, clear while loading, unreadable/oversize input; no broad library prompt |
| Location | Explicit permission/one-fix request, per-request manager identity, denied/restricted/cancel states | Cancel and deny; coordinates are discarded, accuracy is reported |
| Camera | Availability/permission gate, system still camera, retained delegate, permission and capture tickets | Hardware only: deny, cancel pending permission, cancel capture; pixels remain in memory |
| Widget | Embedded synthetic timeline/snapshot and intent returning a synthetic dialog | Add widget, inspect snapshot, open route, invoke intent on a working runtime |

The camera uses the system UIImagePickerController rather than an app-owned AVCaptureSession pipeline. There is no custom preview, streaming recording, microphone, or Photos save. The location adapter does not request background or temporary full-accuracy authorization. Its explicit Cancel button retires an outstanding fix; no framework timeout is promised. The photo import checks 12 MiB **after** Data transfer, so a large buffer can exist before rejection. Downsampling bounds the decoded thumbnail, not total transfer memory. Detached decode may finish after cancellation; guards prevent its obsolete result from committing.

Leaving Platform or backgrounding its scene cancels app-owned photo, location, camera, and auth attempts. System permission dialogs cannot be withdrawn by canceling a Task; the app instead invalidates acceptance. This is a single-window teaching app, not a multi-scene service coordinator. Authentication has no configured provider or token storage, and receiving a callback would not establish a validated login.

The custom WebKit policy allows only its loadHTMLString about:blank document. It is not a remote-origin allowlist to copy unchanged into production. A weak message forwarder avoids handler ownership cycles; teardown removes scripts, message handlers, and delegates. Cookies are synthetic, ephemeral, never used for navigation, and command/document checks govern status updates. The web source contains no fetch, external URL load, or general native evaluator.

## Storage and extension limits

Core Data uses Application Support/SwiftUIWorkbench/synthetic.sqlite. SwiftData uses its default app-sandbox store. Previews use memory-only stores. Neither is seeded automatically. Store failures are surfaced without deleting existing data. CRUD rollback is a small-context tutorial policy, not a universal policy for retaining unsaved drafts. No old-version schema fixture, migration plan, disk-full scenario, account epoch, encryption feature, CloudKit replication, or locked-device storage test is supplied.

The widget has its own synthetic entries and no App Group entitlement or shared store. Its intent returns a dialog and does not mutate either database. A later timeline refresh request is not an exact schedule. No claim of interprocess durability, synchronized acknowledgments, signed extension behavior, or real widget refresh is made.

## Workshop and lesson connections

The maintained content is ../../content/practice-native.json. Each workshop has 900+ teaching words, at least four sections, a learner exercise and worked answer, three explained quizzes, official references, and explicit artifact file links. The companion demonstrates mechanisms; the workshop extensions and acceptance records remain learner work.

| Workshop | New stable session IDs | Earlier UI/platform connections |
| --- | --- | --- |
| swiftui-workbench | 071–081, 084 | 009–011, 013, 031–032, 034–035 |
| ui-accessibility | 072–074, 077, 079–082, 084 | 008, 010, 022, 029–035 |
| persistence-store | 076–078, 081, 083–084 | 019–020, 053 |
| platform-adapters | 071, 075–076, 078–082, 084 | 010–011, 025, 034, 050–051, 054–056 |

The earlier lessons supplied ownership explanations and conceptual scratch exercises. This lab supplies the actual standalone app target, live UIKit bridge, constructed stores, owned service adapters, and extension embedding. Advanced editing, full migration evidence, production account isolation, provider protocols, universal links/APNs, real capture pipelines, durable shared widget mutation, and specialized platforms remain further study.

## Author verification — 29 October 2026

Toolchain: Xcode 27.1 (27A9275), Apple Swift 6.4, iOS Simulator SDK 27.1. Both targets retain iOS 17 deployment settings and Swift 5 language mode. Commands above were run from this lab directory; build output was redirected to /private/tmp logs.

- Ordinary xcodebuild command: **exit 65**, nested macro sandbox initialization failure. Log: /private/tmp/SwiftUIWorkbench-build.log.
- Macro-helper command: **exit 0, BUILD SUCCEEDED**. After source refinement, the final build log is /private/tmp/SwiftUIWorkbench-build-final.log. App and embedded extension binaries contain arm64 and x86_64 simulator architectures. Embedded-binary validation passed. The app-only metadata processor reports that AppIntents extraction was skipped because that app target has no AppIntents dependency; the intent belongs to the widget extension.
- Host parser compilation: **exit 0**. Executed parser checks: **exit 0, 3 accepted and 14 rejected fixtures**.
- Plist/project lint: **exit 0**, all three files OK.
- `node Validation/check-content.mjs`: **exit 0**. Four workshops contain 1,703 / 1,662 / 1,679 / 1,977 teaching words (7,021 total), three quizzes each, valid safe HTML and official references, 21 verified file anchors, and connections covering every session 071–084. No shared output is written.
- `xcrun simctl list devices available`: **exit 1**, CoreSimulatorService connection invalid/refused and simulator log access denied. No simulator installation/launch or physical-device run occurred.

Pending runtime evidence includes Canvas rendering, gallery/presentation interaction, Dynamic Type and VoiceOver, UIKit composition, CRUD/relaunch, background merge behavior, notification authorization/delivery/response, cold/warm installed URL delivery, WebKit callback/cookie/teardown behavior, photo selection, location and camera permission/hardware/cancellation, widget installation and intent execution. Provider authentication is intentionally unconfigured. Successful compilation is not substituted for any of these outcomes.

No company client files, shared course state/manifests/bundle, learner progress, accounts, or scheduled automations were changed. All authored artifacts stay under labs/SwiftUIWorkbench/ and content/practice-native.json.
