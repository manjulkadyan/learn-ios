# DeliveryLab

Local JSON evidence and artifact-identity checks for lessons 105–108 and workshop
`delivery-review-lab`. No third-party dependencies, app signing, publication,
company-client writes, or completion-state changes. All bundled records are
synthetic. Proposed role labels are not actual owners or independent approvals.

## Requirements and bounded claims

- Python 3.10+; the audit used Python **3.14.5**.
- Swift examples require Swift 6 language mode and Foundation. The audit used
  Apple Swift **6.4**, target `arm64-apple-macosx26.0`.
- Xcode **27.1**, build **27A9275**, was installed. No Xcode project or native
  target was built; only `xcresulttool` command help was inspected.
- The validator checks supplied metadata, path containment, attachment digests,
  current revision labels, review fingerprints, and required evidence states.
  It does not authenticate identities or provenance, parse every Apple format,
  verify a signature, symbolicate, measure memory, or prove adoption.
- Eager file reads are suitable for small local fixtures. Streaming large files,
  mutation during collection, filesystem race resistance, UI scheduling and
  cancellation need separate implementation/review before broader use.

## Reproduce the host checks

Run from `ios-learning/course/labs/DeliveryLab/`. A new directory keeps caches,
compiled products and logs out of the course and other authors' labs:

```sh
DELIVERY_TMP=$(mktemp -d /private/tmp/deliverylab.XXXXXX)
export PYTHONPYCACHEPREFIX="$DELIVERY_TMP/python-cache"
python3 -m unittest -v test_validate.py > "$DELIVERY_TMP/python-tests.txt" 2>&1
python3 check_content.py > "$DELIVERY_TMP/content-check.txt"
swiftc -swift-version 6 -module-cache-path "$DELIVERY_TMP/swift-cache" DeliveryExamples.swift -o "$DELIVERY_TMP/DeliveryExamples"
"$DELIVERY_TMP/DeliveryExamples" > "$DELIVERY_TMP/swift-checks.txt"
```

Inspect exit statuses and logs. `check_content.py` audits only this author's unit,
interviews, workshop, safe HTML, prerequisites, references, and source/file paths.
It does not build or mutate shared integration assets. Its teaching count excludes
code blocks, so the minimum is supported by original prose.

For a single record, use the lab itself as evidence root:

```sh
python3 validate.py fixtures/pending.json --root .
python3 validate.py fixtures/wrong-identity.json --root .
python3 validate.py fixtures/pending.json --root . --mode installation
python3 validate.py fixtures/pending.json --root . --mode diagnostic
python3 validate.py fixtures/changed-constraint.json --root . --mode deprecation
```

These intentionally return nonzero where appropriate. Exit **0** means bounded
consistency, **1** means invalid input/evidence, and **2** means required evidence
or review remains pending. Do not convert pending to a learner completion.

## Observed verification on 2 November 2026

Author outputs and caches used the unique subtree
`/private/tmp/deliverylab-20261102-author/`; test fixtures used independently
created `/private/tmp/deliverylab-test-*` directories and were removed afterward.

Executed commands, from the lab unless shown otherwise:

```sh
PYTHONPYCACHEPREFIX=/private/tmp/deliverylab-20261102-author/cache python3 -m unittest -v test_validate.py
python3 validate.py fixtures/pending.json --root /Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/DeliveryLab
python3 validate.py fixtures/wrong-identity.json --root /Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/DeliveryLab
python3 validate.py fixtures/pending.json --root /Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/DeliveryLab --mode installation
python3 validate.py fixtures/pending.json --root /Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/DeliveryLab --mode diagnostic
python3 validate.py fixtures/changed-constraint.json --root /Users/manjul.kadyan/StudioProjects/zocdoc/mobile/ios-learning/course/labs/DeliveryLab --mode deprecation
```

From the mobile workspace, the Swift compile/run commands were:

