# Pending native, sandbox, and device evidence

All rows start **pending**. This authoring task does not execute any row, request
permissions, create accounts, deploy schema, connect hardware, or purchase anything.
Use a separate scratch project with synthetic content only. Record actual SDK,
deployment target, OS, target identity, setup, result and retained artifact for each
row. Do not reuse client credentials or sensitive records. A compiled target is
not proof of interaction, transport, privacy behavior, or service availability.

## StoreKit and ActivityKit

- [ ] Scratch iOS 17+ target, Xcode with that SDK: compile a StoreKit adapter,
  verification handling, long-lived update listener and entitlement reconciliation.
- [ ] Xcode StoreKit configuration, explicitly local simulation: pending purchase,
  cancellation, unverified fake boundary, renewal, revocation/refund update, relaunch,
  expiration and unavailable-product UI. Record local test setup; no real purchase.
- [ ] Separately authorized App Store sandbox investigation: account/environment,
  catalog configuration, cross-device changes, refund submission versus approval,
  transaction replay, server notification verification. Pending; local configuration
  testing does not prove these.
- [ ] Compile a WidgetKit extension with ActivityConfiguration and an ActivityKit
  app adapter; inspect NSSupportsLiveActivities and availability of each overload.
- [ ] Simulator rendering: fresh/stale/final views, compact/expanded layouts,
  accessibility and lock-screen redaction with synthetic labels.
- [ ] Separately authorized device/APNs test: user disabling or dismissing activity,
  process suspension, token changes, late updates, final dismissal and OS lifetime.
  No exact update delivery guarantee may be inferred from a single successful run.

## CloudKit and coordinated documents

- [ ] Local scratch document adapter: coordinated read/write, move, external editor
  change, presenter callback delivery and undo preservation. Do not call accounts.
- [ ] Inspect the designed signing capability, container ID, database scope,
  environment, record types and indexes without deploying anything.
- [ ] Separately authorized development-container test: two installations modify
  disjoint fields, then the same field; retain base/local/server and change tags.
- [ ] Suppressed/lost push followed by foreground fetch; pagination and token-expiry
  recovery; atomic local application of changes plus checkpoint; restart during save.
- [ ] Account sign-out/change, unavailable iCloud, quota and partial failure handling;
  old-generation work cannot write into the new account's local projection.
- [ ] Separate organizational schema review: additive production evolution,
  permissions, retention, rollback and field/index compatibility. No production
  schema deployment is part of this lab.

## Text, media and performance branches

- [ ] Scratch UIKit editor: TextKit 2 construction on iOS 16+; selected replacement
  of emoji/combining text, Arabic/Hebrew mixed direction, long paragraphs and IME.
- [ ] One semantic edit undoes and redoes text plus selection; no wholesale text
  reassignment during marked-text composition; hardware keyboard and VoiceOver.
- [ ] Observe the chosen text stack; accessing layoutManager is a fallback trigger,
  not a harmless introspection technique for a TextKit 2 control.
- [ ] AVFoundation playback of bundled synthetic media: interruption, route change,
  pause/stop ownership and observer cleanup. Playback needs no microphone request.
- [ ] Separately authorized physical-device profiling: intervals for decode, layout,
  compositing, GPU work or Core ML preprocessing/inference/postprocessing. Preserve
  raw traces and correctness before making a branch-specific performance claim.
- [ ] DSP, shader/kernel validation, codecs/DRM, model training/evaluation and model
  distribution are separate projects, not completed integrations here.

## Watch, spatial, Bluetooth and health branches

- [ ] Separate watchOS scratch target: snapshot context versus queued command;
  unreachable counterpart, reply timeout, account generation and replay receipt.
- [ ] Paired-device and independent-watch behavior require separate tests; simulator
  target compilation does not establish transport or background execution budgets.
- [ ] Separate visionOS window: system Button, indirect selection, focus, keyboard,
  VoiceOver and scene suspension. A simulator can check layout, not wearer comfort.
- [ ] Hardware comfort and optional immersive-space entry/exit stay pending; no raw
  gaze stream is implied by ordinary system selection.
- [ ] Separately authorized Bluetooth test peripheral: powered-off/unauthorized,
  bounded service-filtered discovery, retained peripheral, disconnect and duplicate
  notification handling, restoration and background behavior. No scans run here.
- [ ] Separately authorized HealthKit scratch target: capability, purpose strings,
  type-scoped requests, empty/filtered data, write status and product opt-out;
  background observer completion/checkpoint recovery. No real health query runs here.
- [ ] Team review: one branch owner, fallback UX, support cost, data deletion and
  adoption/reversal evidence. This is a decision deliverable, not a certification.
