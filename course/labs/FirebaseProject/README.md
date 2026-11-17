# Firebase notebook companion

This is our original account-owned notebook curriculum for lessons 129–136 and workshop `firebase-course`. All accounts, note titles, tokens and media identities are synthetic. It contains executable offline Swift policy code, actual separately gated Firebase SDK adapters, real Security Rules sources, unexecuted emulator fixtures, and optional Functions/presence source. It is not a completed production app or learner submission.

No dependency was installed or downloaded, no account authenticated, no emulator started, and no service deployed during authoring. The company clients and shared course registrations remain untouched.

## Gate A: runnable offline policy

The host compile includes **only** `Host/Policy.swift` and `Host/Checks.swift`. Foundation is the sole imported framework. Use a Swift 6 compiler on macOS; the actual authoring compiler was Apple Swift 6.4.2, target `arm64-apple-macosx26.0`. These are observed toolchain facts, not minimum Firebase requirements.

From `ios-learning`:

```sh
swift --version
swiftc -swift-version 6 -module-cache-path /private/tmp/firebase-course-module-cache course/labs/FirebaseProject/Host/Policy.swift course/labs/FirebaseProject/Host/Checks.swift -o /private/tmp/firebase-course-checks
/private/tmp/firebase-course-checks
```

Observed result: compile exited 0; execution exited 0 and printed **30 offline policy checks passed; Firebase rules and SDK were not executed.** The checks exercise environment rejection, anonymous/cross-account/forged-owner decisions, stale edit and title bounds, current/stale/same-UID session schedules, malformed snapshots, overlapping pages, same-revision disagreement, token ownership/rotation/signout, media byte/type/path boundaries, orphan recovery, bounded defaults and arithmetic overflow.

`NotePolicy.authorize` is **our model**, not Firebase Security Rules. `SessionModel` holds in-memory state, not an atomic durable store. `TokenOwnership` returns effects and updates a local binding; it does not deliver or persist server registry operations. `MediaPolicy.recovery` chooses a next step; it does not upload or delete. `PagePolicy` preserves first-seen order and does not reproduce Firestore sorting. The read estimate is synthetic arithmetic, not pricing or a production measurement.

Independent work: add a status/error publication method, then deliver an old account's failure after a newer account's successful snapshot. Test same-UID relogin too. Separately add page request identity or a failed token-detachment acknowledgement policy. Retain your predictions and actual new checks; the supplied baseline does not complete these exercises.

## Gate B: actual rules interpreter, not executed

Core configuration is `Emulator/firebase.json`. It selects the real Firestore/Storage rule files and binds Auth 9099, Firestore 8080 and Storage 9199 to `127.0.0.1`. Every local component uses `demo-firebase-course`. No production fallback exists. Auth is included for later app interaction; the rules suite itself supplies mock token identities rather than signing in.

Prerequisites must already be provisioned in a separately authorized environment: a compatible Firebase CLI, required emulator binaries, an appropriate Java runtime, Node, and `firebase` plus `@firebase/rules-unit-testing` modules resolvable from the fixture directory. Record their exact versions when running. There is no package install command or invented version pin here. **A CLI existing on disk does not establish that missing emulator binaries will not be downloaded on startup.** Do not start under the assignment's no-download restriction.

Once provisioned, from `course/labs/FirebaseProject/Emulator`:

```sh
FIREBASE_RULES_LAB=1 firebase emulators:exec --project demo-firebase-course --config firebase.json --only auth,firestore,storage 'node --test --test-concurrency=1 rules.test.mjs'
```

The CLI must supply `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` and `FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199`; fixture assertions reject other values. The fixture loads the rule text with `initializeTestEnvironment`, clears Firestore and Storage between cases, and cleans up its contexts at the end. Missing modules or runtimes are failed prerequisites, not skipped assertions to report as passed.

Firestore fixtures cover owner CRUD; anonymous/Bob direct reads; forged ownership; extra fields; wrong types; empty/oversized titles; fractional/skipped/stale revision; client timestamp; ownership transfer; bounded/unbounded/oversized lists; unknown paths and token-registry denial. Storage fixtures cover owner read/delete, anonymous/Bob denial, MIME, owner metadata, extra metadata, zero/exact-limit/over-limit bytes, forbidden overwrite and metadata transfer.

The Storage fixture's three bytes declared `image/jpeg` are intentionally not an image. The rules evaluate declarations and rights, not valid JPEG pixels. A real image preparation/rendering check belongs to native integration.

Rule differences to review:

