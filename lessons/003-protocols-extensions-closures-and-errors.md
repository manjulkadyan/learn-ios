# Session 003 — Protocols, extensions, closures, and errors

Delivered manually on 16 October 2026, Asia/Calcutta, at the learner's request. Estimated time: 30–45 minutes. Exercises for sessions 001–003 remain pending.

## Objective and recall — 5 minutes

Define a replaceable service, reuse behavior, pass a callback, and handle failure explicitly. These skills let you test feature logic without a network connection.

Recall session 002: `.loaded([])` represents a successful search with no results. `.failed(message:)` represents failure. Today's service must preserve that distinction.

## A protocol defines a contract — 10 minutes

Swift's `protocol` is similar to a Kotlin or Java interface. It states what a conforming type must provide. A struct, class, or enum can conform.

```swift
protocol ProviderServing {
    func providers() throws -> [String]
}

enum ProviderError: Error {
    case offline
}

struct FakeProviderService: ProviderServing {
    let isOffline: Bool

    func providers() throws -> [String] {
        if isOffline {
            throw ProviderError.offline
        }
        return ["Dr. Ada", "Dr. Lin"]
    }
}
```

`[String]` means an array of strings. `: ProviderServing` declares conformance. `: Error` makes the enum usable as a thrown error.

The Kotlin comparison is:

```kotlin
interface ProviderServing {
    fun providers(): List<String>
}

class OfflineException : Exception()

class FakeProviderService(private val isOffline: Boolean) : ProviderServing {
    override fun providers(): List<String> {
        if (isOffline) throw OfflineException()
        return listOf("Dr. Ada", "Dr. Lin")
    }
}
```

Swift includes `throws` in the function contract; Kotlin does not enforce a corresponding declaration at call sites. Swift's ordinary `throws` does not enumerate specific error types like Java's checked exception declarations.

Our fake is synchronous. `throws` permits failure; it creates no background work. A real service may declare `async throws`, which also permits suspension.

## Extensions add behavior

```swift
extension ProviderServing {
    func displayNames() throws -> [String] {
        try providers().map { name in name.uppercased() }
    }
}
```

Every conforming service gains this helper. It uses the protocol's required operation, so it works with a fake or real implementation.

Compare a Kotlin extension:

```kotlin
fun ProviderServing.displayNames(): List<String> =
    providers().map { name -> name.uppercase() }
```

Swift extensions can also add conformance to an existing type and supply default implementations for protocol requirements. Kotlin extensions cannot add interface implementation. Swift extensions cannot add stored properties. Treat extension-only helpers separately from overridable protocol requirements; we will revisit dispatch later.

## Closures and error handling

A closure is a function value, like a Kotlin lambda. `([String]) -> Void` accepts an array and returns no useful value. Swift's `Void` plays a similar role to Kotlin's `Unit`.

```swift
func showProviders(
    service: any ProviderServing,
    onNames: ([String]) -> Void
) {
    do {
        let names = try service.displayNames()
        onNames(names)
    } catch ProviderError.offline {
        print("Offline: retry when connected")
    } catch {
        print("Unexpected error: \(error)")
    }
}

showProviders(service: FakeProviderService(isOffline: false)) { names in
    print(names.joined(separator: ", "))
}
```

`any ProviderServing` stores a conforming value without naming its concrete type. The trailing closure supplies `onNames`; `names in` declares its parameter.

`try` marks a potentially throwing call. It does not catch errors. `do/catch` handles them; another throwing function could propagate them instead. A final catch handles errors outside the specific offline case.

`try?` converts failure to `nil` and discards the error. `try? service.providers() ?? []` makes offline failure look like successful zero results. That erases information needed for retry behavior. `try!` traps if the call throws.

Function closure parameters are nonescaping by default. This callback runs within `showProviders`. A parameter stored for later use requires `@escaping`:

```swift
init(onSelect: @escaping (String) -> Void) {
    self.onSelect = onSelect
}
```

This initializer assumes a declared `onSelect` property; see the complete runnable example. `@escaping` describes lifetime, not threading. Closures can capture surrounding values. We will examine capture ownership in session 004.

## Read your project — 10 minutes

Open [GooglePlaceDetailsServing.swift](../../ios-client/Projects/Infra/ZDModules/Sources/ZDModules/GooglePlaceDetailsServing.swift), lines 12–20. Identify the protocol, `async throws` requirement, and `DIResolver` extension. `Sendable` is a concurrency contract we will study later.

Compare [NotifyMeApiService.kt](../../android-client/app/src/main/java/com/zocdoc/android/notifyme/api/NotifyMeApiService.kt), lines 14–40. It exposes operations through an interface with suspending methods. These files show similar contracts in different features.

Read [CancelAppointmentNavigationCoordinator.swift](../../ios-client/Projects/Features/ZDAppointments/Sources/ZDAppointmentsCancellation/CancelAppointmentNavigationCoordinator.swift), lines 19, 28, and 36. The initializer stores an escaping closure. Lines 79–95 show its throwing invocation and error handling. These are active sources included by the current manifests.

## Practice — 15–20 minutes

Prerequisite: a Swift playground or standalone Swift file. Full app setup is unnecessary.

Create your own `AppointmentServing` protocol with `appointments() throws -> [String]`. Add a fake that returns synthetic appointments, returns an empty array, or throws `.offline`. Add an extension that returns the appointment count. Write a consumer accepting `any AppointmentServing` and a callback, with explicit success and error behavior.

Acceptance: demonstrate all three outcomes; invoke the success callback for an empty array; keep offline failure distinct; explain whether your callback needs `@escaping`. Avoid force unwrapping and `try!`.

Without a compiler, write the code and predicted output. Alternatively, annotate the three repository files and trace contract, implementation lookup, callback lifetime, and error handling.

## Verification

[003-protocols-closures-and-errors.swift](../examples/003-protocols-closures-and-errors.swift) ran successfully with Apple Swift 6.4:

```sh
xcrun swift -module-cache-path /private/tmp/ios-learning-module-cache ios-learning/examples/003-protocols-closures-and-errors.swift
```

```text
Success: DR. ADA, DR. LIN
Offline: retry when connected
Empty success: 0 providers
try? failure is nil: true
Selected: Dr. Ada
```

This verifies the isolated teaching example. The iOS app and Kotlin snippet were not built. Learner completion remains pending.

References: The Swift Programming Language — [Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/), [Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/), [Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/), and [Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/). Claims were checked against the Swift project's corresponding book source chapters because the rendered pages required JavaScript.

## Reflection — 5 minutes

1. What lets the same consumer accept a fake service and a real service?
2. Why does storing a closure parameter require `@escaping`, and does that imply background execution?
3. What user behavior becomes impossible if offline failure is converted to an empty successful result?

<details>
<summary>Answer hints — attempt the questions first</summary>

1. Both conform to the protocol used by the consumer.
2. The closure can outlive the function call; threading is a separate concern.
3. The caller loses the failure reason needed to distinguish retry from no matches.

</details>

Reply with your exercise code and predicted or actual output before advancing. The next lesson is ARC and capture lists.
