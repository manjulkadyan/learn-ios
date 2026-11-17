import SwiftUI
import WorkshopKit

@main
struct PackageDemoApp: App {
    var body: some Scene {
        WindowGroup { CatalogLoaderView() }
    }
}

struct CatalogLoaderView: View {
    @State private var catalog: Catalog?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if let catalog { PackageCatalogView(catalog: catalog) }
                else if let message {
                    VStack {
                        Text(message)
                        Button("Retry local load", action: load)
                    }.padding()
                } else { ProgressView("Loading local notebooks") }
            }
            .task { load() }
        }
    }

    private func load() {
        // Only a tiny bundled fixture. Large IO needs a separate scheduling policy.
        do { catalog = try Catalog.bundled(); message = nil }
        catch { catalog = nil; message = "The local notebook resource could not be loaded: \(error)" }
    }
}
