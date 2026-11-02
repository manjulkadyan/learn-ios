# DurableDataLab

Remote-dependency-free, synthetic macOS Swift fixtures for lessons 097–100 and workshop `durable-data-lab`. No company client edits, network requests, real accounts, Keychain calls, passkey creation, simulator launch, signing, or learner completion. All writes go to caller-supplied scratch paths or the runner's unique `/private/tmp` directory.

## Run

Requires Xcode command-line tools, macOS 14+ for SwiftData, a Swift 6 compiler with macro support, Python 3, and an installed iPhoneOS SDK for the final type-check. Tested with Apple Swift 6.4 (swiftlang-6.4.0.34.1), arm64 macOS 26 target, and iPhoneOS 27.1 SDK with an iOS 17 deployment target. These are observed checkout/toolchain versions, not a claim about the latest release. Basic CryptoKit requires macOS 10.15+/iOS 13+; SwiftData requires macOS 14+/iOS 17+ and macro-capable tooling.

From the lab directory:

```sh
python3 ValidateContent.py
bash run-checks.sh
```

The workspace's nested Swift macro helper sandbox initially failed with `sandbox-exec: sandbox_apply: Operation not permitted`, followed by missing macro-implementation diagnostics. The optional compiler-only workaround runs the helper inside the existing outer workspace sandbox:

```sh
DURABLE_ALLOW_MACRO_HELPER=1 bash run-checks.sh
```

The runner uses `swiftc -parse-as-library -swift-version 6 -warnings-as-errors`, keeps caches/output beneath a new `/private/tmp/DurableDataLab.XXXXXX`, and stops on failure. Do not run seed twice against one existing fixture: the stable operation identity intentionally rejects duplicate enqueue. Use a new directory for each independent run.

For individual checks, set task-specific variables, never HOME:

```sh
lab_root="/Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/DurableDataLab"
lab_run="$(mktemp -d /private/tmp/DurableDataLab.manual.XXXXXX)"
swiftc -parse-as-library -swift-version 6 -module-cache-path "$lab_run/cache" \
  "$lab_root/DurableStore.swift" "$lab_root/MockAuth.swift" "$lab_root/HostChecks.swift" -o "$lab_run/host"
"$lab_run/host" "$lab_run/fixtures"
swiftc -parse-as-library -swift-version 6 -module-cache-path "$lab_run/cache" \
  "$lab_root/DurableStore.swift" "$lab_root/RestartProbe.swift" -o "$lab_run/restart"
"$lab_run/restart" seed "$lab_run/restart-fixtures"
"$lab_run/restart" replay "$lab_run/restart-fixtures"
swiftc -parse-as-library -swift-version 6 -module-cache-path "$lab_run/cache" \
  "$lab_root/CoreDataMigration.swift" -o "$lab_run/coredata"
"$lab_run/coredata" "$lab_run/migration"
swiftc -parse-as-library -swift-version 6 -Xfrontend -disable-sandbox \
  -module-cache-path "$lab_run/cache" "$lab_root/SwiftDataMigration.swift" -o "$lab_run/swiftdata"
"$lab_run/swiftdata" "$lab_run/swiftdata-fixture/store.sqlite"
```

The runner additionally compiles/runs ProtectedDataExercise + KeychainChecks and NativeTransaction + NativeChecks. Its final command is a separate source type-check, not an application build:

```sh
ios_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
swiftc -typecheck -swift-version 6 -warnings-as-errors -target arm64-apple-ios17.0 \
  -sdk "$ios_sdk" -module-cache-path "$lab_run/cache-ios" "$lab_root/ProtectedDataExercise.swift"
```

## What each fixture establishes

