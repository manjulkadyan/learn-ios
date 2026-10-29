# iOS learning progress

## Current state

- Learner: Android engineer with 7–8 years of experience; beginning iOS.
- Updated: 27 October 2026, Asia/Calcutta (course-library expansion only; learner exercise status unchanged).
- Current session: 004 — ARC and capture lists.
- Status: session 004 plan delivered manually at the learner's request; exercises for sessions 001–004 awaiting learner response.
- Completed sessions: none yet.
- Next lesson on request or after acceptance: 005 — Xcode targets/schemes, SPM, and Tuist.
- Recurring automation: not created/activated; scheduler tools unavailable.

## Local learning library

- Created 26 October 2026: [Across the Stack course](course/index.html), with 28 detailed core sessions and a searchable Android-to-iOS reference guide. [Opening and backup instructions](course/README.md).
- The initial browser continue card points to session 004 to reflect the current mentor log; all sessions can be read from the sidebar, including 001 for a fresh start.
- Course availability does not count as delivery, exercise acceptance, or completion. Sessions 001–004 remain pending exactly as recorded below.
- Browser quizzes, notes, and self-reviewed sessions are local to that browser and do not automatically update this mentor log. Submit exercise evidence for mentor review separately.
- Keep a 45-minute daily habit; longer lessons and labs may span multiple days. No recurring automation was created by this work.
- Library expanded 27 October 2026: 56 sessions, with unchanged core content/IDs and 28 additional deep dives. Coverage map includes 118 topics and explicit specialist study branches; Libraries & pins includes both checked-in remote dependency graphs. Availability is not delivery or completion, and all previously pending learner work stays pending.
- Interview practice added 27 October 2026: two prompts per course lesson, model answers/rubrics, eight mock-round agendas and a separate answer/feedback/quiz ledger. Browser self-scores and manual review dates do not update this mentor log, accept exercises or activate scheduled delivery.

## Session history

| Session | Delivery | Lesson | Evidence | Next action |
| --- | --- | --- | --- | --- |
| 001 | 15 October 2026, manual | [Lesson 001](lessons/001-swift-values-and-optionals.md) | Mentor demonstration verified; learner exercise pending | Submit the translated model and predictions |
| 002 | 15 October 2026, manual; explicitly requested | [Lesson 002](lessons/002-enums-and-sealed-states.md) | Mentor example and missing-case diagnostic verified; learner exercise pending | Submit the enum, rendering function, and empty-result reasoning |
| 003 | 16 October 2026, manual; explicitly requested | [Lesson 003](lessons/003-protocols-extensions-closures-and-errors.md) | Isolated Swift example verified; learner exercise pending | Submit the fake appointment service, consumer, and three outcomes |
| 004 | 26 October 2026, manual next-day plan | [Lesson 004](lessons/004-arc-and-capture-lists.md) | Isolated ownership demonstration verified; learner exercise pending | Submit ownership graphs and lifetime predictions |

Mentor verification: isolated Swift example ran successfully with Swift 6.4; output confirmed independent struct values, shared class identity, and optional fallback. No client build was required for this lesson.

Session 002 verification: runnable Swift enum example succeeded with Swift 6.4. A deliberately incomplete switch failed with the expected exhaustive-switch error and named `.offline` as the missing case. No client source files were changed.

Session 003 verification: isolated example ran successfully with Apple Swift 6.4. Output confirmed protocol-based consumption, an extension helper, success and offline handling, an empty successful result, `try?` failure returning `nil`, and a stored escaping closure. The iOS app and Kotlin snippet were not built. Manual delivery does not establish a scheduler run.

Session 004 verification: ran `xcrun swift -module-cache-path /private/tmp/ios-learning-module-cache ios-learning/examples/004-arc-and-capture-lists.swift` successfully with Swift 6.4 and no compiler warnings. The strong-cycle probe remained alive until the stored callback was cleared; weak capture allowed release and safely handled a saved callback after release; queued strong work retained the owner until cleared. All local lesson links resolved. The iOS app and Kotlin snippets were not built.

## Pending exercises

### Session 001

Translate the nullable Kotlin model linked in lesson 001 into an isolated Swift struct with optional integer fields. Demonstrate that assignment followed by mutation leaves the original struct unchanged. Explain how assignment behaves for a Kotlin data class and a Swift class. Add safe optional handling and explain the meaning of `let` for a struct versus a class reference.

Acceptance: correct Swift syntax, correct value/reference explanation, no force unwrap, and evidence that the learner ran or reasoned through the example. A mentor-run example does not satisfy learner completion.

### Session 002

Model search states using a Swift enum with associated values. Handle every state explicitly, including an empty loaded array. Demonstrate or explain the compiler error when a new case is unhandled. Explain the distinction between a search that has not started and one that completed with no results.

Acceptance: correct case payloads, explicit exhaustive handling, and product reasoning about empty results and offline behavior.

### Session 003

Define an `AppointmentServing` protocol with `appointments() throws -> [String]`. Add a fake with populated success, empty success, and offline failure. Add a count extension and a consumer accepting the protocol and a callback. Explain the callback's lifetime and whether `@escaping` is required.

Acceptance: all three outcomes demonstrated or reasoned through; empty success invokes the success callback; offline failure stays distinct; correct closure lifetime explanation; no force unwrap or `try!`. A code-reading alternative may annotate the linked protocol, dependency resolver extension, and cancellation coordinator, tracing contract, callback lifetime, and error handling.

### Session 004

Reproduce a class-to-callback strong capture cycle, demonstrate that dropping an external reference does not release it, and explicitly clear the callback to clean it up. Repeat with weak capture, retaining a separate callback and invoking it safely after releasing the screen. Draw both ownership graphs and explain `guard let self` and unowned lifetime requirements.

Acceptance: cycle and cleanup correctly explained; weak probe shows release; saved weak callback safely handles a missing target; nested strong capture distinguished from a guaranteed permanent cycle. A code-reading alternative may annotate the linked iOS view and coordinator callbacks.

## Recall queue

- Session 002 recall delivered: struct assignment, optional fields, and shared references inside values. Learner recall response pending.
- Session 003 recall delivered: empty successful search versus failure. Learner response pending.
- Session 004 recall delivered: class reference ownership and escaping callbacks. Learner response pending.
- At session 005: explain why a stored callback needs an ownership decision.
- At session 008: connect value/reference semantics to UIKit view ownership.

## Run rules

Read this log before choosing a lesson. For unattended scheduled runs, offer review of the earliest pending exercise. In live chats, honor an explicit request to move to the next lesson while preserving pending exercises; the learner explicitly requested sessions 002, 003, and the next-day plan for 004. Record completions only after reviewing submitted work. Preserve learning notes and never infer a successful automation trigger from a manual delivery.
