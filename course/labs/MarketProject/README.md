# MarketProject: original synthetic asset explorer

This is read-only teaching source, not a completed learner app, live feed or trading tool. Luma, Pebble and their USD prices/history are entirely made up. The default SwiftUI app decodes local source data and intentionally has no remote icon URLs. Separately supplied service/image adapters use actual URLSession/Combine/async/UIKit integration but no real endpoint is contacted automatically.

## Files and contract

- Core/MarketDomain.swift: DTO/domain validation, bounded Decimal-string parsing, synthetic JSON, snapshot generation and publish-after-save favorites store.
- Host/Checks.swift: exact arithmetic, duplicate identity/time, synthetic HTTP response validation, stale/cancelled snapshot schedules and preference recovery.
- Host/ServiceChecks.swift: real Combine and async URLSession adapters executed with an injected offline URLProtocol.
- App/MarketServices.swift: default fixture publisher, HTTP publisher, separate async HTTP implementation and observable UI model.
- App/RemoteIcon.swift: real optional image publisher with separate resource generation/cancellation and placeholder.
- App/MarketScreen.swift: local search, favorites filter, ID-based detail, Swift Charts and exact sample text.
- App/MarketProjectApp.swift: isolated app entry.

HTTP schema: array of id/symbol/name/priceUSD/points and optional iconURL. priceUSD and point amount are unsigned decimal strings, maximum eight fractional digits and maximum 37 text characters; no exponent, commas or numeric prefixes. IDs are bounded lowercase letters/digits/hyphens starting with a letter. Point seconds are Int64 and strictly increasing, with at most 1,000 points per asset. Currency is explicitly USD in this synthetic contract.

Decimal preserves accepted base-ten amounts within bounded precision; it is not arbitrary-precision BigDecimal. Chart receives a Double copy for geometry. Core's canonicalDecimalText uses POSIX NSDecimalString directly on Decimal; exactSampleText adds USD. The exact detail price and sample rows use this shared helper, while priceText retains the two-fractional-digit currency overview. No balance, quantity, trade, settlement rounding or investment advice is implemented.

## Offline commands and actual results

Run from ios-learning. Author toolchain on 17 November 2026: Apple Swift 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1), arm64-apple-macosx26.0.

```sh
swiftc -swift-version 6 -module-cache-path /private/tmp/market-host-module-cache course/labs/MarketProject/Core/MarketDomain.swift course/labs/MarketProject/Host/Checks.swift -o /private/tmp/market-project-checks
/private/tmp/market-project-checks
```

Compiler exit 0; executable exit 0:

```text
PASS decimal grammar/arithmetic, duplicate assets, duplicate sample times
PASS tiny/high-precision canonical sample text, value round-trip, zero normalization
PASS HTTP status and MIME before decode; synthetic response only
PASS old success/error, cancellation invalidation, last-known rows
PASS favorite idempotence/reopen, failed-write rollback, corruption preserved, version refusal
MarketProject: 5 behavior groups passed; no HTTP or image requests
```

Favorites checks use a unique temporary directory and remove it. Missing storage starts empty, corruption/future version is refused without replacing bytes, and an injected failing writer leaves old memory intact. Data.atomic and ordinary reopen are not proof of power-loss durability or coordinated multiwriter correctness. Native writes are small synchronous teaching operations, not a hidden asynchronous storage implementation.

The final host run also rejects a final newline in amounts/IDs, rejects 38-character numeric input beyond the declared length bound, preserves a duplicate-ID store after rejection, and proves that invalidating a separate resource gate leaves the snapshot gate current. Regular expressions use the true end-of-input anchor rather than an anchor that can match before a final newline. This resource test checks local authority, not native icon download or cancellation delivery.

The focused formatter checks assert exactSampleText(0.00000001) == "USD 0.00000001" and exactSampleText(12.345678) == "USD 12.345678", plus decode-format-decode Decimal equality. Canonical text removes redundant zeroes: input 00012.34000000 becomes 12.34, and zero becomes 0. It preserves the accepted numeric value rather than the original spelling or scale. A rounded US-dollar overview may show $0.00 or $12.35; it is intentionally distinct from these exact samples. These passed host assertions are not a native locale/screenshot check.

```sh
swiftc -swift-version 6 -module-cache-path /private/tmp/market-service-module-cache course/labs/MarketProject/Core/MarketDomain.swift course/labs/MarketProject/App/MarketServices.swift course/labs/MarketProject/Host/ServiceChecks.swift -o /private/tmp/market-service-checks
/private/tmp/market-service-checks
```

Compiler exit 0; executable exit 0:

