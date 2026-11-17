# InterfaceProject — original notebook interface, offline core, native source

Lessons 141–144 compose a dashboard, current-card fixture feed, detail, and edit form. This is an isolated core package plus actual SwiftUI app source, **not a built or launched native app**. The values are made up, in memory, and reset on relaunch. No durable store, server history, account, SDK, analytics, or network work is included.

## Contracts and file membership

Swift tools 6.0 or later; package platforms macOS 13 / iOS 17. `InterfaceCore` owns stable IDs, values, draft validation, revision rejection, missing lookup, and pure interaction policy. `Native/InterfaceApp.swift` owns the app entry, shared Board state, original design tokens/style, semantic controls, navigation, sheet, FocusState, motion preference, and system layouts. Native source is outside the SwiftPM targets; tests are a separate target and import the core normally.

- Blue=15, Green=25, total=40. Draft 20 does not publish until Save. Blank title or 241 is invalid. Valid Blue=20 makes total=45 and increments revision.
- A successful Pin returns `PinOutcome.toggled`, changes revision, and leaves total unchanged. An old draft then conflicts. An absent ID returns `PinOutcome.missing`. Deletion makes ID lookup missing; no different item replaces that route.
- Save and Pin compute a checked next revision before copying or mutating a card. `Int.max - 1` can advance once to `Int.max`; later mutations return `revisionExhausted` with every published field unchanged. Missing ID and stale-draft checks precede this gate. The counter never wraps or resets to admit an old draft. Save returns the explicit failure; Pin does too.
- Usable width excludes 16-point padding on each side. 599 gives one column; 600 gives two for ordinary text; accessibility text gives one even at 800.
- A drag ends with one pin action only when `abs(dx)>=80 && abs(dx)>2*abs(dy)`. 80/40 is rejected, -80/0 accepted. Native arbitration is unverified; Pin/Unpin and a named accessibility action provide alternatives.
- Minimum control height 44 is a minimum, with expandable system text. Open and Pin are independent controls. System Reduce Motion removes press scaling/animation and uses an identity plan transition. Keyboard focus is distinct from assistive focus.
- Cancel discards the in-memory draft. Invalid/conflict/missing/exhausted results retain it while the sheet remains presented. Exhausted Save clears input focus and shows that no changes were saved; correcting a field cannot restore revision capacity. The dashboard displays missing/exhausted Pin failures through the same owner callback used by button, gesture, and accessibility action. The conservative card-wide revision rule does not implement field merging, a server transaction, durable drafts, or restoration.

## Recorded host evidence

Observed compiler: Apple Swift 6.4.2 (`swiftlang-6.4.2.1.9 clang-2100.4.1.1`), host target arm64-apple-macosx26.0. Xcode 27.2 build 27B52. On 17 November 2026 this exact command passed:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/ios-learning-interface-modules SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/ios-learning-interface-modules swift test --disable-sandbox --package-path course/labs/InterfaceProject --scratch-path /private/tmp/ios-learning-interface-build --cache-path /private/tmp/ios-learning-interface-cache
```

**8 XCTest tests, 0 failures**, rerun on 17 November 2026 after the revision fix: invalid drafts do not mutate published values; valid save changes 40 to 45; stale drafts cannot undo pin; deletion makes route/save missing; duplicate IDs fail; column and gesture equality/direction boundaries hold. New checks compare the entire cards array after repeated exhausted Saves and both Pin directions, retain the draft, permit the last safe increment via either operation, reject later operations without mutation, preserve stale-conflict precedence, and return missing for an absent Pin. The initial command without explicit module-cache redirection failed on an unwritable default cache. User-level SwiftPM config/security warnings remain environmental; the corrected suite exited 0. `bash -n` passed for the reproducible wrapper:

```sh
bash course/labs/InterfaceProject/verify-host.sh
```

## Native source check

```sh
python3 course/labs/InterfaceProject/check-native.py
```

Executed with exit 0 on 17 November 2026, and rerun with exit 0 after adding the explicit Save/Pin outcomes and exhaustive native handlers. It prints exact commands, emits InterfaceCore for arm64-apple-ios17.0-simulator, then typechecks InterfaceApp with iPhoneSimulator27.2.sdk, Swift 6 language mode, and temporary module caches. The first manual attempt hit sandbox-exec denial in bundled SwiftUI compiler plugins; `swiftc -disable-sandbox` resolved this environment issue. A subsequent real compile error revealed accessibilityReduceMotion is read-only in this SDK. The preview now follows the system setting; no writable environment override is claimed. The SDK uses compiler macro support for State and previews.

This check proves module visibility, syntax, and framework availability for the selected destination. It does not link/package/sign an app, run previews, launch a simulator, move real focus, or collect performance evidence.

## Create a separate scratch Xcode app

1. Create a new iOS App with SwiftUI and Swift, no storage template, minimum iOS 17, and a scratch bundle identifier. Save outside the company client. Keep distribution signing out of this simulator exercise.
2. Add this directory as a **local package** and select the **InterfaceCore** product for the app target.
3. Remove the template's app entry and ContentView from target membership. Add a copy of **Native/InterfaceApp.swift** to the app target. This file supplies the only `@main`. Do not copy package Sources or Tests into app membership; SwiftPM supplies the core.
4. Build for a recorded simulator destination, launch, and compare against the known fixture. Retain exact Xcode build/launch evidence separately from the source check above.
5. Use simulator Settings → Accessibility → Motion → Reduce Motion for motion observations. The preview reads the actual system value. Accessibility-sized text preview is a convenience, not an executed accessibility result.

## Pending interaction and profiling acceptance

All following rows are **pending**: app assembly/launch, invalid-field focus, Cancel/Save/sheet/keyboard Done, hardware keyboard, separate VoiceOver Open and Pin, error announcement, switch access, long text, narrow/wide/split region, right-to-left appearance, contrast, native drag/scroll arbitration, and reduced-motion interaction. Source and host tests do not substitute for them.

Known sequence: start 40; invalid title and 241 stay 40; valid Blue=20 yields 45; pin leaves 45; delete Blue yields 25 and a missing detail. Check control identifiers (`open-blue`, `pin-blue`, `draft-title`, `draft-minutes`, `save-draft`, `board-total`) semantically rather than with fixed screen coordinates.

For a separate scratch native boundary fixture, construct Blue with `revision: Int.max`. Save must retain the sheet and draft, clear input focus, and display `draft-error` without changing any card. Return to the board and request Pin via each supported action: `pin-error` should explain rejection and the pin state must remain unchanged. These message/focus/action observations are **pending**; the host suite establishes the full-state failure contract and native typechecking establishes API acceptance only.

For profiling, make a scratch deterministic 1,000-card fixture with unique IDs and long/short titles. Define a fixed scroll interval, optimized build, named representative device/OS, content size, warm/cold policy, repeated raw samples, and correctness oracle before recording Time Profiler/animation data. Keep original trace files and baseline. No device trace, timing, energy, memory, or speedup was measured here. A cached total must equal recomputation after every mutation/failure; reject a faster candidate that fails correctness. Optional later lessons 036–042/101–104 deepen this work.

Independent learner extension: add notes with a clear length/input policy, preserve all-or-error publication and stale-revision rejection, map its invalid result to native input focus, and gather your own bounded observations. Neither the reference source nor its worked answer records learner completion. Keep the experiment isolated from the client and retain your diff and verification evidence for review.