```sh
swiftc -swift-version 6 -module-cache-path /private/tmp/deliverylab-20261102-author/cache/swift ios-learning/course/labs/DeliveryLab/DeliveryExamples.swift -o /private/tmp/deliverylab-20261102-author/results/DeliveryExamples
/private/tmp/deliverylab-20261102-author/results/DeliveryExamples
```

Observed results:

| Check | Actual result |
| --- | --- |
| Python contract tests | **25 tests passed**, exit 0 |
| Swift compilation | Exit 0 in Swift 6 language mode |
| Swift execution | Identity, checked multiplication/overflow, current independent-review labels, and retirement cases passed; exit 0 |
| Pending proposal, local | `pending`, exit 2: review/retest incomplete |
| Wrong identity, local | `invalid`, exit 1: environment and arm64 symbol UUID mismatches |
| Installation mode | `pending`, exit 2: captured installation/upgrade/privacy evidence and manual checks absent |
| Diagnostic mode | `pending`, exit 2: captured crash evidence absent |
| Widget deprecation | `pending`, exit 2: exception retained; captured consumer/outcome evidence absent |
| Assigned content audit | Exit 0: four lessons, eight interviews, workshop, HTML, prerequisites, source anchors and nine companion paths passed |
| Individual lesson snippets | Four independent `swiftc -typecheck` invocations passed in Swift 6 mode |

The content audit command, from this lab, was:

```sh
PYTHONPYCACHEPREFIX=/private/tmp/deliverylab-20261102-author/cache python3 check_content.py
```

It reported 1,638 / 1,894 / 1,863 / 1,807 teaching prose words for lessons
105 / 106 / 107 / 108, and 1,507 for the workshop. All eight model answers
contain 100–220 words with required rubrics, followups and pitfalls. Snippets
were extracted from the JSON into the unique temporary output directory and
checked with these actual commands:

```sh
swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/deliverylab-20261102-author/cache/swift /private/tmp/deliverylab-20261102-author/results/lesson-105-1.swift
swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/deliverylab-20261102-author/cache/swift /private/tmp/deliverylab-20261102-author/results/lesson-106-1.swift
swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/deliverylab-20261102-author/cache/swift /private/tmp/deliverylab-20261102-author/results/lesson-107-1.swift
swiftc -typecheck -swift-version 6 -module-cache-path /private/tmp/deliverylab-20261102-author/cache/swift /private/tmp/deliverylab-20261102-author/results/lesson-108-1.swift
```

Logs are retained in the temporary `results/` directory; `synthetic-result.txt`
is deliberately **not** the actual test log. The 25 tests include stale revisions,
changed bytes, directory-name hashing, missing files, traversal/symlink rejection,
duplicate images, architecture mismatches, review blockers, and exception gates.
No historical flawed implementation was executed or given invented before/after
results. Swift checks use synthetic numbers, not device memory samples.

## Record and review protocol

Copy a fixture and its evidence tree into scratch space before editing. Keep
identity strings explicit, including build and environment. Match image UUID and
architecture, not only version or source commit. Resource inventories and observed
entitlement values are supplied assertions; compare them with actual packages
and signed artifacts before setting manual-check fields.

Evidence entries need unique `id`, `kind`, relative `path`, `sha256`, `provenance`
(`synthetic` or `captured`), and `revision`. Kinds are listed in `validate.py`.
For directory bundles the hash binds sorted relative paths and file SHA-256
values. Use `artifact_digest(root, relative)` to calculate the exact contract;
do not hash an arbitrarily zipped copy and substitute that digest. Preserve raw
files, tool version, invocation, and output. The collector must review concurrent
mutation risks before using this small-file mechanism outside the workshop.

Use `proposed` → `reviewed` → `revised` → `retested` as the human feedback loop:

1. State expected behavior and missing evidence.
2. An actual independent reviewer runs a counterexample and records findings,
   severity, evidence, and a closure criterion.
3. Revise the implementation/contract, record the correction, and invalidate old
   review inputs. A blocker cannot be closed by merely marking it accepted.
