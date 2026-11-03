# Across the Stack — Android to iOS

A private, local course for an experienced Android engineer starting iOS. Nineteen chapters contain 112 detailed sessions: 14 beginner Swift lessons, 14 beginner SwiftUI lessons, 28 core lessons, 28 deep dives, 24 advanced practice sessions and four specialist entry electives. Lessons include Kotlin/Java comparisons with explicit boundaries, explained quizzes, worked exercises and repository connections.

The 3 November teaching revision starts each lesson, Swift details guide and practice workbench with an everyday story. A small picture shows the parts or steps. A before/change/after example gives you a result to predict. New technical words have nearby definitions. Each introduction ends with one sentence to remember and explains where its story stops matching the real platform. The deeper mechanics, Android comparisons, code, failure cases and exercises follow. Short, familiar sentences help you learn the idea before meeting several unfamiliar terms at once.

The 29 October expansion repaired the language-first progression and connected teaching to implementation. It introduced six paths covering Swift, SwiftUI, mixed UIKit delivery, production engineering, staff practice and principal platform practice, plus eleven guided workbenches with a standalone Swift package, an isolated Xcode app, synthetic regression tooling and a costed multi-team design review. The original 001–056 lesson IDs, quizzes and checklist order remain stable; teaching prose and worked answers were corrected where the audit found gaps. Saved-progress hash contracts prevent accidental quiz/checklist changes during future builds.

The 2 November expansion adds sessions 085–112 without changing earlier quizzes, checklists or interview identities. Eight paths and eighteen guided workbenches connect event processing, practical synchronization, modern Swift concurrency, UI runtime mechanics, durable recovery, integrated profiling and delivery review. The specialist path introduces concrete feature contracts for commerce/live updates, cloud documents, text/media/graphics/inference and additional Apple platforms; deeper framework-specific projects remain elective.

The Coverage map audits 173 topics in 14 areas, including beginner syntax, controls, preview fixtures, dependencies, persistence and principal-level adoption decisions. It labels explanation, available practice and specialist further study separately, with links to concrete companions. The Libraries & pins page inventories 52 remote dependency entries across the Tuist and legacy workspace pin graphs, including 23 direct Tuist declarations. It distinguishes resolution from runtime use and is not an exhaustive catalogue of local/vendor/system frameworks. A course cannot exhaust every Apple API or certify mastery from reading.

Swift details adds three supplementary guides for initialization/access/properties, generic and associated-type contracts, and legacy callback/observer/queue ownership. Each has worked exercises and explained self-directed knowledge checks, linked from the relevant lessons. They are not extra numbered sessions and do not change saved progress or quiz indices. Search includes paths, workbenches and the full guide explanations.

The Interview ledger contains 224 prompts (two per lesson), observable rubrics, explained model answers, Android analogy boundaries, follow-ups and common mistakes. Every numbered lesson ends with interview rehearsal and a recap-quiz link. Mock rounds cover beginner Swift and SwiftUI as well as foundation, UI, concurrency/data, performance, tooling, platform, staff design, principal strategy and cross-platform handoff. Each full agenda reserves setup and debrief time within its advertised duration. The quiz studio samples 10/20/30 questions from the numbered-lesson bank or the smaller set available in a chosen lesson/chapter; it grades only multiple-choice answers. Supplemental workbench/guide checks reveal reasoning without changing stored quiz history.

## Open the course

Open the offline reader directly in Chrome from normal macOS Terminal:

```sh
open -a "Google Chrome" "/Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/index.html"
```

This is the working access path in this workspace. All course data is embedded in the bundled `data.js`; no fetch, CDN, fonts, account, server, or connection is required for reading. Source files open through local file links in this mode, and line jumping depends on the browser. Official documentation links require an internet connection. If clicking the HTML inside Codex opens an editor, the command above opens the browser instead.

Optional: on a machine that allows local listening, run this from `/Users/manjul.kadyan/StudioProjects/zocdoc/mobile`:

```sh
node ios-learning/course/serve.mjs
```

Then open `http://127.0.0.1:4173` while that process is running. The dependency-free, read-only server binds only to loopback and renders source with line anchors. Stop it with Ctrl+C; set `IOS_COURSE_PORT` for a different port. A refused localhost connection means the server is not listening; it does not prevent offline reading.

If you already have the course open, reload the same page after the expansion. Keeping the same file/origin preserves that browser's existing progress; export a backup before switching origins.