| Fixture | Bounded assertion | Limits |
| --- | --- | --- |
| CoreDataMigration | Actual V1 SQLite saved/closed, inferred mapping into distinct V2; A/B identity, rename/default preserved; unsupported source model, corrupt metadata and destination I/O failure retain source bytes | DELETE journal simplifies closed-file comparison; no live WAL backup, cutover, relationships, custom/staged migration or mid-migration cancellation |
| SwiftDataMigration | Actual on-disk V1 container saved, V2 reopened at same URL with SchemaMigrationPlan; rename/default/A/B preserved | One lightweight path, no custom-stage or failure matrix; notification registration diagnostic under sandbox |
| HostChecks | JSON format upgrade, reload, durable intent/receipt replay, delete/conflict, A-B-A, pre-write failure, fake protected availability, corrupt/future preservation, pre-commit cancellation | JSON is not Core Data/SwiftData migration; fake errors are not measured disk exhaustion or device protection |
| RestartProbe | Two OS processes: seed exits after server effect/lost response; replay reloads both journals, preserves ID and asserts one effect | Ordinary exit, no abrupt kill, real network, receipt expiry or power-loss simulation |
| MockAuth via HostChecks | RFC S256 vector, wrong/duplicate state, one-time code, login, refresh, stale logout result, vault failure/cleanup | Fixed test entropy and synthetic provider; no real protocol/security certification |
| Rotation failure via HostChecks | Provider consumes old refresh token; locked vault save fails; unlocked plain retry denied; explicit logout/new login recovers | No provider reconciliation/grace endpoint; refresh is single-caller, no coalescing |
| KeychainChecks | Synthetic query identity/accessibility and OSStatus policy | No SecItem calls, access-group entitlement or actual item behavior |
| NativeChecks | MainActor/main-queue bridge, A-B-A rejection, fresh private-context read and preservation of B | macOS in-memory runtime only; no iOS UI, disk restart or protected files |
| ProtectedDataExercise iOS type-check | UIKit availability seam and complete-protection writing options compile | No device/simulator runtime or protected-file write |

## Critical ownership and recovery limits

DurableOutbox performs synchronous encoding and file I/O inside its actor. This is deliberately a bounded teaching fixture, **not a production cooperative-executor blocking-I/O design**. See lesson 088 for a bounded blocking worker strategy. Offloading introduces a suspension and therefore requires transaction/account revalidation and ordered publication, not an unowned detached task. Atomic replacement is not fsync/power-loss evidence and does not coordinate independent processes writing the same path. Test owners are replaced sequentially; never concurrently use multiple writable actors for one file.

AuthSession refresh is **single-caller**. An actor alone does not coalesce calls across await. The existing shared-refresh workbench can inform an account-owned shared task, but this lab does not implement it. Remote rotation can finish before FakeVault.save fails: the old refresh token is then consumed. The meaningful failure assertion expects a denied plain retry after unlock, then explicitly reauthenticates. A real provider's documented reconciliation/grace policy is an alternative, not an assumed generic retry. The in-memory current credential after failed rotation must not be taken as proof of usable/durable authorization.

The fake vault/cleanup flag are memory-only. A production restart policy needs durable sign-out obligations that gate surviving credential reload. A failed durable marker write is unresolved recovery, not successful global logout. Outbox.logout throws if its durable epoch transition fails; a separate UI/account owner must still close local authorization and reconcile persistence. Keychain, files, contexts and remote revocation are not one transaction.

NativeTransactionOwner owns a dedicated main-queue context and uses MainActor.assumeIsolated only inside that established queue/actor bridge. A private context must use its own serialized command owner. Rollback/reset affects the whole writer; no unrelated UI editor may share it. This source initially warned about actor state in Core Data's Sendable closure; the explicit checked bridge fixed that warning and the runtime ownership check passed.

## Protected-data and Keychain exercise (target/device required)

