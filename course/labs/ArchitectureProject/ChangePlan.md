# Field Notes change and recovery review

Status: current in-memory slice implemented and tested; durable saved choices
PROPOSED. Author adversarial review completed below. Independent human review,
native interaction, and durable implementation acceptance remain pending.
This is an original synthetic exercise, not a production RFC or rollout approval.

## Current contract and changed requirement

Current: Browse, Saved, Detail share one account-session NoteRepository.
Cache is reusable for age <5 seconds. Saved IDs are memory-only. Account changes
revoke old repository authority, reset feature state, and issue a new session UUID.
Route reads and mutations validate session plus account. Each scene owns a Shell.

Changed requirement: save synthetic bookmark choices across process restarts,
separately for demo-a and demo-b. Preserve the existing note identity, presentation
boundaries, route gate, full-snapshot rule, and cancellation semantics.
No account, backend, client, signing, remote install, or deployment work is authorized.

## Alternatives and explicit costs

| Choice | Benefit | Added cost / limitation | Decision |
| --- | --- | --- | --- |
| Keep memory only | Current tested behavior and simple recovery | Cannot satisfy restart retention | Baseline fallback with explicit user message |
| Account-scoped snapshot files | Bounded identifier sets and inspectable envelopes | Versioning, atomic replacement, protection/backup, corrupt read, obsolete write checks | Proposed first experiment |
| Database | Rich queries/transactions if requirements grow | Schema, contexts/isolation, migration and storage tooling | Defer without query/sync need |
| Current MVVM | Direct async methods and small feature states | Every success/error path needs revision discipline | Keep |
| Pure reducer + runner | Auditable event transitions and replay | Actions, effects, result tags, cancellation keys, runner ownership | Reevaluate after demonstrated event-combination complexity |
| Coordinator journeys | Explicit parent completion and mixed UI ownership | Child retention, terminal settlement, presentation bridging | Reevaluate for multi-screen parent-result flow |

Costs describe obligations, not measured engineering hours or performance.
The current package inventory is five source targets, one test target, and one
library product. No external reducer or DI library is introduced by this plan.

## Proposed seam, ownership, and acceptance

Add a narrow `BookmarkStore` in the domain contract and its file adapter in
NoteData. Construction remains in AppShell. Do not import storage into either
feature. A repository is scoped to one account-session; its commit authority must
guard store replacement as well as memory. Disk writes may suspend, so a design
must prove revocation cannot be bypassed between checking authority and writing.
Use an account-owned serialized writer or explicit transaction lease with
revocation acknowledgment; checking a Boolean before an arbitrary async write
is insufficient. The exact implementation and tests are pending.

Envelope proposal: version, synthetic account ID, sorted saved identifiers.
Missing file means never saved; failed read is a failure, not empty success.
Do not persist local ContinuousClock instants or session UUIDs as durable
authorization. Choose an appropriate sandbox location, data protection and backup
policy during actual integration; this fixture has not selected or tested them.
Bound identifier count and envelope bytes before decoding. No real user data.

Acceptance to implement independently:

1. Save n1 in A, restart scratch process, reopen A, and recover n1.
2. Save n2 in B; reopening A still yields only A's expected IDs.
3. Reject malformed, wrong-account, unsupported-version, duplicate-ID and oversized
   envelopes without silently clearing the last readable representation.
4. Inject failed write/rename and interrupted replacement; prior committed file
   remains readable. Observe actual filesystem behavior rather than assuming it.
5. Revoke A during a held write; acknowledgment of revocation guarantees no later
   A write can recreate the store. Join or explicitly drain leased writes safely.
6. Test removed IDs using an authoritative complete snapshot. A partial page does
   not erase bookmarks for absent records.
7. Re-run existing host contracts and native integration acceptance after changing
   composition. Run corruption and migration checks against real scratch files.

Learner: implementation and evidence owner. A separate engineer: review owner
to be named when an actual reviewer accepts the role. Course integrating author:
shared registration/build owner. No role assignment here messages anyone.

## Author review performed and resulting revisions

| Finding | Before | Revision / actual evidence | Status |
| --- | --- | --- | --- |
| Same-account return reauthorizes old route | Account String alone would accept A1 route in A2 | Route includes UUID session; `verticalSliceSavedDetailAndAccountSwitch` checks A→B→A read and mutation rejection | Closed in current slice |
| Saved errors after reset could reappear | Late toggle catch could set failed on reset model | Revision guard around toggle and reload; `resetSuppressesLateSavedErrors` holds and fails both paths after reset | Closed in current slice |
| One feature error must not destroy another's state | Shared data mistaken for shared presentation | `savedFailureDoesNotChangeBrowseState` injects Saved failure and preserves Browse ready | Closed under host fixture |
| Full-snapshot reconciliation is not pagination | Intersecting IDs with a partial page would erase choices | README and lesson bound behavior to full authoritative snapshots | Boundary documented; pagination not implemented |
| Revoked durable write may recreate data | Memory guard cannot guarantee async disk commit | Added serialized writer/lease acknowledgment requirement above | Open until adapter and filesystem tests exist |
| Independent review/native interaction missing | Compiler or author checks could be mislabeled approval | Evidence ledger explicitly separates them | Open |

The review is by the author, using source inspection and adversarial host
schedules. It is not peer sign-off or a fabricated review conversation.
The twelve tests passed on Swift 6.4.2. Native source compiled and linked for an
iOS 17 simulator target; no UI run occurred. See README for commands and limits.

## Adoption, stop conditions, and recovery

Adopt only inside a fresh scratch synthetic session after the new adapter's
acceptance passes. Select it at composition; do not swap the active repository
mid-write. First run missing-store fixtures, then successful writes, failed
replacements, corruption, revoked writes, and older/newer compatibility.
Attach evidence for each before treating the requirement as delivered.

Stop on cross-account identifiers, loss of previous readable data, unknown-format
overwrite, or write-after-revocation. Disable new writes and preserve recoverable
data. Keep bounded schema/error metadata; do not log contents or credentials.
Return future scratch sessions to the in-memory adapter with a clear temporary
message: saved choices will not persist in this mode. Do not replay a failed
side-effecting operation automatically or erase durable user work to hide failure.

Code rollback changes the implementation; data recovery must restore a compatible
representation. Keep a versioned prior readable copy or provide and test explicit
backward compatibility before upgrading. Quarantine corrupt input for diagnosis
only with an appropriate privacy policy, and provide a deliberate recovery choice.
The plan does not claim a file migration, backup restore, production flag switch,
deployment, or real-account recovery was executed.

Independent review should inspect every mutation gate, all suspension points
before durable commit, scene/account ownership, complete-snapshot assumptions,
and previous-format recovery. Mark approval pending until an actual review is
recorded. The reference solution is not learner completion.