## How to learn

For a fresh language-first start, choose **Learn Swift** (057–070), then **Learn SwiftUI** (071–084), then the mixed-framework and production paths. The higher IDs preserve the older course's storage identities; they do not indicate prerequisites in the teaching sequence. The initial continue card still points to session 004 because sessions 001–004 were delivered in the mentor log. No exercises or competencies were marked complete, and the saved reading position is not reset.

Read the explanation, follow its source connections, attempt the knowledge checks and exercise, then expand the worked answer. Complete the reflection checklist and confirm that you attempted the exercise before marking a session reviewed. A reviewed session is your own assessment; it is not mentor verification or a qualification.

Begin with **The idea in everyday words**. Describe its picture out loud, then predict the small example's final state. Read **New words, explained** before the technical sections. Ordered pictures show a flow or timeline; comparison pictures show alternatives rather than an execution order. Every picture has a text caption and labelled parts, works offline and uses the same light/dark theme as the reader. Search also finds the stories, picture labels and word definitions. Use **A story and a picture** in the page's contents to return to the introduction.

Keep a 45-minute daily habit: five minutes of recall, ten of explanation, ten of tracing a scratch example or repository connection, fifteen of independent practice and five of reflection. Per-session estimates include hands-on work; spread longer topics across multiple days. The original core follows the sixth-session lab/seventh-session review rhythm. Beginner and deep-dive chapters have their own integrated work and evidence reviews; do not assume the same calendar pattern. The course supports an ongoing delivery portfolio, not a fixed completion date or guaranteed staff/principal title.

Use Cmd/Ctrl+K to search lesson text and comparisons. Bookmark useful sessions. Keep notes inside a session, find them on the notes page, and export a JSON backup before changing browsers or addresses. The light/dark theme and print view support longer reading sessions.

Use Coverage map to choose depth by topic and inspect explicit gaps. Use Libraries & pins to search dependency names/purposes, inspect exact graph evidence and compare direct declarations. A version pin is a checkout fact, not the latest version or an upgrade recommendation. Use sessions 043–049 for variants, library contracts and bounded migration practice.

Staff practice asks for bounded cross-feature decisions, implementation quality, measurable improvements and team enablement. Principal practice adds multi-team product contracts, investment/no-change alternatives, compatibility, adoption incentives, exception ownership, deprecation and sustained operational accountability. Read the worked strategy, change its constraints, defend a different recommendation and revise it after independent feedback. Neither path is a promotion checklist.

After the relevant core lessons, choose **Runtime and production practice** for sessions 085–108. Work through event loops/scheduling, Swift concurrency migration, UI internals/lifecycle, durable data/authentication, profiling, then delivery and leadership. The updated production, delivery, staff and principal paths link the additions relevant to each responsibility. Choose **Apple feature electives** (109–112) according to product needs. Each long session may span several 45-minute days; reading its answer does not complete its implementation or review.

## Runnable companions

Open **Practice workbenches** to read setup, line-by-line reasoning, independent changes, acceptance evidence, worked answers and quizzes. Complete source text is bundled for offline inspection; opening a source link does not execute it.

- `labs/SwiftLanguageLab/`: remote-dependency-free Swift 6 package. Covers language contracts, event-gated concurrency, stale success/error rejection, account epochs, per-consumer cancellation, work limits, Unicode/locale/time and isolated file failure fixtures. Follow its README's unique temporary-cache commands.
- `labs/SwiftUIWorkbench/`: separate iOS 17+ Xcode app and widget extension. Covers SwiftUI controls, styles/environment, state and navigation, UIKit diffable/bridge behavior, Core Data and SwiftData CRUD, and real platform adapter boundaries. Use synthetic data. Permission requests, notification scheduling and camera/location actions require explicit learner interaction; authentication is deliberately not started without a reviewed provider.
- `labs/MeasurementLab/`: first-capture signpost and retention examples, artifact/debugging commands, an executable synthetic regression evaluator and a multi-team platform decision. Invented numbers demonstrate decision rules, not production performance.
- `labs/RuntimeLab/`: RunLoop eligibility, dispatch/operation completion, synchronous synchronization and bounded-worker fixtures. A host RunLoop probe is separate from the UIKit display-link exercise.
- `labs/ConcurrencyMigrationLab/`: compiler diagnostics/settings cases, transfer and ownership boundaries, an injected clock, task context and a cancellation-aware demand channel. Check its explicit compiler and OS requirements.
- `labs/UIRuntimeLab/`: an isolated native UI target for dispatch/KVO, layer animation, advanced layout and lifecycle/routing practice, with host checks for pure contracts.
- `labs/DurableDataLab/`: persisted outbox/restart/replay fixtures, synthetic authentication, actual Apple-store migration exercises and separate Keychain/protected-data checks. Mock vault and file-envelope evidence does not certify real Keychain or database behavior.
- `labs/ProfilingLab/`: an instrumented native workload wired into its scratch target, plus raw-record validation. Capture and retain your own device traces; synthetic records exercise rules only.
- `labs/DeliveryLab/`: runnable evidence/identity validation with changed-constraint fixtures and an independent-review/revision exercise. It does not sign, upload or distribute an app.
- `labs/SpecialistLab/`: bounded synthetic specialist policy practice and a feature-selection exercise. Store, cloud, health, hardware and additional-platform integration need their own sandbox/device evidence.