- Swift trims and counts `Character` values; Firestore checks stored string size without trimming. Whitespace-title hardening needs a deliberate rule and direct fixtures.
- The host restricts IDs; Firestore rules do not currently constrain `noteID`.
- Rules validate exact keys and request-time timestamps absent from the small host Note.
- Storage objects are immutable: updates/listing deny, changed bytes get a new ID, and owner deletion is a separate permission.
- All media-manifest, token-registry, cleanup-command and administrative client paths deny. Add and test a manifest policy before claiming media publication.

The emulator does not enforce production composite-index requirements and does not reproduce all transaction behavior or service limits. The supplied `firestore.indexes.json` is for the **optional** query `revision > 0`, ordered by `revision` ascending and `updatedAt` descending. It is not a deployed index and is not required evidence for the base single-field notebook query. Verify actual deployed query/index readiness later.

## Gate C: isolated iOS notebook target, not built

The files contain real imports and APIs. They intentionally produce `#error` if included without their compile condition; they do not silently substitute mocks. No Firebase SDK dependency was resolved or linked for this lab. A syntax parse is not an SDK typecheck.

Create a scratch Xcode iOS App project named `FirebaseNotebookLab`, SwiftUI/Swift, with a made-up bundle ID such as `example.learning.FirebaseNotebookLab`. Choose iOS 17 as this app's deployment target. This is a teaching-app choice above the documented Firebase 13 iOS floor, not a claim about every product/platform.

Add exactly these files to the target:

```text
Host/Policy.swift
SDK/FirebaseBootstrap.swift
SDK/FirebaseNotesRepository.swift
SDK/FirebaseMediaRepository.swift
SDK/FirebaseCourseApp.swift
```

Exclude `Host/Checks.swift` and `SDK/ProductionServices.swift`. Remove/exclude the generated duplicate App entry so there is one `@main`. Set Active Compilation Conditions to include `FIREBASE_SDK_LAB`, Swift language mode to Swift 5 for this adapter exercise, and default actor isolation to nonisolated. The host was checked in Swift 6 mode; these target settings do not alter Firebase's compiler requirement. Resolve/typecheck actor and callback transfer diagnostics against the actual chosen SDK.

In an already provisioned dependency environment, attach `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore` and `FirebaseStorage` products from the reviewed Firebase Apple package. Xcode Add Packages normally resolves/downloads dependencies; do not invoke it under this assignment's no-download constraint. Save the exact selected release and resolved graph when authorized integration occurs.

The bootstrap uses a named `FirebaseCourseEmulator` app and synthetic FirebaseOptions. It routes Auth before account calls; establishes Firestore loopback, disabled local TLS and `MemoryCacheSettings` before queries; and routes Storage before transfers. Include no remote `GoogleService-Info.plist` in this emulator target. Optional operational products are excluded because their initialization does not inherit these three routes.

If a particular local runtime requires an App Transport Security exception, add only the documented local-network/localhost exception to this scratch Debug target after diagnosing the actual error. Do not weaken a release target globally. Confirm the resolved SDK accepts the synthetic demo options through an actual target build and local request; this is currently pending.

After the emulators are separately running, build a simulator destination and record the exact Xcode command/settings. Launch the app, choose **Connect local services**, then **Create synthetic local account**, then **Add paper lantern note**. Each milestone is separate: configure objects, authenticate locally, acknowledge a Firestore transaction, and receive listener data. Repeat with stopped emulators and a denied request. Capture failures without logging credentials or tokens.

The target supports a simulator's loopback-to-Mac path only. On a physical phone, loopback means that phone; the guard intentionally rejects a remote Mac address. No physical-device emulator integration is claimed.

The app entry demonstrates synthetic account creation, create and a live first window. Read/edit/delete/page methods are service adapters for independent controls. Preserve a captured expected revision, retain an edit on conflict, and check current account/request identity after await. Historical cursors reset on account/query changes and are separate from the live first window. `disconnect` removes listeners and clears protected display; composition must call it before signout and teardown.

Storage starts at prepared valid JPEG bytes; picker, orientation, resizing and rendering are learner integration. Bound encoded bytes and decoded memory separately. `cancel` reduces transfer work, while the caller still rejects stale progress/completion. Do not claim a manifest was written under the current rules.

## Gate D: optional remote operational target, not executed

Use a separate scratch target/configuration that excludes the emulator App/bootstrap and includes `Host/Policy.swift` plus `SDK/ProductionServices.swift`. Set `FIREBASE_PRODUCTION_SERVICES`; attach the actual products matching its imports: Core, Auth, Messaging, Analytics, Crashlytics, Performance, RemoteConfig, AppCheck, Functions and Database. Supply your own app entry/composition. This file is adapter source, not a second completed app.

