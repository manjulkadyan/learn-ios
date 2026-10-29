# Session 002 — Swift enums and Kotlin sealed states

Delivered manually on 15 October 2026 at the learner's request. Estimated time: 30–45 minutes. Exercises for sessions 001 and 002 remain pending; delivery does not establish completion.

## Objective and recall

Model an action or UI state as mutually exclusive cases, with the right data attached to each case. This helps the compiler catch forgotten behavior and reduces contradictory states in navigation and rendering.

Before starting, recall session 001: assigning a Swift struct copies its value semantics; assigning a Kotlin data-class instance shares its reference. Swift enums also have value semantics. A class reference inside an associated value can still be shared.

## Start from a Kotlin sealed class

Your Android client already has this pattern in [PreAppointmentLocationState.kt](../../android-client/app/src/main/java/com/zocdoc/android/appointment/preappt/components/location/state/PreAppointmentLocationState.kt):

```kotlin
sealed class PreAppointmentLocationState {
    data class GetDirections(val locationUri: String) : PreAppointmentLocationState()
    data class ContactDoctor(val phoneNumber: String) : PreAppointmentLocationState()
}

fun describe(state: PreAppointmentLocationState): String = when (state) {
    is PreAppointmentLocationState.GetDirections -> "Directions: ${state.locationUri}"
    is PreAppointmentLocationState.ContactDoctor -> "Contact: ${state.phoneNumber}"
}
```

Each subtype identifies an action and carries its own data. Swift expresses this using an enum with associated values:

```swift
enum LocationAction: Equatable {
    case getDirections(locationURI: String)
    case contactDoctor(phoneNumber: String)
}

func describe(_ action: LocationAction) -> String {
    switch action {
    case let .getDirections(locationURI):
        return "Directions: \(locationURI)"
    case let .contactDoctor(phoneNumber):
        return "Contact: \(phoneNumber)"
    }
}

let action = LocationAction.getDirections(locationURI: "geo:0,0")
print(describe(action))
```

`case` declares a possible variant. `locationURI: String` is data supplied when creating that variant. `case let` matches the variant and binds its payload to a local constant. `case .getDirections(let locationURI)` is another spelling of the same binding.

`_` before the function's parameter means the call has no argument label: `describe(action)`. Conversely, `locationURI:` is the case constructor's argument label. Swift can infer the enum type when context is available: `let action: LocationAction = .getDirections(locationURI: "geo:0,0")`.

| Kotlin | Swift | Important boundary |
| --- | --- | --- |
| Sealed subtype carrying fields | Enum case carrying associated values | Swift cases are variants, not classes you subclass |
| `when` with `is` and smart casts | `switch` with pattern bindings | Binding extracts data from the matched case |
| Data-class generated equality | Enum `Equatable` conformance | Synthesis requires every associated type to be `Equatable` |
| Reference-type sealed instances | Value-type enum instances | Nested class payloads can still share references |

For a local enum, a `switch` must cover every case or include a catch-all such as `default`. Covering cases explicitly means adding a new action exposes consumers that need a decision. A `default` branch can hide that work. Public non-frozen enums from resilient libraries have additional rules, including `@unknown default`; we will cover those with module/API design.

## Read the iOS project

In [CancelAppointmentNavigationCoordinator.swift](../../ios-client/Projects/Features/ZDAppointments/Sources/ZDAppointmentsCancellation/CancelAppointmentNavigationCoordinator.swift), `NavigationState` has two cases: `.question(CancelAppointmentQuestionData)` and `.bookingPrompt`. The switch in `generateViewController` extracts `questionData` only for the question case. A booking prompt cannot accidentally contain an unrelated question payload.

These are similar state/action modeling patterns across the two clients, not matching implementations of one feature.

Also compare [CancellationReason.swift](../../ios-client/Projects/Features/ZDAppointments/Sources/ZDAppointmentsCancellation/CancellationReason.swift): it declares `enum CancellationReason: String`. Those strings are raw values, fixed for each case. Associated values are supplied per instance. Here, a fixed API identifier belongs in a raw value; screen-specific question data belongs in an associated value. These two enum forms cannot be combined in a single raw-value enum.

## Practice — 15–20 minutes

Create an isolated Swift `SearchState` with `.idle`, `.loading`, `.loaded(providers: [String])`, and `.failed(message: String)`. Implement a function returning text for every state without `default`. Show four inputs and outputs, including an empty loaded array. Use `if case let .loaded(providers) = state` to extract providers in a conditional.

Temporarily add `.offline` and observe the compiler requiring your switch to handle it. Decide whether the app needs an explicit offline state or whether a failure payload is sufficient, and explain the product behavior behind your choice.

Acceptance: every state has explicit handling, only loaded state carries providers, only failure carries its message, and you can explain why multiple independent booleans would permit contradictory states. A playground or standalone Swift file is sufficient. Without a compiler, write the switch and identify the branch required by `.offline`.

## Questions

1. How does an associated value differ from a raw value?
2. What happens when you add a case but leave an exhaustive local switch unchanged?
3. Is `.loaded([])` necessarily the same as `.idle`? What product decision determines that?

<details>
<summary>Answer hints — attempt the questions first</summary>

1. Associated values vary per constructed instance; a raw value is fixed for each case.
2. The compiler rejects the switch until it handles the new case.
3. Usually they differ: an empty result can mean a completed search, while idle means a search has not started; UI requirements determine the distinction.

</details>

## Verification and next step

The isolated example is [002-enums-and-sealed-states.swift](../examples/002-enums-and-sealed-states.swift). It ran successfully with the installed Swift 6.4 compiler using `xcrun swift -module-cache-path /private/tmp/ios-learning-module-cache ios-learning/examples/002-enums-and-sealed-states.swift` from the workspace root. Output confirmed payload extraction, an unchanged original enum value, all four search-state branches, and `nil` for an unknown raw value.

A separate deliberately incomplete switch was rejected with `error: switch must be exhaustive` and `note: add missing case: '.offline'`. This was the expected result of the missing-case demonstration. No iOS app build was needed; learner completion remains pending.

Reference: [The Swift Programming Language — Enumerations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/).

Reply with your enum, rendering function, and explanation of the empty-result case. The next lesson is protocols, extensions, closures, and error handling.