A successful host test, native build, observed UI interaction, device trace and organizational review are different evidence. Supplied code and instructor verification do not complete your exercise. Record your environment, actual command/result, changed fixture and remaining uncertainty in the related session notes.

## Interview practice and ledger

Open Interview ledger in the sidebar. Filter by chapter, Foundation/Senior/Staff, search, bookmark or practice state. Explain the prompt without hints, then reveal its rubric and model answer. Record a response, optional self-score (0–4), time spent, feedback, a concrete next action and an optional next-review date. Drafts save separately from immutable attempt history. A high self-score is not mentor verification, a hiring prediction or a staff qualification. Review dates use Asia/Calcutta and form a manual queue; no automation is activated.

Mock rounds are suggested printable agendas, not a live interviewer or running timer. Record each selected prompt in its own question ledger. Use a colleague or mentor for independent challenge and retain feedback. The final quiz studio saves unfinished choices, checks completed answers against the actual lesson keys, and keeps explained results. Interview/quiz practice never marks original lesson quizzes or completion as passed.

History is bounded to 20 attempts per question and 30 finished quizzes. Each answer is limited to 5,000 characters, feedback to 2,000 and next action to 500. At a history limit the reader refuses a new record instead of deleting older evidence. Clearing question or finished-quiz history requires an explicit confirmation naming the scope; export first, since recovery requires your backup. Replacing an unfinished quiz also asks for confirmation. Storage quotas may be smaller than the supported content limits; a storage warning means you should export before closing.

The existing progress export now also includes the separate interview ledger. Old lesson-only backups remain importable without erasing interview work. Imports validate both sections before changing in-memory state, deduplicate immutable attempts/results by ID, and reject conflicting drafts/IDs rather than overwriting answers. The size allowance scales with bounded lesson notes and interview text; it does not promise that browser localStorage can hold a worst-case full ledger.

## Local progress

Notes, bookmarks, quiz answers, checklists, theme, and reviewed sessions use browser localStorage. They are scoped to the browser and origin; the direct file reader and `127.0.0.1` can have separate storage. If storage is denied, the reader shows a warning and still keeps the current state in memory so you can export it.

Export from the notes page or footer. Import merges known sessions and preserves existing notes; only validated plain-text fields and known answer/checklist indices are accepted. There is no automatic synchronization with `ios-learning/PROGRESS.md`, no account, no analytics, and no hosted publication. The daily scheduler remains unactivated; the website does not schedule notifications.

Imports retain partial quiz/checklist work. When answers conflict, existing local answers take precedence unless an imported, validated review supplies a complete set. A fresh reader also restores the backup's theme and last session. Notes are limited to 100,000 characters per session; an oversized merge is rejected without changing current progress. The bounded backup-size allowance scales with the number of lessons so a valid full export remains importable. Browser storage quotas still vary; use export if storage is unavailable.

## Maintain the course

Source content is in `content/unit-01.json` through `unit-19.json`, with stable ranges/tracks and explicit interview/practice bank registration in `content/manifest.json`. Reading order is in `content/paths.json`; workshop teaching and explicitly exposed artifact paths are in the registered `content/practice-*.json` files. The reference comparisons and syntax table are in `content/reference.json`; the audit is in `content/coverage.json`; supplementary Swift guides are in `content/essentials.json`. Interview prompts are in the registered `content/interview-*.json` banks; agendas are in `content/interview-rounds.json`. `inventory.mjs` reads the two checked-in remote pin graphs and Tuist declarations without changing the client. The authoring format is documented in `CONTENT_SPEC.md`.

