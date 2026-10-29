# Course authoring contract

Audience: Android engineer with 7–8 years of Kotlin/Java experience, zero assumed iOS knowledge. Course title: Across the Stack — Android to iOS. Detailed mentor-style instruction, not summaries. Local website only.

All authoring paths below are relative to `/Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/`. Preserve existing lessons and progress. Do not edit client source code.

## Data format

Each content unit is a JSON object with `unit` and `lessons`. No dependencies. Encode HTML as JSON strings. HTML may contain p, h3, h4, ul, ol, li, strong, em, code, pre, table, thead, tbody, tr, th, td, blockquote, details, summary, a. Use `<pre><code class="language-swift">…</code></pre>` for code and HTML-escape angle brackets and ampersands inside examples. Avoid h1/h2 in content; the site supplies section headings. Avoid executable scripts, styles, external images, iframes, and forms. Links to local code belong in `repo`, not hard-coded absolute file URLs inside prose.

```json
{
  "unit": { "id": "foundations", "title": "Swift foundations", "summary": "...", "order": 1 },
  "lessons": [{
    "id": "001",
    "title": "...",
    "summary": "...",
    "duration": 45,
    "level": "Foundation",
    "prerequisites": [],
    "objectives": ["..."],
    "sections": [{"id": "mental-model", "title": "...", "html": "<p>...</p>"}],
    "quiz": [{"question": "...", "options": ["...", "...", "..."], "answer": 1, "explanation": "..."}],
    "exercise": {"brief": "...", "steps": ["..."], "acceptance": ["..."], "solution": "<p>...</p>"},
    "references": [{"label": "Official Swift language guide", "url": "https://docs.swift.org/..."}],
    "repo": [{"label": "...", "path": "ios-client/Projects/.../file.swift", "line": 12, "why": "..."}],
    "checklist": ["I can ...", "I can ..."]
  }]
}
```

The main agent adds `unitId` while building. Session IDs must be three-digit strings. Every lesson needs at least 5 sections, 3 quiz questions, one exercise with worked solution, 2 official reference links, and at least one verified active repository anchor. Aim for 1,200–1,800 words of teaching per lesson, allowing longer sessions for substantial topics and shorter lab/review prose if the worked task is detailed. Avoid claiming exhaustive coverage of the whole platform. Each lesson should feel usable as a future reference.

## Teaching quality

Start with why and a familiar Android example. Define unfamiliar syntax before using it; explain code line by line when helpful. Explain small distinctions (argument labels, optional handling, reference lifetime, actor isolation, platform/API availability, language vs tools version) instead of waving them away. Include a correct Swift example, a Kotlin/Java counterpart where useful, misconceptions, edge cases, failure modes, design tradeoffs, a practice task, acceptance criteria, and a worked answer. Follow current checkout conventions. Separate a conceptual analogy from an exact feature counterpart. Use synthetic data. Distinguish snippets that require UIKit/SwiftUI or a target from runnable standalone Swift.

Verify facts against official Swift/Apple/Kotlin/Android documentation as needed. Inspect the relevant repository files and instructions. Provide source links, not copied chapters. Do not imply an isolated example was built as an iOS app. Explain modern alternatives alongside actual legacy patterns without inventing migrations. No user exercise is pre-completed.

## Unit ownership

- `content/unit-01.json`: sessions 001–007, language and tools foundation (values, enums, protocols/extensions/closures/errors, ARC, tooling, model/test lab, retrieval review).
- `content/unit-02.json`: sessions 008–014, UI and feature delivery (UIKit/lifecycle, SwiftUI/Observation, navigation/interoperability, async first steps, testing, UI lab, feature-tracing review).
- `content/unit-03.json`: sessions 015–021, production data/concurrency (structured concurrency/cancellation, actors/Sendable, streams/Combine/RxSwift, URLSession/Codable/auth, persistence/DI/module contracts, data lab, architecture review).
- `content/unit-04.json`: sessions 022–028, production/staff practice (accessibility/localization, performance/Instruments, reliability/observability, security/privacy, build/release/signing, RFC/migration lab, staff portfolio review).

Each agent may edit ONLY its assigned JSON unit. Main agent owns the website, build tools, reference library, README, shared schema, and integration. Use `apply_patch` for authoring edits. Return paths changed and any accuracy or verification limits. Do not spawn further agents.

## Depth expansion — 27 October 2026

The original 28 lessons remain unchanged, including their IDs, quizzes, and pending learner work. The manifest defines an additional 28 deep dives. Units 05–08 use the same lesson schema and seven lessons per unit. Aim for at least 1,300 words of explanation per lesson, plus a worked exercise; prioritize precision and line-by-line explanation rather than a list of API names. Six or more sections are welcome. Explain prerequisites, API availability, failure modes, Android analogy boundaries, and measurable acceptance evidence. Deep dives can take several 45-minute days.