4. Retest the current candidate. Bind `reviewedFingerprint` to
   `fingerprint(record)` after inspecting final inputs. Provide a revision note,
   closed blocker resolutions, and host-test evidence for this revision.

The tool checks a current state, not an authenticated history of all transitions.
Different reviewer strings and captured labels are not proof of real people or
real artifacts. If an independent person is unavailable, retain that review gate
as pending; synthetic fixture review never closes it. Do not silently rewrite old
reports when the tool or contract changes.

## Manual target, diagnostic, and installation work still required

No raw crash, hang, jetsam, trace, or `.xcresult` file was supplied or generated.
The following help command actually succeeded:

```sh
xcrun xcresulttool help get test-results summary
```

It advertised `get test-results summary --path <path>` and schema version 0.4.0.
This established command syntax only. If an **actual** authorized scratch run
produces a result bundle, point `DELIVERY_RESULT_BUNDLE` at that existing bundle,
check it exists, and then extract it:

```sh
if test -d "$DELIVERY_RESULT_BUNDLE"; then
    xcrun xcresulttool get test-results summary --path "$DELIVERY_RESULT_BUNDLE"
else
    printf 'Pending: supply an existing result bundle from an actual scratch run.\n'
fi
```

These extraction commands were **not executed** because no real bundle existed.
Do not create synthetic `.xcresult`/`.trace` directories to satisfy evidence rows.
Record selected tests, retries, skips, cancellations, destination and configuration.
Use original real report/trace paths and their actual digests for diagnostic mode.
The validator does not inspect their internal Apple schemas or diagnose causality.

For symbolication, independently compare report image UUID/architecture to
`xcrun dwarfdump --uuid` output for the actual executable and retained dSYM. Then
use the installed Xcode/symbolication tools with matching symbols. For jetsam,
use its recorded page size and selected process; do not invent a backtrace.

A signed device installation or beta step is a **manual learner task requiring
separate authorization**, a learner-owned scratch target, and suitable Apple
account/device access. The author did not sign, upload, install, or distribute an
app. Inspect effective settings, each executable's signed claims/profile, packaged
resources, and privacy declarations. Run fresh installation and preserved-baseline
upgrade as separate rows, with synthetic app data, denied/allowed permissions,
account/storage boundaries, and relevant extensions. No store rollback is promised.

The widget fixture requires retained reader compatibility, a real owner,
compensating old/new-reader checks, and an independently reviewed removal decision.
No consumer adopted anything in this exercise. Captured outcome windows,
cross-team owner acceptance, real independent critique, and operational recovery
remain unverified. UI integration, cancellation schedules, target membership,
native shared-storage coordination, simulator/device interaction, and measurements
also remain specialist practice. Parent integration/global reader checks are not
run by this author.

## Official reference audit and checkout connections

Official pages retrieved with `curl -L --fail --silent --show-error` on the audit
date supported build-setting definitions, TN2415 entitlement troubleshooting,
required-reason API declarations, symbol UUID/architecture matching, jetsam fields,
MetricKit delivery/availability, Swift errors/concurrency/attributes, Android build
variants, Kotlin cancellation/deprecation, Java 11 checked multiplication, and
shared extension-container coordination. The
precise URLs are in the owned content JSON files; copies are not embedded here.

Live Apple MXMetricManager documentation showed iOS 13 introduction and an iOS
27.2 deprecation entry recommending MetricManager. Xcode 27.1 being installed does
not establish that newer API's SDK/deployment availability. No MetricKit receiver
was compiled, installed, or observed; the runnable Swift examples are host-only.
Recheck the imported SDK and supported deployment OS before a native implementation.

After reading `ios-client/AGENTS.md`, the author inspected the active app manifest
(dynamic plist/entitlement paths, resources, widget membership), Sentry startup,
Tuist CI result path/signing comment, ZDAccount target/test manifest, ZDAssets
resource processing, and the main-actor PrivacyChoicesModule protocol. They are
read-only source anchors, not emitted-artifact, build, runtime, or adoption proof.