```text
PASS actual Combine and async URLSession adapters through offline URLProtocol
PASS adapter status, MIME and malformed JSON failure for both boundaries
MarketProject: 2 offline adapter groups passed; no remote endpoint contacted
```

FixtureURLProtocol intercepts fixture.invalid using an ephemeral session. These execute actual adapter pipelines, with local 200 JSON, 503 JSON, 200 HTML and malformed JSON responses; they do not use DNS, sockets, a live feed or remote TLS. They do not exercise MarketModel initialization or write the author's Application Support preferences.

## Create an isolated Xcode target

1. Create a new iOS App in a scratch directory, named MarketProjectLab, SwiftUI interface, Swift language, bundle ID org.example.MarketProjectLab. Choose a simulator for initial work.
2. Set minimum iOS 17.0, Swift Language Version Swift 6 and Default Actor Isolation Nonisolated. The model/loader explicitly use @MainActor.
3. Remove the generated app/ContentView target membership. Add exactly Core/MarketDomain.swift and all four App/ files. Do not include either Host file: each contains a separate @main.
4. No remote package, service account, location permission or secret is needed. Foundation, Combine, SwiftUI, UIKit and Charts are Apple SDK frameworks.
5. Build/launch the isolated app. It automatically loads only the synthetic fixture. Load/refresh and Simulate refresh failure are local controls. Search and Favorites only also operate locally.
6. Native favorites live under Application Support/SyntheticMarketLab/favorites.json within the app sandbox. A malformed or future-version file disables writes and remains preserved. Inspect/export it before any intentional repair.
7. To exercise real HTTP deliberately, supply an approved HTTPS schema-compatible endpoint and injected session to HTTPMarketService or AsyncHTTPMarketService. The default app constructs neither remote service. Remote icon behavior is enabled only by deliberately adding an approved HTTPS URL to a fixture/response.

LabState aliases the existing SwiftUI.State property-wrapper type. Direct @State initially selected a newer SDK macro whose plugin nested sandbox failed; the alias removes that tool dependency without changing state ownership. Final source typechecking passed.

## Native source command and evidence

Actual SDK/toolchain: Xcode 27.2 build 27B52, iPhoneSimulator27.2. This final command passed (exit 0, no source diagnostics):

```sh
xcrun --sdk iphonesimulator swiftc -typecheck -swift-version 6 -target arm64-apple-ios17.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.2.sdk -module-cache-path /private/tmp/market-native-module-cache course/labs/MarketProject/Core/MarketDomain.swift course/labs/MarketProject/App/*.swift
```

Combine base APIs begin on iOS 13; NavigationStack and Charts begin on iOS 16; URLSession async data APIs use the modern async-support availability (iOS 15+). The project deliberately targets 17 for the used SwiftUI overloads. @Published is observation, receive(on:) downstream scheduling and @MainActor state isolation; none alone establishes latest-result relevance. Each final commit checks its lane's generation. Cancelling Future does not automatically cancel a Task hidden inside it.

## Explicit limits and pending checks

The author did not link/sign/install/launch either native app or use a simulator/device UI. Large text, VoiceOver, swipe discoverability, locale formatting, detail disappearance and process restoration are pending runtime experiments. No remote provider, feed accuracy, TLS/pinning/authentication, redirect/rate-limit behavior or icon download was checked. URLProtocol is local integration evidence only.

HTTP and image caps are checked after URLSession buffers bodies. They are accepted-input caps, not streaming transfer or peak-memory bounds. The optional icon cap is 262,144 encoded bytes; a small compressed image can decode to a huge bitmap. The 32-point frame does not downsample. This basic UIImage adapter has no dimension inspection, downsampling, request coalescing or app-owned bitmap cache; system URL caching is a different policy. There is no persistent quote cache or continuous live-price stream. No device performance, memory or energy claims were measured.

## Independent learner capstone

Add original Ember data, new filter/detail predictions, a failed favorite save, and separate resource/snapshot cancellation schedules. Compare both adapters on a new intercepted failure. Record exact toolchain/commands/outcomes and keep unperformed runtime/provider rows pending. Supplied answers and author verification do not record completion.

Official references: [DataTaskPublisher](https://developer.apple.com/documentation/foundation/urlsession/datataskpublisher), [Future](https://developer.apple.com/documentation/combine/future), [Decimal](https://developer.apple.com/documentation/foundation/decimal), [Chart](https://developer.apple.com/documentation/charts/chart).

Optional later course reading: [lesson 018: HTTP and production data](../../index.html#lesson/018) and [lesson 024: reliability and observability](../../index.html#lesson/024). These links use the local course reader; neither lesson is a prerequisite for this project.