Remote configuration steps remain learner work. Register the exact bundle ID in the chosen Firebase project, review its target-specific `GoogleService-Info.plist`, add it only to that target, and inspect the built resource. Record project, registration, bucket, region and service owners. Configuration is not a service-account secret; administrative/provider/APNs private credentials must stay outside the bundle/repository.

**Providers/account lifetime:** enable the selected Auth providers. For Apple, configure the matching capability/provider, use a cryptographically random nonce and matching hash/credential exchange, and test cancellation and recent-login recovery. For Google, review the separately selected GoogleSignIn release, client IDs, URL scheme, presenting controller and callback exchange. Explicit linking/collision handling and account cleanup are additional workflows. No provider compatibility or successful sign-in was established here.

**Messaging/APNs:** enable Push Notifications for the actual app ID/target and matching signing profile; assess background Remote notifications separately. Upload the reviewed APNs authentication key with team/key IDs through an authorized console account. Keep the key out of source. Use `UIApplicationDelegateAdaptor(MessagingBridge.self)` in your own App and install its delegate after configuration. The source forwards APNs token explicitly. If choosing disabled proxying, set `FirebaseAppDelegateProxyEnabled` false and complete all required forwarding/presentation/analytics callbacks from the official guide. Ask permission after explicit user action. Add routing for foreground/tap/cold-launch, account gates, authenticated token-registry writes and idempotent detachment. Test delivery on an appropriate real-device/provider setup; no send occurred here.

**Consent:** before `FirebaseApp.configure`, initial Info.plist Boolean defaults are `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false`, `FirebaseCrashlyticsCollectionEnabled=false`, and `firebase_performance_collection_enabled=false`. Runtime `applyConsent` re-applies each stored purpose choice. Test enable, revoke and relaunch; persisted runtime settings can override initial defaults. Keep user content, email and tokens out of events, crash keys and trace attributes. Notification permission does not determine telemetry consent.

Crashlytics documents next-launch application of opt-out and local retention while reporting is disabled; subsequent opt-in can send retained reports. Test that retained-report lifecycle before re-enabling. A setter does not establish deletion of previously stored diagnostics.

**Crashlytics:** retain the exact binary/dSYM pair and compare their UUIDs with `dwarfdump --uuid`. If using the official upload run script in later authorized remote work, configure its inputs:

```text
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist
$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist
$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)
```

With both `ENABLE_USER_SCRIPT_SANDBOXING=YES` and `ENABLE_DEBUG_DYLIB=YES`, include `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}.debug.dylib`. Consult the chosen SDK's current instructions for its script location. No upload script or test crash ran here. A readable dashboard report remains separate from matching local UUIDs.

**Performance:** `traceSave` measures repository-call-start to return and uses `defer` to stop on thrown exits. Apply consent first, define population and units, and use bounded metrics. It measures neither UI rendering nor whole-app responsiveness unless those are explicitly inside the chosen interval. No trace was uploaded or performance gain measured.

**Remote Config/App Check:** create `notes_page_size` with a safe default, stage any remotely proposed values, and retain local 1–25 validation. Define fetch/activation timing and failure fallback. Install the App Check provider factory before configuration, register App Attest for the matching app, check metrics/device coverage, then plan enforcement. Debug provider tokens stay outside release source; debug/simulator evidence does not establish physical-device attestation. Auth, App Check and resource rights remain distinct.

## Gate E: Functions and RTDB integration, not executed

`Functions/cleanup.mjs` requires separately provisioned `firebase-admin` and `firebase-functions` releases supporting the documented v2 callable/Firestore APIs. No version was selected or downloaded. In a provisioned scratch Functions workspace, copy the source, set package `type` to `module` and `main` to `cleanup.mjs`, and record compatible exact dependencies and supported Node engine using the current official Functions guide. Configure `FIREBASE_FUNCTIONS_LAB=1` and an explicitly reviewed `FIREBASE_COURSE_STORAGE_BUCKET`; the module refuses missing gates. For the demo local setup the bucket is `demo-firebase-course.appspot.com`.

For later local execution, add a scratch Functions entry to the emulator config pointing to that provisioned source directory, bind its emulator to loopback port 5001, and start it with the same demo project's Auth/Firestore/Storage emulators. Ensure Admin Firestore and Storage endpoints point to the emulators and never supply service-account credentials. Configure the client Functions object with `useEmulator(withHost: "127.0.0.1", port: 5001)` before calling; the supplied remote `requestCleanup` needs this explicit alternate composition. App Check is enforced on the callable source: provide compatible test evidence under the selected runtime; do not silently disable enforcement or claim local attestation. Record actual emulator support/limitations when provisioning.