After a content change:

```sh
node ios-learning/course/build.mjs
node ios-learning/course/build.mjs --check
node ios-learning/course/check-teaching.mjs
node --check ios-learning/course/app.js
node --check ios-learning/course/state.js
node --check ios-learning/course/serve.mjs
node ios-learning/course/test.mjs
node ios-learning/course/test-reader.mjs
node ios-learning/course/test-interview.mjs
node ios-learning/course/labs/MeasurementLab/test-evaluate.mjs
```

The builder validates ranges, lesson order, both the original 56-session and pre-expansion 84-session quiz/checklist hashes, essential fields, references, teaching depth, safe HTML, prerequisites, coverage/path/guide/workbench links, mock-round timing and repository path/line existence. It also requires the story/example/picture/vocabulary structure for all 133 teaching pages. `content/progress-plain-contract.json` preserves the existing assessments, section identities and code blocks for all 112 lessons, 18 workbenches and three guides, plus interview identities/timing/code. `check-teaching.mjs` can check one author's registered files, for example `node ios-learning/course/check-teaching.mjs unit-09.json unit-10.json`, while other authors are still working. Artifact paths must resolve to bounded text files inside `labs/`; only declared sources enter the bundle/server allowlist. SHA-256 digests identify bundled source snapshots. Generated `data.js` may be refreshed by the builder; edit source files rather than the bundle.

The units were authored/audited in parallel with disjoint files, then reviewed and integrated. The core anchors were checked on 26 October 2026; expanded anchors and remote dependency graphs were checked on 27 October 2026. Verify target membership and current line numbers if sources change. Code examples are teaching material; UIKit/SwiftUI examples require suitable iOS targets, and an isolated Swift run does not establish that the main app builds.

The audit distinguishes guide prose from active code: ZDRxCore exports ReactiveKit despite RxSwift wording in the repository guide, and PromiseKit remains used despite migration preferences. The two pin graphs differ in presence and selected revisions/versions. Build lessons distinguish main-app and demo deployment floors, Swift tools versus language mode, environment flags versus Debug, and inspected Android flavors versus guide-only descriptions. Thermal/power/memory-pressure decisions have explicit fixture and device-evidence boundaries.

## Verification and limits

The validator checks safe HTML, teaching depth, source anchors, all path/guide/workbench connections, explained assessments, interview rubrics and honest full-round budgets. `test.mjs` checks progress rules, the original 56-session and pre-expansion 84-session storage contracts, old backups, artifact containment/digests/source equality, pin anchors and the read-only HTTP handler without opening a port. `test-reader.mjs` exercises every lesson, guide, path, workbench, artifact and interview route in a controlled DOM adapter, including anchors, local-file links, escaping, search, storage and transactional backups. `test-interview.mjs` checks history, bounds, dates, grading, new quiz-bank scopes and preservation of old history. These do not establish real-browser layout or native interactions.

Integrated checks on **3 November 2026** passed for the plain-language revision: build/check, source checks across all **41 registered teaching/interview files**, **1,879 state/handler/artifact/wiring checks**, **1,941 controlled-DOM reader checks**, **65 interview-ledger checks**, and syntax checks for all eight changed JavaScript files. The reader was rebuilt from the final sources. Its **112 lessons, 18 workbenches and three guides** each have a unique everyday story, a concrete before/change/after example, a captioned illustration and defined vocabulary. The pictures include 52 flows, 43 comparisons and 38 timelines. All 841 technical-section openings were revised. Technical teaching remains substantial: every page retains at least 1,129 words of non-code explanation across its sections and worked answer. All **224 interview questions** have clearer prompts, scenarios, answers and review criteria.

The new preservation baseline matches the starting commit, `b2b5978`, for every existing quiz/checklist payload, section ID, displayed code block and interview identity/time budget. Existing notes, unfinished answers, reading position and interview history remain compatible. Tests also check that the new plain-text stories and picture labels are escaped, searchable offline and linked to their captions. The course does not mark any learner exercise complete.