1. Build a standalone scratch iOS 17+ target and include ProtectedDataExercise.swift; do not add it to the company application. Retain an availability-observation owner and remove it on teardown. Actual I/O errors remain authoritative after advisory availability checks.
2. Write synthetic files with complete protection and completeUnlessOpen, inspect replacement attributes, and compare retained-open versus closed/reopened handles across lock/unlock on a passcode-enabled device. completeUnlessOpen does not guarantee newly opened background access. Record actual operations/errors, lifecycle and OS, without assuming a simulator reproduces protection.
3. Inspect Keychain dictionaries first. A future signed adapter may use only `example.course.DurableDataLab.synthetic` plus bounded synthetic accounts, with narrowly scoped cleanup. No broad class-only delete. Prefer fake status checks until you explicitly implement such a scratch adapter. No actual Keychain writes are included here.
4. Separate item-not-found, interaction-not-allowed/not-available, duplicate and configuration errors. Explain foreground device-only versus after-first-unlock availability and cross-device restore implications. Passkey/biometric/provider evidence needs its own relying-party/signed-target workflow.
5. Hold A's transaction values, activate B and A again, then release A's old epoch; assert rejection before mutation. Design a durable sign-out marker and bootstrap gate, then state the marker's protection/error policy and remaining device evidence.

## Author verification ledger — 2 November 2026

Initial compilation was performed beneath `/private/tmp/durable-data-author.TYR7x7` with independent module caches. Initial failures were corrected: test closure parameters now declare Sendable, single-file entry points use parse-as-library, throw sites include required try, and the native owner has an explicit checked actor/queue bridge. SwiftData's nested macro helper required the optional workaround above.

- `swiftc -swift-version 6 -module-cache-path ... DurableStore.swift MockAuth.swift HostChecks.swift -o .../host-checks`: exit 0 after fixes. Running `.../host-checks .../rotation-fixtures`: exit 0, including the added post-rotation vault failure, denied retry and reauthentication assertions.
- `swiftc -parse-as-library -swift-version 6 ... CoreDataMigration.swift -o .../coredata-checks`, then `.../coredata-checks .../coredata-fixtures`: exit 0; actual SQLite migration and preservation/failure assertions passed.
- `swiftc -parse-as-library -swift-version 6 -Xfrontend -disable-sandbox ... SwiftDataMigration.swift -o .../swiftdata-checks`, then `.../swiftdata-checks .../swiftdata-fixtures/store.sqlite`: exit 0; actual on-disk schema migration assertions passed. Runtime also emitted `CoreData: error: unable to check registration for posting store changed notification`. No cross-process notifications are claimed verified.
- `.../restart-probe seed .../process-fixtures`, followed by independent `.../restart-probe replay .../process-fixtures`: both exit 0; persisted ambiguous intent and receipt reload yielded one effect and durable acknowledgment.
- `.../keychain-checks`: exit 0; no SecItem calls. `swiftc -swift-version 6 -warnings-as-errors ... NativeTransaction.swift NativeChecks.swift -o .../native-checks`, then `.../native-checks`: exit 0, with the in-memory ownership assertions passed.
- `swiftc -typecheck -swift-version 6 -target arm64-apple-ios17.0 -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk ... ProtectedDataExercise.swift`: exit 0. This is compilation evidence only.

Final command: `DURABLE_ALLOW_MACRO_HELPER=1 bash ios-learning/course/labs/DurableDataLab/run-checks.sh` from the mobile workspace. **Exit 0**, output root `/private/tmp/DurableDataLab.gtS6up`. All Swift compilations used warnings-as-errors. Content validation passed with 1,883 / 1,946 / 2,119 / 2,202 teaching words for 097–100, 1,525 for the workshop, and all 8 interview/schema/HTML/anchor/artifact checks. Host, two-process replay, Core Data, SwiftData, Keychain dictionary/status, native in-memory owner and iOS seam checks all passed. The SwiftData notification-registration diagnostic recurred. Xcode tool discovery additionally reported failed filesystem event-stream startup and a user-cache lookup fallback; these environmental diagnostics do not establish actual device or cross-process behavior. Parent owns the global course build; this lab never invokes it.

