# Across the Stack — Android to iOS

A private, local course for an experienced Android engineer starting iOS. Eight chapters contain 56 detailed sessions: 28 core lessons and 28 deep dives, with Android comparisons, explained quizzes, worked exercises, active repository anchors, and a cross-platform field guide.

The original core has about 46,000 teaching words, 29 comparison entries, and 22 syntax mappings. After the 27 October 2026 audit, the numbered lessons contain 103,176 teaching words, with another 4,204 in the Swift supplements (counts include examples). The expansion adds deeper UI engineering, performance/optimization, libraries/build variants/tooling, and platform systems. It keeps every original lesson ID, question, and exercise unchanged.

The new Coverage map audits 118 topics in 14 areas. It labels explanation, available practice, and specialist further study separately. The Libraries & pins page inventories 52 remote dependency entries across the Tuist and legacy workspace pin graphs, including 23 direct Tuist declarations. It distinguishes resolution from runtime use and is not an exhaustive catalogue of local/vendor/system frameworks. A course cannot exhaust every Apple API or certify mastery from reading.

Swift details adds three supplementary guides for initialization/access/properties, generic and associated-type contracts, and legacy callback/observer/queue ownership. These are detailed references with worked exercises, not extra numbered sessions. They do not change existing progress or quiz indices. Search includes their full explanations.

The Interview ledger adds 112 original interview prompts (two per lesson), observable rubrics, explained model answers, Android analogy boundaries, follow-ups and common mistakes. Each lesson ends with interview rehearsal and a recap-quiz link. Eight mock-round agendas cover foundation, UI, concurrency/data, performance, tooling, platform, staff design and cross-platform handoff. The quiz studio samples 10/20/30 questions from the existing 176-question bank or the smaller set available in a chosen lesson/chapter; it grades only multiple-choice answers.

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

Start with the learning desk or a session from the sidebar. The initial continue card points to session 004 because sessions 001–004 were delivered in the mentor log. No exercises or competencies were marked complete.

Read the explanation, follow its source connections, attempt the knowledge checks and exercise, then expand the worked answer. Complete the reflection checklist and confirm that you attempted the exercise before marking a session reviewed. A reviewed session is your own assessment; it is not mentor verification or a qualification.

Keep a 45-minute daily habit. Per-session estimates include explanation, tracing, and hands-on practice; spread longer topics across multiple days rather than rushing. Use session 001 for a fresh start. The original core follows the sixth-session lab/seventh-session review rhythm. Deep-dive chapters have their own integrated labs and evidence reviews; do not assume the same calendar pattern. The course supports an ongoing delivery portfolio, not a fixed completion date or guaranteed staff title.

Use Cmd/Ctrl+K to search lesson text and comparisons. Bookmark useful sessions. Keep notes inside a session, find them on the notes page, and export a JSON backup before changing browsers or addresses. The light/dark theme and print view support longer reading sessions.

Use Coverage map to choose depth by topic and inspect explicit gaps. Use Libraries & pins to search dependency names/purposes, inspect exact graph evidence and compare direct declarations. A version pin is a checkout fact, not the latest version or an upgrade recommendation. Use sessions 043–049 for variants, library contracts and bounded migration practice.

The course is a foundation for increasingly independent iOS contributions. Staff-level capability requires repeated delivery, sound architecture decisions, measurable outcomes, and influence over time.

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

Source content is in `content/unit-01.json` through `unit-08.json`, with stable ranges/tracks in `content/manifest.json`. The reference comparisons and syntax table are in `content/reference.json`; the audit is in `content/coverage.json`; supplementary Swift guides are in `content/essentials.json`. Interview prompts are in `content/interview-core.json` and `interview-deep.json`; agendas are in `content/interview-rounds.json`. `inventory.mjs` reads the two checked-in remote pin graphs and Tuist declarations without changing the client. The authoring format is documented in `CONTENT_SPEC.md`.

After a content change:

```sh
node ios-learning/course/build.mjs
node ios-learning/course/build.mjs --check
node --check ios-learning/course/app.js
node --check ios-learning/course/state.js
node --check ios-learning/course/serve.mjs
node ios-learning/course/test.mjs
node ios-learning/course/test-reader.mjs
node ios-learning/course/test-interview.mjs
```