The callable derives UID from authenticated context, validates identities, and writes `users/{uid}/cleanupCommands/{commandID}` transactionally. Repeating the same identity/payload reuses intent; a different payload fails. The worker deletes the derived owner path with not-found tolerance, then marks completed. `accepted` is not deletion completion. Published references, bounded retry/backoff, rate limits, dead-letter/stuck-job monitoring and operational ownership need production design; the sources implement neither a full account-deletion nor manifest workflow. Never use an arbitrary client-supplied bucket/path/UID for an Admin operation.

For RTDB, `Emulator/presence.firebase.json` and `presence.test.mjs` form another **unexecuted** rules suite. In an already provisioned local environment, from the Emulator directory:

```sh
FIREBASE_PRESENCE_LAB=1 firebase emulators:exec --project demo-firebase-course --config presence.firebase.json --only database 'node --test --test-concurrency=1 presence.test.mjs'
```

The expected `FIREBASE_DATABASE_EMULATOR_HOST` is `127.0.0.1:9000`. Fixtures cover owner publish/get/delete, anonymous/Bob denial, missing/extra fields, stale client time, wrong types and false online. They do not test an actual disconnect hook. For a later SDK presence test, route Database using `useEmulator(withHost: "127.0.0.1", port: 9000)` before obtaining references, use a new connection-lifetime ID, and stop the owner before changing Auth credentials. Register disconnect removal before online advertisement, re-register on reconnect, and observe late-registration completion, removal acknowledgement, multiple connections and disconnect delay. RTDB authorization is distinct from Firestore's rules language. Presence indicates connection, not attention.

## Primary sources and compatibility evidence

Official pages were inspected through the available web tool on **17 November 2026**. The Apple release page's observed leading entry was 13.1.1 dated 22 October 2026; this is a page observation, not a guaranteed latest release or selected pin. Its 13.0.0 entry specifies iOS 15, Xcode 26.2, Swift tools 6.2.1 and compiler 6.2.3 requirements, and distribution through SPM/binaries rather than CocoaPods for Firebase 13+. Recheck the exact chosen release and GoogleSignIn compatibility independently. Firebase's emulator guide carries a Java 21 migration notice; it is not evidence of an installed Java/emulator version.

