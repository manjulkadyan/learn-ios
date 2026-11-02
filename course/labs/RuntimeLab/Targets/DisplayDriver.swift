// Target-required reference: add only to a separate iOS 15+ UIKit app.
// Excluded from the host SwiftPM target. SDK typechecked; no simulator/device run.
import UIKit

@MainActor
final class DisplayDriver: NSObject {
    private var link: CADisplayLink?
    private var elapsed: CFTimeInterval = 0
    func start() {
        stop()
        elapsed = 0
        let next = CADisplayLink(target: self, selector: #selector(tick(_:)))
        next.add(to: .main, forMode: .common)
        link = next
    }
    @objc private func tick(_ link: CADisplayLink) {
        elapsed += link.targetTimestamp - link.timestamp
        // Commit a small synthetic visual step here; no I/O or heavy decode.
    }
    func stop() {
        link?.invalidate()
        link = nil
    }
    // Owner MUST call stop at its chosen lifecycle boundary: link retains target.
}
