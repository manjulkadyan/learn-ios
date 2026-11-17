# MapProject: fictional places with a real MapKit boundary

This is original teaching source, not a completed native app or learner submission. Fictional destinations and synthetic host route summaries are local data. App/ contains actual SwiftUI, MapKit search/directions, and Core Location integration. Host checks never call them.

## Files and ownership

- Core/MapDomain.swift: validated coordinates, stable destination IDs, local attempt generations, retained-place search presentation, shared fresh/cached estimate text, route intent and injected-time cache.
- Host/Checks.swift: meaningful offline validation, stale success/error, independent request lanes and cache boundary checks.
- App/MapServices.swift: real MKLocalSearch and MKDirections operations, owned Task handles, cancellation plus final generation checks, in-memory MKRoute cache.
- App/LocationService.swift: explicit When In Use authorization and one-fix request, freshness/accuracy checks and simulation fallback.
- App/MapScreen.swift: modern iOS 17 Map content/camera/selection, readable destination buttons and route recovery.
- App/MapProjectApp.swift: isolated app entry.

Coordinates are supplied examples near 37.33/-122.03; the named destinations are made up. Constructing coordinate values does not read GPS. A displayed Apple map can load provider tiles/data even with local markers. Cached MKRoute values are neither app-owned offline tiles nor turn-by-turn navigation.

## Run the offline host checks

From the ios-learning workspace directory:

```sh
swift --version
swiftc -swift-version 6 -module-cache-path /private/tmp/map-host-module-cache course/labs/MapProject/Core/MapDomain.swift course/labs/MapProject/Host/Checks.swift -o /private/tmp/map-project-checks
/private/tmp/map-project-checks
```

Actual author verification on 17 November 2026: Apple Swift 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1), arm64-apple-macosx26.0; compiler exit 0, executable exit 0. Output:

```text
PASS coordinate validation, decoded invalid input, inclusive bounds
PASS duplicate rejection and stable identity after reorder
PASS old success/error, cancellation invalidation, independent lanes
PASS search cancel/edit/blank status, retained places, late-result and invalid-catalog recovery
PASS cache mode/direction, exact expiry, backward clock rejection
PASS fresh/cache-hit text retains distance/duration/age, exact expiry and invalid-summary recovery
MapProject: 6 behavior groups passed; no MapKit or location requests
```

The gates are local request authority, not provider revisions or proof of instant resource shutdown. Synthetic RouteSummary(420 metres, 300 seconds) is only a host input for cache and presentation checks. Uptime-based native cache lasts strictly less than 60 seconds, keys exact origin/destination/mode and is bounded to eight entries. No disk cache or persistent provider-data license is implemented.

The final focused review run also executes PlaceSearchSnapshot's actual shared cancel/edit/blank transitions. isSearching becomes false; the cancelled or input-changed message replaces Searching; accepted places remain. A blank query overrides that generic message with its specific prompt. Old successes/errors cannot overwrite those states, and an invalid candidate leaves accepted places intact.

Both fresh and cached native routes use routeEstimateText. The host's synthetic 420 metres/300 seconds formats as "Apple estimate: about 420 metres; 5 minutes." Fresh adds "Fresh response."; a cache hit at injected age 59 adds "Cached response, 59 seconds old (expiry at 60 seconds)." These are presentation-template checks, not Apple-supplied host data. Lookup at 60 expires, and invalid/expired summaries offer recovery. The native routeMessage remains outside the conditional Map branch, preserving readable distance/duration/freshness when Map is hidden; no simulator interaction was performed.

## Create an isolated Xcode target

1. Outside the company client, choose File > New > Project > iOS > App. Name it MapProjectLab, Interface SwiftUI, Language Swift, bundle ID org.example.MapProjectLab. Use a simulator destination; no account or distribution signing is needed for this source/typecheck exercise.
2. Set deployment target iOS 17.0, Swift Language Version Swift 6, and Default Actor Isolation Nonisolated. Explicit @MainActor declarations own UI/services; do not silently apply a project-wide isolation setting to the portable Core types.
3. Remove the generated app entry and ContentView from target membership to avoid two @main declarations. Add exactly Core/MapDomain.swift and all four App/ files to the app target. Do not add Host/Checks.swift, which has another @main.
4. In target Info, add Privacy - Location When In Use Usage Description (NSLocationWhenInUseUsageDescription): "Use one location fix as an optional route origin when you press the location button." No Always usage description or background location mode is needed.
5. Build and launch the isolated target. Initial state is the fictional text catalog, with the Apple Map branch hidden. Show Apple map, Apple search and Apple directions are explicit controls and may use network data. The location service is configured at init but asks for no permission/fix until Request my location once.
6. Prefer simulator location injection for the first experiment. A received fix changes the route origin only after the separate toggle. Permission denial/restriction keeps simulation usable. An initial authorization callback without wantsFix does not request a fix.

The LabState alias names SwiftUI.State's existing property-wrapper type. In this author SDK, direct @State resolved to a newer same-name macro whose plugin could not start its nested sandbox. The alias resolves the existing type without changing its state contract. Initial compiler attempts failed on that macro; the final command below passed without macro execution or a sandbox permission change.

## Native source verification

Actual toolchain: Xcode 27.2, build 27B52; iPhoneSimulator27.2 SDK. This exact final source command returned exit 0 with no source diagnostics:

```sh
xcrun --sdk iphonesimulator swiftc -typecheck -swift-version 6 -target arm64-apple-ios17.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.2.sdk -module-cache-path /private/tmp/map-native-module-cache course/labs/MapProject/Core/MapDomain.swift course/labs/MapProject/App/*.swift
```

This checks the actual SwiftUI/MapKit/location source against iOS 17 availability with a current SDK. It does not link an executable or create/sign/install an Xcode project. Installed SDK headers identify MKLocalSearch base availability iOS 6.1 and MKDirections iOS 7.0. The _MapKit_SwiftUI interface identifies MapCameraPosition, MapContentBuilder and MapPolyline iOS 17.0; Apple's MapCameraPosition documentation was also retrieved. Legacy MKPlacemark/MKMapItem constructors remain usable for the deployment target; future SDK deprecations are distinct from unavailability.

## Required learner evidence, currently unperformed by the author

- Linked isolated app build and actual launch on a named simulator/device.
- Camera pan, text/marker shared selection, accepted search replacement clearing selection, blank query cancellation and independent route invalidation.
- Apple tiles/search/directions availability, provider failure/no-route and real cancellation behavior. None was requested during author verification.
- Permission prompt, denied/restricted state, approximate/precise fix and stale/invalid fix recovery. No real location was requested.
- Large text, VoiceOver focus and readable route/provenance messages.
- Physical-device location/accuracy/energy and navigation suitability. This lab supplies no navigation feature or device measurements.

Core Location delegate observations do not carry the search request token. The service ignores callbacks while stopped and checks recent usable fixes; it does not promise exact request-to-fix correlation or instant hardware stopping. MainActor is isolation, not a dedicated task thread; await requires rechecking current intent.

## Independent work

Add demo:ink, rename/reorder it while retaining selection, add a third-origin cache miss, and create an old error after newer success. Predict values before running. In the native target, independently record selection, permission simulation and recovery outcomes. A copied answer or these author checks do not record learner completion.

Official references: [MapCameraPosition](https://developer.apple.com/documentation/mapkit/mapcameraposition), [MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections), [location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services).