Each author first audits the relevant existing lessons and the active source/manifests. Distinguish a mention from usable instruction. In the final message, report substantive gaps found and filled, repository evidence checked, and topics still needing specialist practice. Do not change existing units or shared files. Client source is read-only. No exercises are pre-completed, measurements invented, or migrations claimed complete. Official documentation links should support precise claims, not merely point to a homepage. Verify changing Apple policies/API availability against official references when tools allow. Treat checkout pins as checkout pins, not the latest software versions.

- Unit 05, sessions 029–035: UI engineering. 029 Auto Layout, hugging/compression, safe areas, sizing and traits; 030 collection/table reuse, diffable snapshots, compositional layout, pagination and prefetch; 031 SwiftUI layout, modifiers, builders, preferences and custom layout contracts; 032 interaction, animations/transactions, gestures, scroll identity and focus; 033 forms/keyboard/text editing/validation/localization; 034 app/scene lifecycle, adaptive iPad/multiple windows, restoration and ownership; 035 integrated UI lab and review. Preserve accessibility, dynamic text, navigation and UIKit/SwiftUI bridging throughout.
- Unit 06, sessions 036–042: performance and optimization. 036 measurement contracts, Instruments, signposts, distributions and representative devices; 037 cold/warm launch, startup/first usable frame and binary size; 038 rendering/hitches/main-thread work/list scrolling and SwiftUI invalidation; 039 memory/ARC/COW/Objective-C autorelease/image decoding/downsampling; 040 networking/IO/energy/concurrency limits/caches and backpressure; 041 compiler/build-time/module/algorithm optimization and evidence-based tradeoffs; 042 profiling lab and regression gates. Do not claim profiling occurred merely from reading source.
- Unit 07, sessions 043–049: tooling, libraries and variants. 043 targets/schemes/configurations/xcconfig/environments/bundle IDs/flags/signing and Gradle variant boundaries; 044 SPM products/targets/pins/static-dynamic/XCFramework/ABI/module stability/availability/license and supply chain; 045 verified active library and internal-module landscape with responsibilities and migration status; 046 code generation/assets/localization/resources/privacy manifests; 047 LLDB/debugging/toolchain diagnostics/Objective-C interoperability; 048 test/CI/destination/configuration matrices and reproducible verification; 049 bounded dependency/configuration change lab, rollout and rollback. Read manifests before naming a library as active.
- Unit 08, sessions 050–056: platform systems. 050 background execution and notifications/APNs entitlement/environment/cancellation policy; 051 deep links/universal links/App Clips/routing/authentication gates; 052 Foundation dates/time zones/DST/Unicode/locale/numbers/files/sandbox correctness; 053 Core Data/SwiftData contexts/migration/confinement/cache and account boundaries; 054 WebKit and system authentication/trust boundaries/cookies/bridges; 055 device capability/permission services (location/maps/photos/camera/AVFoundation) with denied/limited/restricted states and ownership; 056 extensions/widgets/App Intents/cross-device boundaries and an integration review/lab. Teach unimplemented adjacent platforms as further study, not implemented checkout support.

The main agent owns a coverage matrix separating explained, practiced, and further-study topics. No author may claim to exhaust all of iOS. The goal is a substantially deeper, auditable course for this client, with explicit specialist boundaries.

## Supplementary Swift details

`content/essentials.json` contains `{ "guides": [...] }` with three non-numbered references. Each guide has `id`, `title`, `summary`, `sections`, `exercise`, `references`, and `sessions` (related existing lesson IDs). Sections, worked exercises, and HTTPS references follow the lesson HTML contract. Use at least four sections, two official references, and 900 teaching words including the worked answer. Stable IDs are `initialization-access`, `generic-contracts`, and `callback-ownership`. Guides do not add quiz indices, change the 56-session sequence, or record completion. A coverage topic may list optional `guides` IDs as additional reading. The builder validates and bundles them; the Swift details route and global search display them.

## Interview bank

`content/interview-core.json` and `content/interview-deep.json` each contain `{ "questions": [...] }`. Provide two bespoke prompts per numbered lesson: IDs `iq-001-a`, `iq-001-b`, continuing through `iq-056-b`. Each question has `id`, `lesson`, `level` (`Foundation`, `Senior`, `Staff`), `kind` (`Explain`, `Debug`, `Design`, `Code`), `prompt`, `scenario`, `minutes` (3–20), `androidBridge`, `rubric` (at least four observable answer points), `answerHTML` (100–220 words of original explained answer, using the same safe HTML contract), `followUps` (at least two), and `pitfalls` (at least two). Read the associated lesson before drafting. The first prompt checks a core mechanism; the second asks for failure analysis or an applied tradeoff. Staff prompts must require ownership, alternatives, evidence and recovery, not obscure API trivia. Kotlin/Java analogies must state where they break. Use synthetic scenarios; no real interview/company claims, no automatic mentor approval, and no client edits. Existing lesson questions and indices remain unchanged. Each author edits only its assigned interview JSON; main agent owns integration, state, tests and mock-round metadata.
