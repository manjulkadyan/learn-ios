# GitProject: actual disposable Git practice

Original fixtures for sessions 117–120 and workshop `git-course`. The runner
executes real Git only in newly created unique `/private/tmp` repositories. It
does not run a Git mutation in this checkout, configure a remote, contact a server,
push, create a real PR or alter learner records.

## Run and inspect

Requirements: Python 3.9+ (Path.is_relative_to) and Git 2.28+
(`init --initial-branch`). `switch` and `restore` themselves require Git 2.23;
that lower minimum does not cover this complete setup. Local filesystem access
is required. No external Python packages. Older versions were not tested.
From the `ios-learning` workspace:

```sh
python3 course/labs/GitProject/scratch_checks.py
```

Read the script first. It creates a unique run root and four repositories,
asserts each Git working directory is beneath that root, removes inherited GIT_
environment redirects and ignores system/global Git configuration for this process.
Per-command settings use fictional identity `Scratch Learner` /
`learner@example.invalid`, disabled hooks/signing and deterministic text policy.
The machine's normal Git configuration is untouched. No remote is configured.

For manual practice, reuse lesson 117's `git_scratch` wrapper before initialization
and every later Git invocation. Its preflight rejects all exported `GIT_*`
variables, including `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_COMMON_DIR`,
`GIT_OBJECT_DIRECTORY` and `GIT_ALTERNATE_OBJECT_DIRECTORIES`, and checks the
new scratch path. Deliberately unset reported variables in that scratch shell
before retrying. The runner instead removes all inherited `GIT_*` variables from
each Git subprocess. `-C` selects a working directory; it does not clear repository
redirects or establish isolation by itself.

The script retains repositories and `evidence.json`, including captured staged/
working diffs, conflict text, full IDs and range-diff. Inspect the printed root
with an explicit scratch path only after checking repository redirects. Do not
redirect any lesson command to the real
checkout. Remove only an exact known disposable root if you later choose cleanup.

## Author evidence — 17 November 2026

Executed the command above with Python 3.14.5, Git 2.54.0 (Apple Git-157), arm64
macOS 26.6.2 (25G83). Exit 0, root `/private/tmp/git-project-2w_p7104`:

```text
PASS staged snapshot, independent working copy, ignores and tracked inputs
PASS divergent branches, conflict index, abort and intentional merge
PASS revert ancestry, soft/mixed reset, rescue ref and bounded hard reset
PASS private rebase, merge-base review, range-diff and resource inputs
PASS 4 Git behavior groups; evidence: /private/tmp/git-project-2w_p7104/evidence.json
```

Actual assertions:

- Index contains staged completion while working text has a later rename; MM
  status and commit contents match. A tracked file remains tracked after adding
  an ignore rule. Generated files are ignored; resource and synthetic empty app
  resolution fixture are tracked. No packages are downloaded or resolved.
- Diverging branches produce conflict markers and three index stages; abort
  restores captured clean main state. A deliberate resolution has exact content,
  no unmerged stages, clean status and both expected parents.
- Revert corrects the bad non-merge change without removing its ancestry. Soft
  reset preserves staged/working notes; mixed reset leaves new notes untracked.
  Named rescue and reflog retain the known old tip for this run; selected-file
  restore creates a new recovery snapshot. Hard reset discards one known synthetic
  tracked working edit at current HEAD, never arbitrary checkout work.
- Private rebase creates a new tip descended from updated main; feature review
  paths exclude main's independent policy addition; range-diff contains both
  replayed patches. JSON accent remains orange; listed input paths exist and are
  tracked; no remote entries exist.

These observations are author baseline evidence. They do not approve learner work.
The final JSON exists only after all groups succeed. No measured performance or
claims about long-term reflog retention, merge-revert semantics or remote policies.

## Native/resource boundary

`Fixtures/App.swift` is actual target-required SwiftUI entry source. The runner
copies/reviews its bytes; it does not compile or run it. It shows text and does
not load Theme.json. `Fixtures/Resources/Theme.json` is synthetic data, and
`Fixtures/TargetResources.txt` is an input-review list, **not an executable Xcode
project, target membership or Copy Bundle Resources configuration**.

For independent native practice, create a new iOS SwiftUI App in a unique
`/private/tmp` directory with fictional identity and no simulator signing team.
Choose iOS 17+, remove the generated competing App entry and ContentView, and
copy `Fixtures/App.swift` into the target as its only entry. Add Theme.json with
target membership and Copy Bundle Resources. Implement Bundle.main URL lookup,
Data read and Codable decoding with separate missing-file/invalid-data errors.
Build and run that target separately and observe the decoded value. Do not copy
company sources or invoke client project generation.

Pending: native source typecheck/target build, actual resource packaging and Bundle
lookup, simulator UI, device/signing, generator behavior, remote PR/CI and team
approval. Git input checks prove neither app packaging nor rendered theme. The
companion does not resolve third-party dependencies. Main owns shared course
registration, reader validation and this checkout's Git.

## Independent work and recovery

In a personal copy, add a semantic conflict case where the validator and form
message must agree, or preserve a useful detached-HEAD commit with a named branch
before leaving it. The baseline does not execute detached-HEAD practice. Add a
missing required resource path and verify rejection before deliberate repair.

Predict HEAD/index/working values and full content before commands. Preserve useful
committed tips with named references; separately preserve uncommitted bytes.
Reflog is local, can expire, and is not an independent backup. Hard reset discards
tracked edits and may remove obstructing untracked paths; use only known scratch
values when deliberately practicing it. Revert adds a historical correction;
private reset/rebase changes references/identities; abort ends an unfinished
operation. Choose based on work location and who depends on the history.

Fill `ReviewTemplate.md` in the personal copy with exact base/candidate IDs,
behavior, configuration/resource scope, actual checks, alternatives, recovery
owner and pending native/remote rows. It is intentionally unfilled here. No
reviewer approval, certification or learner completion is pre-recorded.