The builder validates manifest ranges, lesson order, essential fields, question indices, references, teaching depth, safe HTML, prerequisites, coverage links, and repository path/line existence. It emits the offline `data.js` bundle with the dependency snapshot. Generated output may be refreshed by the builder; edit the JSON sources rather than the bundle.

The units were authored/audited in parallel with disjoint files, then reviewed and integrated. The core anchors were checked on 26 October 2026; expanded anchors and remote dependency graphs were checked on 27 October 2026. Verify target membership and current line numbers if sources change. Code examples are teaching material; UIKit/SwiftUI examples require suitable iOS targets, and an isolated Swift run does not establish that the main app builds.

The audit distinguishes guide prose from active code: ZDRxCore exports ReactiveKit despite RxSwift wording in the repository guide, and PromiseKit remains used despite migration preferences. The two pin graphs differ in presence and selected revisions/versions. Build lessons distinguish main-app and demo deployment floors, Swift tools versus language mode, environment flags versus Debug, and inspected Android flavors versus guide-only descriptions. Thermal/power/memory-pressure decisions have explicit fixture and device-evidence boundaries.

## Verification and limits

The integrated content validator checks HTML tag balance, safe attributes, prerequisites, coverage/guide links, interview IDs/rubrics/answer depth, mock-round links and source anchors. `test.mjs` checks progress rules, preservation of original-course backups, remote pin identity anchors and the actual read-only HTTP handler without opening a port. `test-reader.mjs` executes the reader against a controlled DOM adapter, covering every lesson, guide and interview route, events, interview drafts/history, final-quiz scoring, transactional combined-backup validation, coverage/library filtering and notes persistence/escaping. `test-interview.mjs` checks pure ledger bounds, dates, history, self-assessment status, quiz grading and merge/conflict rules. These tests do not provide real browser behavior or visual verification. Unit authors also checked selected lesson snippets; interview content reuses lesson evidence rather than establishing new compiler/device results.

Integrated checks after the interview addition on 27 October 2026 passed: full content build/check, 579 state/handler/wiring checks (147 source viewers), 522 controlled-DOM reader checks and 38 pure interview-ledger checks. The interview addition did not edit the 56 lesson sources or their quiz indices. During the earlier depth expansion, all 28 original lesson payloads were also compared with the previously delivered bundle and matched exactly. No learner exercise or production measurement was pre-completed.

This Codex session's sandbox blocked binding a local server port and launching a browser. Real-browser layout, interaction, mobile, print, and screenshot checks were therefore not completed, and the server is not currently running. The handler tests are not a substitute for those checks. No main iOS app build or device audit was performed.

For optional browser checks outside that restriction, start the local server, then supply an already installed Playwright package:

```sh
IOS_COURSE_PLAYWRIGHT=/absolute/path/to/node_modules/playwright/index.mjs node ios-learning/course/verify.mjs
```

If that package has no bundled browser, also set `IOS_COURSE_BROWSER_PATH` to your installed Chrome executable. The verifier uses a temporary browser profile, checks all sessions and the coverage/library routes, and writes screenshots under `/private/tmp/ios-course-preview`. It does not download packages.

## Files

- `index.html`, `styles.css`, `app.js`, `state.js`: the offline reader and progress rules
- `interview.js`, `interview-state.js`: interview/quiz UI and bounded, separate practice history
- `data.js`: generated course and reference bundle
- `build.mjs`: dependency-free validation and bundling
- `inventory.mjs`: read-only remote dependency and graph snapshot
- `serve.mjs`: loopback server and bounded source viewer
- `content/`: maintainable course source units
- `verify.mjs`: optional browser smoke checks using an installed Playwright package
- `test.mjs`: dependency-free state, HTTP-handler, and wiring checks
- `test-reader.mjs`: app route/event checks using a controlled DOM adapter
- `test-interview.mjs`: pure interview history, score, bounds, date and backup checks

Use the existing `ios-learning/examples/` Swift examples for sessions 001–004. Production client code was not changed by creating this course.
