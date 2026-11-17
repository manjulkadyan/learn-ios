# PackageProject — an offline library and a separate consumer

Original notebook fixtures for lessons 137–140. No company SDKs, real data, credentials, remote package dependencies, or deployment. Reading/copying the example does not complete learner practice.

## Requirements and ownership

Swift tools 6.0 or later; host package declares macOS 13 / iOS 17 minima. The observed compiler is Apple Swift 6.4.2 (`swiftlang-6.4.2.1.9 clang-2100.4.1.1`), host target `arm64-apple-macosx26.0`; Xcode 27.2 build 27B52. A new toolchain is not evidence every older permitted toolchain was exercised.

`PackageProject` is the package; `WorkshopKit` is its library product/target/module. `WorkshopKitTests` uses a normal public import. The resource is owned and loaded by WorkshopKit with `Bundle.module`, never by asking a consumer to locate a filename in `Bundle.main`. `Consumer` is a separate package with a local path dependency and explicit matching deployment floors. Native source is excluded from the SwiftPM target graph and belongs only to an isolated app.

Catalog publishes a complete valid candidate or throws. IDs are unique exact strings; blank IDs/titles and minutes outside 1...240 are invalid. Decoding shape, domain validation, missing resource, and IO failure are different boundaries. The fixture is `blue=15`, `green=25`, total `40`. Loading is synchronous and intentionally tiny; large IO requires a separate scheduling/cancellation policy. No persistence or remote resolution is implemented.

## Reproduce host evidence

From the course's parent `ios-learning` directory:

```sh
bash course/labs/PackageProject/verify-host.sh
```

The script expands the following commands, which were actually executed on 17 November 2026 after redirecting both compiler caches:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/ios-learning-package-modules SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/ios-learning-package-modules swift test --disable-sandbox --package-path course/labs/PackageProject --scratch-path /private/tmp/ios-learning-package-build --cache-path /private/tmp/ios-learning-package-cache
env CLANG_MODULE_CACHE_PATH=/private/tmp/ios-learning-package-modules SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/ios-learning-package-modules swift run --disable-sandbox --package-path course/labs/PackageProject/Consumer --scratch-path /private/tmp/ios-learning-consumer-build --cache-path /private/tmp/ios-learning-package-cache CatalogConsumer
```

Observed: **4 XCTest tests, 0 failures**. Checks cover bundled resource IDs/total/absent lookup, whole-candidate duplicate rejection, corrupt JSON versus out-of-range domain input, inclusive 240, blank values, and independent value copies. The consumer build/run exited 0 and printed:

```text
consumer: 2 cards, 40 minutes
Blue notebook
```

Initial test attempts failed because the default Clang module cache was not writable in the managed environment. `--cache-path` alone did not redirect it; the two environment variables above did. User-level SwiftPM configuration/security cache warnings remained; the local builds/tests succeeded. The first consumer attempt exposed a real macOS minimum mismatch (implicit 12 versus library 13), fixed by explicit consumer platform declarations. No approval, remote install, or client change was required. `bash -n` passed for verify-host.sh.

## Native source check and isolated target setup

```sh
python3 course/labs/PackageProject/check-native.py
```

Executed successfully on 17 November 2026. The script prints exact `xcrun swiftc` commands, emits a WorkshopKit module for `arm64-apple-ios17.0-simulator`, then typechecks both native files using iPhoneSimulator27.2.sdk and Swift 6 language mode. It reuses SwiftPM's actual generated **host** resource accessor. That proves source/module/API acceptance, **not iOS resource-bundle construction or runtime loading**. `-disable-sandbox` allows bundled compiler-plugin subprocesses in this managed environment; no remote plugin is used.

To obtain actual app evidence, create a new scratch Xcode iOS App with SwiftUI/Swift, no storage template, minimum iOS 17, and an unrelated scratch bundle identifier. Save it outside the company client. Add this local package through Xcode's local package option and select the **WorkshopKit** product for the app target. Remove the generated app entry and ContentView from target membership. Add copies of **both** `Native/PackageDemoApp.swift` and `Native/PackageCard.swift` to the app target. Do not add Sources/WorkshopKit or Tests to app membership: SwiftPM supplies the library and its resource rule. There must be exactly one `@main`, PackageDemoApp.

Build for a selected simulator without distribution signing. Launch and verify two rows, Blue=15, Green=25, and combined static accessibility labels. In a separate scratch resource experiment, rename `Sources/WorkshopKit/Resources/cards.json` to `renamed-cards.json` inside the same processed directory. The populated resource bundle and accessor still exist, but the requested `cards.json` URL is absent: `Catalog.bundled()` throws `missingResource`. Restore the filename, then separately corrupt its JSON bytes to exercise `invalidJSON`. Restore the valid fixture afterward. Observe the visible error/retry path only in an actual app run. Xcode project generation, app bundle assembly, launch, simulator interaction, accessibility inspection, and iOS resource load are **pending**, not covered by the command-line typecheck.

The URL guard assumes `Bundle.module` has already located its bundle. Removing the sole processed resource can prevent accessor generation and cause a build failure. If the generated accessor cannot locate the entire bundle at runtime, the inspected accessor calls `fatalError` before the URL guard; `do/catch` cannot turn that trap into `missingResource`. Treat complete bundle delivery as a packaging requirement, distinct from missing a filename inside an existing bundle. The shipped resource has not been renamed or corrupted by this correction.

## Lesson 138 private-access diagnostic

The lesson defines a named `private func resourceDebugLabel() -> String` in a scratch `Catalog` extension, then attempts `print(catalog.resourceDebugLabel())` in the separate consumer. A public consumer control must build first. The failing attempt must report private protection, rather than a nonexistent member or missing module.

```sh
python3 course/labs/PackageProject/check-private-access.py
```

This check reads the exact lesson snippets, copies the local package into a temporary directory, appends the helper there, and builds the normal consumer before adding the deliberate private call. It prints its exact commands and diagnostic. All dependencies remain local, and the original package/resource/consumer files remain unchanged. This is a compiler access-control check, not an app interaction or resource-failure run.

Executed on 17 November 2026 with the Swift 6.4.2 host toolchain recorded above: the script exited **0**. Its public consumer build control exited **0** with the private helper present. After appending the lesson's attempted call, the consumer build exited **1**, as expected, with this specific diagnostic:

```text
error: 'resourceDebugLabel' is inaccessible due to 'private' protection level
note: 'resourceDebugLabel()' declared here
```

The script required that diagnostic and removed its temporary copy. It did not execute the consumer or any native resource-failure interaction. The original consumer's two-card/40-minute runtime evidence remains the earlier recorded run.

## Independent practice and third-party boundary

In a scratch copy add amber=10, predict total 50, update the consumer expectation deliberately, add invalid 0/blank-title cases, and add a filtered public query with inclusive bounds. Keep normal imports and semantic resource access. Submit your own diff and actual output; the supplied tests are reference checks.

`DEPENDENCY_ASSESSMENT.md` records an actual bounded inspection of Collections 1.1.4 primary sources at the checkout revision. No vendor code is installed, compiled, benchmarked, or incorporated. License/privacy review, vendor adapter execution, proposed-release review, representative measurements, binary distribution, and production build compatibility remain separate work. No XCFramework, ABI matrix, signing, or client tests were performed.
