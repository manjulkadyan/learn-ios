# Swift Collections at the checkout pin

Assessment date: 17 November 2026. This is a bounded technical decision, not legal/privacy approval or a performed upgrade.

## Need and decision

The two-card offline catalog needs stable order and duplicate rejection. Array plus Set meets that contract. Keep this companion free of remote dependencies. For a larger ordered-unique selection or a queue with frequent operations at both ends, consider the smallest matching Collections product behind a feature-owned adapter returning ordinary arrays/values.

## Inspected primary evidence

- Client `ios-client/Tuist/Package.swift:77` requests exact `1.1.4`.
- Client `ios-client/Tuist/Package.resolved:248` records revision `671108c96644956dddcd89dd59c203dcdb36cec7`.
- [Pinned manifest](https://github.com/apple/swift-collections/blob/671108c96644956dddcd89dd59c203dcdb36cec7/Package.swift): tools version 5.7, generated products including OrderedCollections/DequeModule in default configuration, no remote package dependencies.
- [Pinned README](https://github.com/apple/swift-collections/blob/671108c96644956dddcd89dd59c203dcdb36cec7/README.md): 1.1.x requires Swift 5.7.2 / Xcode 14.2 or later, no minimum deployment target; describes ordered uniqueness, deque structure, modular imports, and compatibility policy. These are pinned facts, not latest-version claims.
- [Pinned license](https://github.com/apple/swift-collections/blob/671108c96644956dddcd89dd59c203dcdb36cec7/LICENSE.txt): Apache 2.0 with Runtime Library Exception. Preserve applicable license/notices and have the consuming organization review intended redistribution/modification conditions. No organization review occurred here.
- [Complete pinned tree](https://api.github.com/repos/apple/swift-collections/git/trees/671108c96644956dddcd89dd59c203dcdb36cec7?recursive=1): fetched successfully, 692 entries, `truncated=false`, no `.xcprivacy` paths. This only checks filenames. Manifest/README/license/tree inspection is not an implementation audit, app-level privacy review, or security certification.

The upstream files were read through `curl -L --fail --max-time 25` using the exact URLs above (raw.githubusercontent.com for the three text files), with outputs in `/private/tmp/ios-learning-collections-*`. Nothing was installed or added to the package graph.

## Next experiment and removal contract

Define duplicate selection as a no-op preserving initial position; remove then reselect appends. Reject unknown IDs against the catalog. Compile the adapter in an isolated authorized consumer at the pin, check duplicate/removal/replay cases, then measure only if workload evidence justifies it. Record operation sizes/mix, optimization mode, destination, raw repeated samples, memory, and correctness.

Owner: the adopting feature's maintainer, with platform review for shared distribution. Keep the public surface feature-owned. Restore the local implementation if correctness changes or supported compiler/build configurations fail. Review proposed release notes and toolchain floors before an upgrade; retain requirement and resolved revision for rollback.

Pending: vendor installation/build/API execution, relevant implementation privacy/API inspection, organization license review, representative runtime/build measurements, proposed-release assessment. No speedup, app size, privacy approval, or migration success is asserted.