After correcting two overloaded Apple documentation URLs and adding the verified typed-metadata/generic-perform availability note, `python3 ios-learning/course/labs/DurableDataLab/ValidateContent.py` again exited 0. Final prose counts are **1,954 / 1,946 / 2,119 / 2,202**, workshop **1,525**. Companion Swift sources were unchanged after the complete runner pass, so runtime checks were not unnecessarily repeated.

## Reference audit and deliberately remaining work

Read CONTENT_SPEC completely including its 2 November expansion, and client AGENTS before client source. Inspected lessons 018/019/025/053/054/083: existing material covers foundations and CRUD, while executable old-store preservation, disk outbox/restart and integrated synthetic auth recovery needed the added practice. Read-only anchors inspected: CoreDataStore lines 25/60/105; MedicationReminderStore lines 80/122–143; CredentialManagerActor lines 81/154; KeychainManager lines 42/63 and its query/error adapters. These are source observations, not production runtime evidence.

Verified official facts by reading Apple's current Markdown documentation for automatic migration, SchemaMigrationPlan/MigrationStage, completeUnlessOpen, UIApplication protected availability, Keychain accessibility classes/statuses and supporting passkeys; checked RFC 7636/8252 plus official Kotlin Mutex, Android Room and Java 11 Files references. Lesson reference arrays preserve precise source URLs. Teaching policy and proposed recovery designs are labeled separately from those reference facts and the executed fixture assertions.

Still required for a production proposal: custom/relationship migrations and cutover/process death; physical-device lock/reboot/retained-handle matrices; real signed Keychain/entitlement cleanup; durable sign-out restart; provider/browser/passkey verification; refresh coalescing and canceled waiter schedules; real receipt retention/conflict contracts; fsync/power-loss/disk-full behavior; multi-process/extension writers; bounded blocking worker implementation. No production measurements or learner acceptance are invented. CloudKit and full multi-device synchronization remain specialist work outside this unit.

## Integration correction — conflict dependency order

Independent review found that removing a conflicted command and appending its replacement could move it behind a later edit to the same record. The later edit could advance the server revision before the replacement runs. The supplied `resolveConflict` now requires one pending command for that record, replaces it at its original index with a fresh ID, and rejects unsupported dependent edits without changing the queue, bytes or actor memory. A broader resolver must reconcile the entire dependent lane atomically; a current revision supplied by the caller is still a snapshot that the server can reject after an intervening edit.

`HostChecks.rebaseChecks` verifies successful single-edit resolution, the immutable original conflict receipt, failed-write preservation, and rejection of a two-edit queue whose later operation could otherwise execute first. Lesson 098, both associated interview answers and the workshop were corrected; an explained dependency-order MCQ was added. The supplied implementation is instructor reference code, not a completed learner exercise.

From the workspace, integration verification used:

```sh
REBASE_TMP=$(mktemp -d /private/tmp/outbox-rebase.XXXXXX)
swiftc -parse-as-library -swift-version 6 -warnings-as-errors \
  -module-cache-path "$REBASE_TMP/module-cache" \
  ios-learning/course/labs/DurableDataLab/DurableStore.swift \
  ios-learning/course/labs/DurableDataLab/MockAuth.swift \
  ios-learning/course/labs/DurableDataLab/HostChecks.swift \
  -o "$REBASE_TMP/host-checks"
"$REBASE_TMP/host-checks" "$REBASE_TMP/fixtures"
python3 ios-learning/course/labs/DurableDataLab/ValidateContent.py
```

Both compilation/execution and content validation exited **0**. Output at `/private/tmp/outbox-rebase.3k2vRv` reported `PASS rebase` and the full existing host checks. Updated prose counts: lesson 098 **2,058**, workshop **1,611**; the other lessons and all eight interview checks passed. Unchanged Apple-store migration/native/protected-data sources were not rerun. No broader conflict engine, device behavior or production result is inferred from this correction.
