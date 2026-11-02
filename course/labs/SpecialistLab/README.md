# Specialist policy workbench

This is a bounded, synthetic host companion to lessons 109–112 and
`specialist-selection-lab`. It is not an iOS application or an Apple integration.
There are no packages, network calls, Apple accounts, hardware access, real
permissions, health records, payment flows, signing changes, or cloud containers.

Requirements: Python 3.11+ using only its standard library; optional Swift 5.9+
and Foundation on macOS 13+ for the exact Foundation examples in lesson 111.
The Python model also runs without macOS. Run from this directory:

```text
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v test_policy
PYTHONDONTWRITEBYTECODE=1 python3 policy_model.py
PYTHONDONTWRITEBYTECODE=1 python3 check_content.py
swiftc -module-cache-path /private/tmp/specialist-module-cache SnippetChecks.swift -o /private/tmp/specialist-snippet-checks
/private/tmp/specialist-snippet-checks
```

`policy_model.py` models injected verification, local fixture revisions,
conditional tags, three-way merging, operation receipts, owner generations,
freshness and end boundaries, and product-specific feature fallback decisions.
`test_policy.py` checks adversarial delivery permutations, expiry at equality,
refund updates on an existing transaction, model reconstruction after a lost
acknowledgment, conflicting fields, stale owners, and post-end updates.
`SnippetChecks.swift` checks the three standalone examples from lessons 110–112
and synthetic entitlement arithmetic. It does not compile any StoreKit, CloudKit,
ActivityKit, UIKit, or device adapter.
`check_content.py` checks only the author's assigned banks and explicit files.
It is not the shared course builder and does not validate assembled routes.

Fixture revisions are deliberately monotonic integers. StoreKit does not promise
these integers or the modeled event order. CloudKit record tags are opaque values,
not the model's incrementing counter. Receipt insertion and mutation happen
together in this single-process model, but JSON reconstruction does not prove disk
durability, crash atomicity, interprocess synchronization, or cloud idempotency.
Surface deadlines are an application policy; no OS callback timing is simulated.
Health `consent` is a synthetic product opt-in and must not be interpreted as known
HealthKit read authorization. Empty results stay ambiguous.

The independent exercise is to add fixed-schema tombstone behavior, including
delete-versus-edit conflict evidence and replay after model reconstruction, then
submit an evidence ledger. Existing passing checks are examples and do not complete
your work. Keep native rows in `NativeChecklist.md` pending until performed in a
separate authorized scratch project. No learner completion is recorded here.

## Actual author verification — 2 November 2026

Environment reported Python 3.14.5 and Apple Swift 6.4, targeting
arm64-apple-macosx26.0. These are the observed host tools, not minimum course
requirements or a claim about the latest released toolchain.

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v test_policy`: exit 0;
  all 12 synthetic correctness tests passed.
- `PYTHONDONTWRITEBYTECODE=1 python3 policy_model.py`: exit 0; output explicitly
  labeled synthetic, with grant before revocation true, grant after revocation
  false, independent title/note edits preserved, and stale at the threshold.
- `PYTHONDONTWRITEBYTECODE=1 python3 check_content.py`: exit 0. Original prose
  excluding preformatted code: lesson 109 1,733 words; 110 1,770; 111 1,807;
  112 1,775. Eight interview answers are 159–171 words. Workshop is 1,346 words.
  HTML/schema/IDs/references/source anchors and six explicit files passed.
- The `swiftc` compile command above exited 0. Running the temporary executable
  exited 0 and printed `PASS: synthetic entitlement, Unicode replacement, field
  merge and watch-plan checks`. The checker also confirmed that the three lesson
  examples match the compiled companion source.
- Lesson 109's StoreKit example was extracted and passed to
  `swiftc -typecheck -module-cache-path /private/tmp/specialist-module-cache -`
  using the host macOS SDK. The process returned 0 but emitted two
  `sandbox-exec: sandbox_apply: Operation not permitted` diagnostics. This is
  limited compiler evidence, not a clean native-target validation. No function
  was executed and no StoreKit operation was invoked.

Official Apple web results were inspected for current entitlement/revocation,
ActivityKit freshness/lifetime/data limits, CloudKit version/schema behavior,
TextKit compatibility, Watch Connectivity transport, visionOS input/privacy,
Bluetooth background behavior, HealthKit read privacy, audio API guidance and
Core ML/Metal boundaries. Precise official links are retained in the lessons.
Direct curl retrieval failed host resolution; elevated curl was rejected because
sandbox approvals are disabled. The web tool's direct Apple Markdown retrieval
also failed with unsupported content type, so documentation verification used
official indexed pages and Apple WWDC material rather than claiming all linked
pages were downloaded in full.

The global builder was not run. No simulator, device, signed target, App Store
sandbox, APNs, iCloud, permission, hardware or health test ran. No performance
measurement, production integration, or learner completion is asserted. Native
adapters, disk crash/atomicity tests, full collaborative editing, DSP/shader/model
validation, paired transport and platform operational review remain separate work.

## Integration StoreKit compiler check

The integrator extracted the complete `import StoreKit` Swift example directly
from lesson 109, decoded its HTML entities, and typechecked that source for an
**arm64 iOS 17 simulator target** using SDK **27.1** and Swift **6** mode. The
compiler-helper flag disabled only the compiler's nested helper sandbox; the
outer workspace restrictions remained. The equivalent invocation was:

```sh
SPECIALIST_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -typecheck -swift-version 6 -Xfrontend -disable-sandbox \
  -target arm64-apple-ios17.0-simulator -sdk "$SPECIALIST_SDK" \
  -module-cache-path /private/tmp/specialist-native-dqkypp_x/module-cache \
  /private/tmp/specialist-native-dqkypp_x/StoreKitLesson.swift
```

Exit **0**, with no diagnostics; extracted source and diagnostics are retained
under that temporary directory. This resolves the earlier noisy host-only
typecheck for this one example. No function executed, app linked or launched,
purchase started, entitlement observed, or App Store sandbox interaction occurred.
