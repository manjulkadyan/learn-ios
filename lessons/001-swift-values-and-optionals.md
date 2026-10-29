# Session 001 — Swift bindings, optionals, and value semantics

Delivered manually on 15 October 2026. Estimated time: 30–45 minutes. Learner exercise: pending.

## Objective

Predict what happens when you assign and mutate a Swift model, and read nullable fields in the iOS client. This matters because a mistaken assumption about shared state can turn a form edit into an unintended change elsewhere.

## Start from Kotlin

You already know bindings and nullability. Swift uses `let` for a binding you cannot reassign and `var` for a mutable one. `String?` is an optional string: it contains a string or `nil`. Kotlin's `String?` and `null` are useful starting comparisons; Swift's optional is a language type with explicit unwrapping behavior.

| Kotlin/Java | Swift | Meaning |
| --- | --- | --- |
| `val name = "A"` | `let name = "A"` | Binding cannot be reassigned |
| `var name = "A"` | `var name = "A"` | Binding can change |
| `String?` / `null` | `String?` / `nil` | Value may be absent |
| `name ?: "Unknown"` | `name ?? "Unknown"` | Fallback for an absent value |
| `name?.length` | `name?.count` | Access only if present; these length APIs differ in Unicode semantics |
| Kotlin data class | Swift struct | Similar model syntax; assignment semantics differ |

Swift does not add Kotlin-style `copy()` simply because you declare a struct. You normally assign a value to a new variable and mutate that variable. Equality also needs an appropriate conformance such as `Equatable`.

## The first critical difference

Kotlin data classes are reference types. Here, both variables refer to the same instance:

```kotlin
data class Draft(var providerName: String, val patientName: String?)

val original = Draft("Dr. A", null)
val edited = original
edited.providerName = "Dr. B"
println(original.providerName) // Dr. B
```

For a separate Kotlin object you could use `original.copy()`. That is a shallow copy: nested mutable objects can remain shared.

Swift structs have value semantics:

```swift
struct Draft {
    var providerName: String
    var patientName: String?
}

var original = Draft(providerName: "Dr. A", patientName: nil)
var edited = original
edited.providerName = "Dr. B"
print(original.providerName) // Dr. A
print(edited.providerName)   // Dr. B
```

Reason about independently owned values, not a promise that Swift physically copies every byte immediately. Optimizations can preserve the same observable behavior. A struct holding a class reference still points to that class object after assignment; value semantics are not automatic deep cloning.

Swift classes have reference semantics, like ordinary Kotlin/Java objects. `let object = SomeClass()` prevents reassigning `object` but can still allow changing its `var` properties. With `let value = SomeStruct()`, you cannot assign a new value to one of that struct's stored `var` properties, because that would mutate the bound value. A class nested inside the struct can still be mutable.

## Read your project

Open [CancelAppointmentQuestionData.swift](../../ios-client/Projects/Features/ZDAppointments/Sources/ZDAppointmentsCancellation/CancelAppointmentQuestionData.swift). Identify `struct`, its immutable `let` fields, `subtitle: String?`, and the computed `asNavigationState` property. `Hashable` is a conformance used for equality/hashing; it does not create reference identity.

Compare the nullable fields in [TriageSpecialtyProcedurePair.kt](../../android-client/database/src/main/java/com/zocdoc/android/database/repository/mht/TriageSpecialtyProcedurePair.kt). These are similar language patterns, not implementations of the same feature. Its `val` fields prohibit setting those fields, but the Kotlin model remains a reference type. `Parcelable` is Android transport machinery and is unrelated to Swift value semantics.

## Practice — 15–20 minutes

In an isolated Swift file or playground, translate `TriageSpecialtyProcedurePair` into a struct with two optional integer fields. Use `Int64?` if you want to preserve Kotlin `Long`'s signed width. Add defaults of `nil`.

Create `original` with specialty ID 10, assign it to `edited`, and change only `edited` to 20. Print both IDs using `??`, then use `if let` to access an optional's contained value safely. Explain what would change with a Swift class or an assignment to the Kotlin data class. Finally, predict whether changing a stored property through a `let` struct binding compiles.

Acceptance: the original struct still contains 10; the edited value contains 20; the absent procedure ID has a safe fallback; your explanation distinguishes binding immutability from reference identity. Do not edit client production files for this exercise.

## Questions

1. Why is Kotlin `data class` not a one-to-one equivalent of Swift `struct`?
2. Why can a `let` Swift class reference allow property mutation?
3. Would putting a mutable class inside a struct guarantee independent nested state after assignment?

<details>
<summary>Answer hints — read after attempting the questions</summary>

1. Kotlin data classes retain reference semantics; Swift structs have value semantics.
2. `let` fixes the reference binding; it does not freeze the referenced object.
3. No; the struct's copies can share the contained class reference.

</details>

## Verification and next step

The mentor demonstration is [001-value-semantics.swift](../examples/001-value-semantics.swift). It ran successfully with the installed Swift 6.4 compiler using `xcrun swift -module-cache-path /private/tmp/ios-learning-module-cache ios-learning/examples/001-value-semantics.swift` from the workspace root. Its output was:

```text
struct original: Dr. A
struct edited: Dr. B
optional fallback: Unknown
class original: Dr. B
same instance: true
```

This verifies the small teaching example, not an iOS app build. The learner exercise remains pending.

Reference: [The Swift Programming Language — Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/) and [The Basics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/).

Reply with your translated model and predicted output. After reviewing it, we will move to session 002: Swift enums and Kotlin sealed states.