- [Apple setup](https://firebase.google.com/docs/ios/setup), [Apple release notes](https://firebase.google.com/support/release-notes/ios), [Firestore emulator setup/differences](https://firebase.google.com/docs/emulator-suite/connect_firestore), [rules testing](https://firebase.google.com/docs/rules/unit-tests).
- [User management/reauthentication](https://firebase.google.com/docs/auth/ios/manage-users), [Apple provider](https://firebase.google.com/docs/auth/ios/apple), [Google provider](https://firebase.google.com/docs/auth/ios/google-signin).
- [Transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [field rules](https://firebase.google.com/docs/firestore/security/rules-fields), [query rules](https://firebase.google.com/docs/firestore/security/rules-query), [listeners](https://firebase.google.com/docs/firestore/query-data/listen), [cursors](https://firebase.google.com/docs/firestore/query-data/query-cursors), [offline behavior](https://firebase.google.com/docs/firestore/manage-data/enable-offline), [indices](https://firebase.google.com/docs/firestore/query-data/indexing).
- [Storage uploads](https://firebase.google.com/docs/storage/ios/upload-files), [downloads](https://firebase.google.com/docs/storage/ios/download-files), [conditions](https://firebase.google.com/docs/storage/security/rules-conditions).
- [FCM/APNs](https://firebase.google.com/docs/cloud-messaging/ios/get-started), [token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens), [Analytics collection](https://firebase.google.com/docs/analytics/ios/configure-data-collection), [Crashlytics customization](https://firebase.google.com/docs/crashlytics/ios/customize-crash-reports), [dSYM inputs](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports), [trace contracts](https://firebase.google.com/docs/perf-mon/custom-code-traces), [Performance collection settings](https://firebase.google.com/docs/perf-mon/disable-sdk).
- [Remote Config](https://firebase.google.com/docs/remote-config/ios/get-started), [App Attest](https://firebase.google.com/docs/app-check/ios/app-attest-provider), [debug provider](https://firebase.google.com/docs/app-check/ios/debug-provider), [callables](https://firebase.google.com/docs/functions/callable), [Functions setup](https://firebase.google.com/docs/functions/get-started), [local Functions](https://firebase.google.com/docs/functions/local-emulator), [Firestore triggers](https://firebase.google.com/docs/functions/firestore-events), [retry policy](https://firebase.google.com/docs/functions/retries), [RTDB presence](https://firebase.google.com/docs/database/ios/offline-capabilities), [RTDB rules](https://firebase.google.com/docs/database/security/core-syntax).
- [Firestore billing](https://firebase.google.com/docs/firestore/pricing), [budget alerts](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills), [Dynamic Links shutdown FAQ](https://firebase.google.com/support/dynamic-links-faq). Dynamic Links shut down on 25 August 2025 and is excluded from this new project.

Some generic documentation URLs still show old product examples or future-tense shutdown language. Prefer platform-specific instructions and release-specific notes for the chosen version. No deprecated Dynamic Links setup or blanket CocoaPods instruction is used.

## Actual verification and remaining work

Executed syntax commands from `ios-learning`:

```sh
swiftc -frontend -parse -D FIREBASE_SDK_LAB course/labs/FirebaseProject/SDK/FirebaseBootstrap.swift course/labs/FirebaseProject/SDK/FirebaseNotesRepository.swift course/labs/FirebaseProject/SDK/FirebaseMediaRepository.swift course/labs/FirebaseProject/SDK/FirebaseCourseApp.swift
swiftc -frontend -parse -D FIREBASE_PRODUCTION_SERVICES course/labs/FirebaseProject/SDK/ProductionServices.swift
node --check course/labs/FirebaseProject/Emulator/rules.test.mjs
node --check course/labs/FirebaseProject/Emulator/presence.test.mjs
node --check course/labs/FirebaseProject/Functions/cleanup.mjs
```

All exited 0. Node was v26.12.1. Swift commands parsed syntax only; imported Firebase modules, API compatibility, availability, actor transfer diagnostics and linking were not checked. Node commands did not import packages, evaluate gates, load rules or run assertions. JSON content, artifact paths, safe HTML, simple objects, interview identities, teaching depth and all Firebase prerequisites were checked locally against the current curriculum order; main performs shared reader/builder integration.

| Evidence boundary | Actual result | Remaining evidence |
| --- | --- | --- |
| Offline Swift contracts | Compiled and ran 30 checks | Learner's independent changed behavior and tests |
| Swift adapter syntax | Parse succeeded | Resolved SDK typecheck/link and isolation diagnostics |
| JS fixture/server syntax | `node --check` succeeded | Imports, runtime initialization and assertions |
| Firestore/Storage rules | Source + direct fixtures supplied | Actual emulator interpreter execution |
| RTDB rules | Source + direct fixtures supplied | Actual interpreter and SDK disconnect behavior |
| Isolated notebook app | Source and target recipe supplied | Xcode build, simulator interaction and failure matrix |
| Authentication/providers | Concrete setup/ownership steps | Restoration, provider exchange, reauth and cleanup |
| Media | Bounded source/recovery policy | Valid image preparation/render, real transfers and manifest rules |
| APNs/telemetry | Separate adapters and settings | Device delivery, token registry, consent persistence, symbols/reports/traces |
| Remote Config/App Check/Functions | Source and integration steps | Actual activation, attestation, authenticated call and worker recovery |
| Production workload/index/cost | Bounded synthetic planning | Deployed index, service limits, current pricing and operational observations |

Name the next owner for each pending row. Keep exact commands, resolved versions, rule digests, build destinations and observed failures when those checks run. No baseline run, copied solution or authoring report marks learner work completed.

## Exact authored path set

All paths below are relative to `ios-learning/course/`; no shared registration, app, guide, learner-state or client file was edited.

```text
content/unit-24.json
content/interview-firebase.json
content/practice-firebase.json
labs/FirebaseProject/README.md
labs/FirebaseProject/Host/Policy.swift
labs/FirebaseProject/Host/Checks.swift
labs/FirebaseProject/SDK/FirebaseBootstrap.swift
labs/FirebaseProject/SDK/FirebaseNotesRepository.swift
labs/FirebaseProject/SDK/FirebaseMediaRepository.swift
labs/FirebaseProject/SDK/FirebaseCourseApp.swift
labs/FirebaseProject/SDK/ProductionServices.swift
labs/FirebaseProject/Rules/firestore.rules
labs/FirebaseProject/Rules/storage.rules
labs/FirebaseProject/Rules/firestore.indexes.json
labs/FirebaseProject/Rules/database.rules.json
labs/FirebaseProject/Emulator/firebase.json
labs/FirebaseProject/Emulator/rules.test.mjs
labs/FirebaseProject/Emulator/presence.firebase.json
labs/FirebaseProject/Emulator/presence.test.mjs
labs/FirebaseProject/Functions/cleanup.mjs
```
