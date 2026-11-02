import Foundation

/// Objective-C compatible KVO model; the app confines writers to UIKit's main thread.
final class CounterRecord: NSObject {
    @objc dynamic var count = 0
}
