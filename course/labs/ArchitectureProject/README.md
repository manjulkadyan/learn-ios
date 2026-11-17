# Field Notes: original architecture companion

This is an original, synthetic, offline learning project for lessons 145–148.
It uses the public topic order only; no paid course lessons, assets, or projects
were inspected or copied. It records no learner completion or certification.
No company client, real account, remote package, backend, or deployment is used.

## Run the host logic

Requires Swift tools 6.0+, Swift 6 language mode, and macOS 14+ for Observation.
The package has no remote dependencies. Swift Testing is supplied by the toolchain.
Run from this directory:

```sh
sh verify-host.sh
python3 verify-content.py
python3 verify-examples.py
```

The host script runs `swift --version`, then this command with compiler caches
redirected to writable temporary directories:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/architecture-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/architecture-swift-cache \
swift test --scratch-path /private/tmp/architecture-project-host \
  --cache-path /private/tmp/architecture-project-cache --disable-sandbox
```

Only scratch/cache output is written outside the companion, under `/private/tmp`.
The compiler subprocess sandbox flag accommodates this managed environment; the
workspace's filesystem restrictions still apply. No remote plugin is loaded.
An ordinary standalone terminal may omit that flag if its toolchain permits.
Do not put generated build output in another author's lab or course data files.

## Files and responsibilities

| File | Responsibility |
| --- | --- |
| `Package.swift` | Five source targets, one test target, one library product; Swift 6 mode |
| `Sources/NoteDomain/Contracts.swift` | Note values, validation, Sendable access/reader/time contracts |
| `Sources/NoteData/Repository.swift` | Synthetic reader, ContinuousClock adapter, account-scoped repository |
| `Sources/BrowseFeature/BrowseModel.swift` | Observable loading/result state and revision gates |
| `Sources/SavedFeature/SavedModel.swift` | Independent saved list state and reset-safe async paths |
| `Sources/AppShell/Shell.swift` | Composition, session routes, account switching, Browse task ownership |
| `Tests/ArchitectureTests/ArchitectureTests.swift` | Registered reader gates, virtual time, fifteen behavior tests |
| `Native/ArchitectureApp.swift` | Separate SwiftUI App, root, Browse/Saved/detail adapters |
| `ChangePlan.md` | Cost comparison, author review findings, proposed durable-store adoption/recovery |
| `verify-host.sh` | Host test command and compiler cache paths |
| `verify-native.py` | Simulator module/object compilation and adapter linking |
| `verify-content.py` | Scoped schema/depth/HTML/artifact/anchor/prerequisite audit |
| `verify-examples.py` | Separate typechecking of four complete lesson snippets |

Dependency arrows mean imports: BrowseFeature→NoteDomain,
SavedFeature→NoteDomain, NoteData→NoteDomain, AppShell→all four.
The native source is outside package Sources and is not a host-test target.
The library product `ArchitectureKit` includes AppShell and NoteData with their
target dependencies. Public initializers are intentional consumer APIs.

## Behavior and honest boundaries

Browse loads complete snapshots for synthetic `demo-a`/`demo-b`. Saved membership
and cached notes live only in one in-memory repository. Reload bypasses cache;
cacheAllowed reuses it for age strictly less than five seconds. Accepted time is
sampled after reader completion. Missing cache differs from loaded empty data.
The newest admitted fetch wins authority even if it fails; an older completion
cannot refill the cache. Ordinary/malformed refresh failure preserves the last
accepted cache, but Browse shows failure rather than claiming fresh success.

Browse checks cancellation and its model revision after a delay, before invoking
the shared repository. An obsolete delayed refresh cannot become a newly admitted
fetch and replace shared cache/detail while leaving newer Browse rows visible.
The success/error guards after the repository call still protect presentation.

Saved separates `sessionRevision`, advanced by reset, from `readRevision`, advanced
by reload. A completed read does not revoke a pending mutation's session authority.
A successful current-session toggle starts a fresh reload even if an overlapping
reload already returned empty. Reset rejects both late success and late failure;
repository invalidation remains the separate owner of account data authority.

Account switching requests Browse task cancellation, resets both models and
path, revokes the repository, then publishes a new session. A session UUID plus
account and record ID rejects obsolete routes, including A→B→A. Saved commands
use the same gate and capture the correct model before suspension. Old success
and old ordinary failure both need guards. Revoked repository authority prevents
cache refill even if the synthetic gate reader ignores cancellation.

The clock seam is deliberately narrower than `Swift.Clock`: `now()` returns a
local elapsed Duration and `sleep(for:)` suspends. LiveClock wraps ContinuousClock;
TestClock advances manually and settles canceled/deadline continuations once.
GateReader independently controls request registration and completion.
Every held test operation is released and joined; tests use no elapsed sleeps.
The XCTest harness prints zero tests because these are Swift Testing `@Test`
functions. The subsequent Swift Testing result is the relevant fifteen-test count:
twelve original baseline tests and three follow-up regression tests.

This is not durable persistence, authentication, server authorization, network
cancellation, background execution, or cross-window synchronization. Saved IDs
are reconciled against a COMPLETE snapshot; a page cannot be treated as deletion
evidence. Uncooperative production readers need timeout/resource shutdown rules.
Switching does not await a forever-running reader; old retained objects may live
until its task finishes, but cannot affect the new repository.

## Create a concrete isolated iOS target

The companion supplies real app source, not a checked-in `.xcodeproj`. Create the
learner's project in a separate scratch directory; do not alter ios-client or a
shared workspace target. Authoring verification did not perform these UI steps.

1. In Xcode choose File → New → Project → iOS → App. Use product name
   `FieldNotesArchitecture`, Interface SwiftUI, Language Swift, no storage or
   remote service option. Use a synthetic bundle identifier such as
   `org.example.FieldNotesArchitecture`. Save outside company client projects.
2. In the app target set iOS Deployment Target to 17.0, Swift Language Version to
   Swift 6, Strict Concurrency Checking to Complete where that setting is shown,
   and Default Actor Isolation to nonisolated (not a project-wide MainActor
   default). The source states its own actor isolation. Xcode 16+ is the practical
   baseline for this tools-6.0 package; the checked compiler was newer.
3. Choose File → Add Package Dependencies → Add Local. Select the
   `course/labs/ArchitectureProject` directory. Add its `ArchitectureKit` library
   product to the app target. Add no remote dependencies and do not copy package
   Sources into the app target; doing so loses module boundaries or duplicates
   declarations.
4. Remove the generated `<ProductName>App.swift` and `ContentView.swift` from
   app target membership, or delete them only in this new scratch project.
   Add `Native/ArchitectureApp.swift` to this target (copy or reference in the
   scratch project). Keep exactly one `@main` entry. No company SDKs, assets,
   configuration files, secrets, capabilities, or entitlements are needed.
5. Select this app scheme and an installed iOS simulator, then Build. Simulator
   builds do not require a distribution team or provisioning profile. Real-device
   signing is outside this authoring task. Record the selected destination,
   configuration, toolchain, result, and any warnings.
6. Run the simulator app. Reload; open n1; Toggle saved; Return to root; select
   Saved and Update saved list. Expect n1. Switch account; expect empty Saved,
   root path, and demo-b titles after loading. Back navigation, repeated Reload,
   large text, VoiceOver labels/actions, and compact/expanded windows need actual
   interaction checks. Do not mark them passed from compilation.

The adapter intentionally has one shared NavigationStack around two tabs.
Detail is a pushed route above that root. It does not supply independent tab
histories, durable restoration, external deep links, or live Saved subscriptions.
Each WindowGroup root owns its own Shell; windows have independent synthetic
data. These choices are testable starting contracts, not production defaults.

## Native compile command and observed evidence

```sh
python3 verify-native.py
```

The script selects `xcrun --sdk iphonesimulator swiftc`, Swift 6 language mode,
an arm64 simulator target on this Mac (x86_64 on an Intel host), deployment 17.0,
explicit simulator SDK and temporary module cache. It emits all five modules
and objects, compiles the actual SwiftUI adapter, links an executable, and calls
`xcrun vtool -show-build`. It does not package an app or run a simulator.
Linker-generated local code signatures are not provisioning/distribution evidence.

Original author observations on 17 November 2026, before the follow-up fixes below:

- Apple Swift 6.4.2, swift-driver 1.168.6, target arm64-apple-macosx26.0.
- Xcode 27.2, build 27B52; iPhoneSimulator27.2.sdk.
- `sh verify-host.sh`: PASS, twelve Swift Testing tests, zero failures.
- `python3 verify-content.py`: PASS, lessons 145–148 respectively contain
  1,939 / 1,914 / 2,025 / 2,037 builder-style teaching words; workshop contains
  1,576. Eight interviews and fourteen artifact registrations passed. All
  prerequisites precede their lessons in `content/curriculum.json`, including
  the complete stage/extension ordering. Later extensions are optional reading.
- `python3 verify-examples.py`: PASS, four complete Swift lesson snippets
  independently typechecked against the host NoteDomain module.
- A read-only Node invocation imported the existing `course/teaching.mjs`
  `simpleIssues` function: PASS for all four lessons and the workshop. No shared
  builder or generated data was run or written.
- `python3 verify-native.py`: PASS, five simulator modules plus actual adapter
  compiled and linked. Final SDK-explicit run produced
  `/private/tmp/architecture-native-fc0hvh7y/ArchitectureApp`; `vtool` reported
  platform IOSSIMULATOR, minimum OS 17.0, SDK 27.2.
- The first host attempt failed writing the default protected Clang cache.
  Explicit cache environment paths resolved it. SwiftPM still reports inaccessible
  user configuration/security directories and disables those user-level caches.
- The first native attempt failed when the installed macro server tried to create
  a nested sandbox. Compiler `-disable-sandbox` allowed local Observation macros
  within the existing managed filesystem restrictions. A first linked attempt
  warned about xcrun's default sysroot; selecting `--sdk iphonesimulator` removed
  it. Final binary platform metadata was inspected, rather than accepting any
  executable as iOS evidence.
- Official Observation, NavigationStack, ContinuousClock, Swift language, package
  manifest, and Swift Testing pages were fetched from primary documentation.
  Apple documentation data confirmed iOS 17 Observation, iOS 16 NavigationStack,
  and local ContinuousClock instants. Source anchors were read after AGENTS.md.

## Follow-up fixes and evidence — 17 November 2026

The independent source review found two additional schedules, now fixed and
covered by deterministic tests. Lesson 146's simple picture now compares the
actual branching imports. Lessons 147/148 and the workshop explain the authority
checks and the current test inventory. IDs, quizzes, checklists, prerequisites,
source/file registrations, exercise requirements, and existing teaching snippets
were preserved. The interview bank was unchanged.

| Test | Controlled schedule and asserted result |
| --- | --- |
| `delayedObsoleteBrowseCannotReachRepository` | Register A's delay, finish B with Garden plan, advance A, and join it. Exactly one reader call; Browse, cache, and detail keep Garden plan. |
| `savedMutationReconcilesAfterOverlappingReload` | Hold a successful toggle, complete an empty reload, then release and join the toggle. Its follow-up read displays n1 and agrees with the repository. |
| `resetRejectsLateSavedMutationSuccess` | Hold a successful toggle, reset, then release and join it. No follow-up read, rows, or failure from the old model session. |

The Saved mutation fixture is a valid delayed `NoteAccess` implementation. Its
reset test establishes presentation authority; it does not claim that resetting
a model cancels a side effect or revokes a data adapter. Existing repository
invalidation and A→B→A route tests continue to check those separate contracts.
All held operations are released and joined without real elapsed sleeps.

Executed against the changed source using Apple Swift 6.4.2 and Xcode 27.2/27B52:

- `sh verify-host.sh`: PASS, fifteen Swift Testing tests, zero failures.
- `python3 verify-content.py`: PASS, lessons 145–148 contain
  1,939 / 1,914 / 2,107 / 2,122 teaching words; workshop contains 1,741.
  Eight interviews, fourteen artifacts, and prerequisite ordering passed.
- `python3 verify-examples.py`: PASS, all four existing lesson snippets
  independently typechecked after the changed host package build.
- `python3 verify-native.py`: PASS, all five simulator modules and the actual
  SwiftUI adapter compiled and linked to
  `/private/tmp/architecture-native-ksod1r2w/ArchitectureApp`.
  `vtool` reported IOSSIMULATOR, minimum OS 17.0, SDK 27.2.
- From the ios-learning root,
  `node course/check-teaching.mjs unit-27.json practice-architecture.json interview-architecture.json`:
  PASS, three files, five teaching introductions, eight interview identities.
- A scoped before/after hash comparison confirmed unchanged IDs, assessments,
  section links, exercise requirements, prerequisites, references, registrations,
  and existing code blocks. No shared builder or generated course data was run.

SwiftPM still warned about inaccessible optional user configuration/security
caches; the supplied temporary cache settings allowed the host checks to pass.
`ChangePlan.md` retains the original author's twelve-test review record as history;
this follow-up records the current fifteen-test suite. Durable implementation and
independent human review remain pending.

The native result is compiler/linker evidence for the changed source. No isolated
Xcode project build, app packaging/install, simulator interaction, accessibility
or adaptive-window audit, physical-device run, provider call, or durable-store
acceptance occurred. Runtime and data-recovery claims still need those checks.

Pending: complete isolated Xcode project build/run, simulator interaction,
accessibility and adaptive-window acceptance, physical-device behavior,
app lifecycle stress, provider/network adapters, persistent bookmark adapter,
durable recovery fixtures, and independent reviewer sign-off. No runtime or
provider result is inferred from the host or simulator-compiler evidence.
Shared course registration, data generation, navigation integration, and global
course checks belong to the integrating author; these files do not modify them.
