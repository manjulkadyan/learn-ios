import SwiftUI
import WorkshopKit

/// Source adapter for a separate scratch iOS app. The package has no SwiftUI dependency.
struct PackageCatalogView: View {
    let catalog: Catalog

    var body: some View {
        List(catalog.cards) { card in
            VStack(alignment: .leading) {
                Text(card.title).font(.headline)
                Text("\(card.minutes) minutes").font(.subheadline)
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("Local notebooks")
    }
}