Thirteen authors worked in separate file scopes. Two independent reviewers checked every rewritten lesson, guide, workbench and interview question against the starting sources. Review corrected a Swift explanation that confused `Sendable` conformance with the `async throws` method contract, and clarified the UI workbench's different coordinates before and after wrapping. Interview review added missing definitions for sign-in `state`, PKCE and `nonce`, qualified layout coordinates for both offered widths, and explained the p95 rounding formula with exact values. All five findings were resolved and rechecked; neither reviewer has outstanding findings. The author commits and review fixes are recorded below; the reader, supplementary guides, validation contract and generated bundle are integrated in a separate commit.

| Author | Content scope | Commit |
|---|---|---|
| Jason | Lessons 001–014 | `bcdc125` |
| Ptolemy | Lessons 015–028 | `0577330` |
| James | Lessons 029–042 | `27cffb1` |
| Gauss | Lessons 043–056 | `787f7d5` |
| Mencius | Swift lessons 057–070 | `3565ccd` |
| Carver | SwiftUI lessons 071–084 | `6b5bfe5` |
| Russell | Runtime/concurrency lessons 085–092 | `18f1838` |
| Averroes | UI/durable-data lessons 093–100 | `b1e7014` |
| Goodall | Profiling/delivery/electives 101–112 | `42046c7` |
| Descartes | Original eleven workbenches | `51bf5d5` |
| Gibbs | Seven advanced workbenches | `d1ebfba` |
| Dewey | Interview questions for 001–056 | `70af66f` |
| Fermat | Interview questions for 057–112 | `7d9e3ac` |
| Heisenberg review → integration fix | `Sendable` versus `async throws` | `19d39d2` |
| Boole review → integration fix | Wrapped-row example coordinates | `2f2bb83` |
| Heisenberg review → integration fix | Sign-in `state`, PKCE and `nonce` definitions | `ff9609f` |
| Boole review → integration fix | Layout widths and nearest-rank p95 arithmetic | `ecb1129` |

A headless attempt with the installed Chrome exited with code 134 before producing a screenshot. Real-browser layout, mobile rendering and print appearance remain unverified; the pictures have controlled-DOM and source validation only. No native or production-client code changed in this revision, and native suites were not rerun. Earlier native-build and host evidence below retains its original date and limits.

Integrated checks on **2 November 2026** passed for the full 112-session expansion: build/check, **1,387 state/handler/artifact/wiring checks** (170 source viewers), **1,466 controlled-DOM reader checks**, **65 pure interview-ledger checks**, the **13-test synthetic regression evaluator**, and JavaScript syntax checks. The current bank contains **345 numbered-lesson MCQs**, **63 explained supplemental checks**, **224 interview prompts** and **18 mock rounds**. All 001–084 quiz/checklist payload hashes match the pre-expansion baseline; tests preserve existing notes, unfinished work, reading position and interview history without marking new lessons complete. Every declared companion file is available through the offline artifact reader and the optional read-only handler, including Python and shell source shown as text. Undeclared files remain unavailable.

Seven authors supplied disjoint units and companions; two independent reviewers examined the additions. Review found and corrected double RTL reflection in the SwiftUI layout exercise and a durable-outbox rebase that could reorder dependent edits. The layout helper now leaves direction-aware placement to SwiftUI. The bounded conflict resolver replaces a single pending edit in its original queue position with a fresh identity; unsupported dependent edits and failed writes preserve the queue and stored bytes. The affected host checks, teaching answers and source snapshots were updated, and the reviewers rechecked the corrections.

The new companion READMEs retain exact author commands, results and evidence boundaries. Runtime scheduling/synchronization/CPU/file fixtures passed on the host, and the UIKit display-link source typechecked. The Swift concurrency lab passed 13 tests, 14 compiler diagnostic/settings cases and 14 snippets. UI runtime host geometry/routes and KVO checks passed, and its corrected native simulator target built with the documented compiler-helper flag. Durable-data checks exercised actual Core Data and SwiftData on-disk migrations, separate-process replay, synthetic OAuth/vault failure policies and context ownership; the rebase regression passed separately after review. Real Keychain access and protected-device behavior remain pending. The profiling target built in Release, host semantic and raw-record checks passed, and binary/dSYM UUIDs matched. Delivery passed 25 Python contract tests and Swift examples; specialist practice passed 12 synthetic policy tests and standalone Swift examples. The actual lesson 109 StoreKit snippet also typechecked in Swift 6 for an iOS 17 simulator target against SDK 27.1 without diagnostics; no purchase or entitlement interaction ran.

