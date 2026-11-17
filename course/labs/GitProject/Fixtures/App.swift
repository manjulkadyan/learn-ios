import SwiftUI

// A real target-required SwiftUI entry; the Git runner reviews its tracked bytes only.
// This fixture does not load Theme.json. Resource loading is the independent exercise.
@main
struct GitScratchApp: App {
    var body: some Scene {
        WindowGroup { Text("Pocket Tasks resource experiment").padding() }
    }
}
