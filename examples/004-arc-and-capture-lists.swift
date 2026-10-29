// Isolated ownership demonstration. No client dependencies or asynchronous work.
// The intentionally cyclic example is explicitly cleaned up before returning.

final class StrongCaptureScreen {
    let name = "Strong screen"
    var onTap: (() -> Void)?

    func installCallback() {
        onTap = { print("Tapped: \(self.name)") }
    }

    deinit { print("deinit: \(name)") }
}

func demonstrateStrongCycle() {
    var screen: StrongCaptureScreen? = StrongCaptureScreen()
    screen?.installCallback()
    weak var probe = screen

    screen = nil
    print("strong cycle keeps screen alive: \(probe != nil)")
    probe?.onTap?()

    // Remove the stored callback to break the intentionally created cycle.
    probe?.onTap = nil
    print("strong cycle cleaned up: \(probe == nil)")
    probe = nil
}

final class WeakCaptureScreen {
    let name = "Weak screen"
    var onTap: (() -> Void)?

    func installCallback() {
        onTap = { [weak self] in
            guard let self else {
                print("callback skipped: screen is gone")
                return
            }
            print("Tapped: \(self.name)")
        }
    }

    deinit { print("deinit: \(name)") }
}

func demonstrateWeakCapture() {
    var screen: WeakCaptureScreen? = WeakCaptureScreen()
    screen?.installCallback()
    weak var probe = screen
    let savedCallback = screen?.onTap

    savedCallback?()
    screen = nil
    print("weak capture allows release: \(probe == nil)")
    savedCallback?()
    probe = nil
}

final class DeferredWorkQueue {
    var pending: (() -> Void)?

    func runAndClear() {
        let work = pending
        pending = nil
        work?()
    }
}

final class WorkOwner {
    let name = "Work owner"

    func makeTap(queue: DeferredWorkQueue) -> () -> Void {
        return { [weak self] in
            guard let self else { return }
            // Captures the newly bound strong self, despite the outer weak capture.
            queue.pending = { print("queued work for: \(self.name)") }
        }
    }

    deinit { print("deinit: \(name)") }
}

func demonstrateTemporaryRetention() {
    let queue = DeferredWorkQueue()
    var owner: WorkOwner? = WorkOwner()
    weak var probe = owner
    let tap = owner?.makeTap(queue: queue)

    tap?()
    owner = nil
    print("queued work keeps owner alive: \(probe != nil)")
    queue.runAndClear()
    print("cleared work releases owner: \(probe == nil)")
    probe = nil
}

demonstrateStrongCycle()
demonstrateWeakCapture()
demonstrateTemporaryRetention()