These results establish content integrity, bounded host behavior and compilation for the named targets. New native UI interaction, device Instruments traces, thermal/energy observations, authentication/Keychain integration, cloud/store/hardware behavior, installation/upgrades and independent organizational acceptance remain learner work. CoreSimulator services were unavailable during authoring; the native builds did not launch an app. Real-browser layout and screenshot checks remain unexecuted. The earlier dated evidence below is retained as history, rather than represented as a new run.

Integrated checks on 29 October 2026 passed: full 84-session build/check, 891 state/handler/artifact/wiring checks (153 source viewers), 993 controlled-DOM reader checks and 49 pure interview-ledger checks. The bank contains 260 numbered-lesson MCQs plus 42 explained supplemental checks. All 56 original quiz/checklist payload hashes match the pre-expansion bundle; old notes, partial quizzes and interview history remain compatible. The two beginner mock rounds now fit a 45-minute block. No learner work or production measurement was pre-completed.

Companion evidence: 32 host Swift tests across five suites passed on Apple Swift 6.4; the synthetic evaluator passed 13 tests. The standalone iOS 17+ app and embedded widget extension built successfully with Xcode 27.1 / simulator SDK 27.1. The ordinary nested macro sandbox failed in this environment; the documented compiler-helper workaround passed inside the outer sandbox. Native source retains Swift 5 language mode; the host package uses Swift 6. Parser fixtures accepted three supported routes and rejected fourteen hostile/unsupported forms, and plist/project lint passed. These compile, host and fixture results do not imply runtime acceptance.

Teaching-example evidence from the authors: all 55 runnable Swift bootcamp examples compiled and ran in Swift 6 mode on macOS; the session 070 scratch package passed five tests. Three intentional compiler failures were checked separately; runtime traps were not executed. All 16 non-test SwiftUI snippets and both capstone test blocks type-checked in Swift 5 mode against simulator SDK 27.1 with an iOS 17 target. Hosted XCTest/UI-test execution, linking and launch of those lesson examples remain unexecuted. Minimum toolchains, Linux and live official-reference availability were not verified; reference fetching was blocked by DNS. Recheck changing APIs/policies against official documentation when online.

The current validation uses the offline reader and read-only handler, not a listening localhost server. The earlier sandbox blocked local listening/browser launch, and an installed Playwright package was not available to this integration. Real-browser layout, mobile/print and screenshot checks remain unexecuted. The native companion builds for the simulator SDK, but simulator services are unavailable: app launch, preview rendering, CRUD/relaunch, permissions, hardware, accessibility and widget interaction remain pending. No production-client build, provider authentication, Instruments/device measurement, signing or distribution was performed.

For optional browser checks, supply an already installed Playwright package. The verifier defaults to the same offline HTML file:

```sh
IOS_COURSE_PLAYWRIGHT=/absolute/path/to/node_modules/playwright/index.mjs node ios-learning/course/verify.mjs
```

If that package has no bundled browser, also set `IOS_COURSE_BROWSER_PATH` to your installed Chrome executable. To include HTTP source-viewer checks, start the optional server and set `IOS_COURSE_URL=http://127.0.0.1:4173/`. The verifier uses a separate temporary profile, checks all numbered sessions plus paths/workbenches/artifacts and ledger behavior, and writes screenshots under `/private/tmp/ios-course-preview`. It does not download packages or touch your normal browser progress.

## Files

- `index.html`, `styles.css`, `app.js`, `state.js`: the offline reader and progress rules
- `interview.js`, `interview-state.js`: interview/quiz UI and bounded, separate practice history
- `data.js`: generated course and reference bundle
- `build.mjs`: dependency-free validation and bundling
- `teaching.mjs`, `check-teaching.mjs`: story/picture checks and preservation of the existing teaching contracts
- `inventory.mjs`: read-only remote dependency and graph snapshot
- `serve.mjs`: loopback server and bounded source viewer
- `content/`: maintainable course source units
- `verify.mjs`: optional browser smoke checks using an installed Playwright package
- `test.mjs`: dependency-free state, HTTP-handler, and wiring checks
- `test-reader.mjs`: app route/event checks using a controlled DOM adapter
- `test-interview.mjs`: pure interview history, score, bounds, date and backup checks

Use the existing `ios-learning/examples/` Swift examples for sessions 001–004. Production client code was not changed by creating this course.
