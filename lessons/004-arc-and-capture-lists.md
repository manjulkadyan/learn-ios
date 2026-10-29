# Session 004 — ARC and capture lists

Prepared on 26 October 2026, Asia/Calcutta. Estimated time: 45 minutes. Earlier exercises remain pending.

## Day plan

| Time | Activity | Outcome |
| --- | --- | --- |
| 5 minutes | Recall reference types and escaping callbacks | Explain how a stored callback can outlive the call that created it |
| 10 minutes | ARC, strong/weak references, and capture lists | Draw the references in a retain cycle |
| 10 minutes | Read the cancellation callback in the iOS client | Identify what the callback retains |
| 15 minutes | Reproduce and repair a closure cycle | Show deallocation and safe callback behavior |
| 5 minutes | Review ownership choices | Explain weak capture versus temporary strong retention |

## Objective and recall

Explain why a screen stays in memory after navigation away. Recall: classes are reference types; callbacks can escape their creating function. `@escaping` does not make a closure weak or move it to a background thread.

## Start from Java and Android

JVM GC can collect cycles unreachable from GC roots. Android's ART also uses GC, with a different implementation from HotSpot. A singleton-held listener can still keep an Activity reachable.

Swift's ARC keeps class instances alive while strong references remain. A stored closure capturing its owner creates a loop that ARC cannot automatically collect:

```text
Screen --strong--> stored callback --strong--> Screen
```

Setting `screen` to `nil` removes one reference, leaving the loop intact. `deinit` runs on deallocation; it cannot clean up a cycle that prevents deallocation.

The analogous Kotlin shape is:

```kotlin
class Screen {
    var onTap: (() -> Unit)? = null

    fun installCallback() {
        onTap = { println(this.toString()) }
    }
}
```

The Kotlin cycle alone need not leak; a GC-root path matters. The Swift cycle itself retains the instance.

## Capture ownership

```swift
final class Screen {
    var onTap: (() -> Void)?

    func installCallback() {
        onTap = { [weak self] in
            guard let self else { return }
            self.render()
        }
    }

    func render() { print("Render") }
    deinit { print("Screen released") }
}
```

`[weak self]` captures without retaining the screen. Inside, `self` is optional and becomes `nil` after release. `guard let self` exits if absent; otherwise it creates a strong local binding for this work.

| Reference | Keeps its target alive? | If the target is released |
| --- | --- | --- |
| Strong | Yes | Release requires removing the remaining strong ownership |
| Weak | No | Reference becomes `nil` |
| Unowned | No | Reading a normal unowned reference traps if its target is gone |

Use weak when a callback can outlive the screen; unowned requires a lifetime guarantee. Strong capture can retain a dependency until work completes. Choose based on ownership.

## Read your project

Read [CancelAppointmentViewController.swift](../../ios-client/Projects/Features/ZDAppointments/Sources/ZDAppointmentsCancellation/CancelAppointmentViewController.swift), lines 85–97, and the view's [Actions container](../../ios-client/Projects/Features/ZDAppointments/Sources/ZDAppointmentsCancellation/Views/CancelAppointmentViewController.View.swift). Trace controller → view → actions → callback, then the weak link back to the controller.

Read [CancelAppointmentNavigationCoordinator.swift](../../ios-client/Projects/Features/ZDAppointments/Sources/ZDAppointmentsCancellation/CancelAppointmentNavigationCoordinator.swift), lines 64–79. After `guard let self`, the nested `Task` captures strong `self`. This shows retention, not proof of a permanent cycle; cancellation needs separate review.

Android's [BookingActivityNew.kt](../../android-client/app/src/main/java/com/zocdoc/android/booking/view/BookingActivityNew.kt), lines 310 and 1940, uses `WeakReference` for instance tracking: a similar ownership mechanism in another feature, with different collection timing.

## Exercise — 15 minutes

Prerequisite: a Swift playground or standalone file. Create a class with a stored `onTap` closure and a `deinit` print. Install a strongly capturing callback, observe the instance through a `weak var probe`, and remove the external strong reference. Explain why the probe still sees it, then explicitly clear the callback to clean up the demonstration.

Repeat using `[weak self]`. Keep a separate copy of the callback, release the screen, and invoke that callback again. It should safely do nothing or report that the screen is gone. Predict how `[unowned self]` would behave; do not run the crashing version.

Acceptance: draw both ownership graphs, observe the weak probe becoming `nil` after release, and explain why a weak callback still needs an optional check. Without a compiler, annotate the repository callbacks and predict each lifetime.

## Verification and reflection

The [isolated example](../examples/004-arc-and-capture-lists.swift) ran with Swift 6.4. It demonstrated strong-cycle cleanup, weak capture, and temporary retention by queued work. Verification did not require an iOS app build; learner completion remains pending.

Run from the workspace root:

```sh
xcrun swift -module-cache-path /private/tmp/ios-learning-module-cache ios-learning/examples/004-arc-and-capture-lists.swift
```

Key output:

```text
strong cycle keeps screen alive: true
strong cycle cleaned up: true
weak capture allows release: true
callback skipped: screen is gone
queued work keeps owner alive: true
cleared work releases owner: true
```

1. Why can a cycle disappear under JVM GC yet remain under Swift ARC?
2. Why does `guard let self` inside a weak callback introduce a strong binding?
3. What lifetime guarantee would justify choosing unowned instead of weak?

<details>
<summary>Answer hints — attempt the questions first</summary>

1. GC checks root reachability; an ARC cycle still contains owning references.
2. Successfully unwrapping supplies a strong reference for the work using it.
3. The target must outlive every use through that reference, including escaped callbacks.

</details>

References: [Swift ARC](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/), [Swift closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/), and [Android memory management](https://developer.android.com/topic/performance/memory-overview). Swift claims were checked against the corresponding official book source chapters.

Reply with your two ownership graphs and predicted or actual output. Session 005 will map Xcode targets and schemes, Swift packages, and Tuist to Gradle concepts.
