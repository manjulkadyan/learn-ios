// Deliberately cyclic synthetic fixture for learning a retaining-path investigation.
// Not included in the native app unless the learner adds it to a scratch target.
// Do not use this ownership pattern as application guidance.
final class RetentionFixture {
    private var callback: (() -> Void)?
    private(set) var taps = 0

    init() {
        callback = { self.taps += 1 }
    }

    func invoke() { callback?() }

    // Call while an external owner is still present, before discarding that owner.
    func stop() { callback = nil }
}

func checkSyntheticRetention() {
    weak var observed: RetentionFixture?
    var owner: RetentionFixture? = RetentionFixture()
    observed = owner
    owner?.invoke()
    precondition(observed?.taps == 1)
    owner = nil
    precondition(observed != nil) // The deliberate closure cycle remains.
    observed?.stop()
    precondition(observed == nil) // With the strong cycle broken, nothing owns it.
}
