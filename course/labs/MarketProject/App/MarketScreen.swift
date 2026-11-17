import SwiftUI
import Charts

// An alias selects the property-wrapper type instead of the newer same-name macro.
typealias LabState<Value> = SwiftUI.State<Value>

func priceText(_ amount: Decimal) -> String {
    amount.formatted(.currency(code: "USD").precision(.fractionLength(2)))
}

@available(iOS 17.0, *)
struct MarketScreen: View {
    @StateObject private var model = MarketModel()
    @LabState private var favoritesOnly = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Original synthetic asset explorer. Prices and charts are made up; no live feed or trading.")
                    Text(model.snapshot.message)
                    Button("Load / refresh synthetic snapshot") { model.refresh() }
                    Button("Simulate refresh failure") { model.refresh(fail: true) }
                    Button("Cancel refresh") { model.cancel() }
                    Toggle("Favorites only", isOn: $favoritesOnly)
                    Text(model.persistenceMessage)
                }
                Section("Synthetic assets") {
                    let rows = model.visible.filter { !favoritesOnly || model.favorites.contains($0.id) }
                    if rows.isEmpty { Text("No matching assets. Clear search or disable Favorites only.") }
                    ForEach(rows) { asset in
                        NavigationLink(value: asset.id) {
                            HStack {
                                RemoteIcon(url: asset.iconURL)
                                VStack(alignment: .leading) {
                                    Text(asset.name)
                                    Text(asset.symbol).font(.caption)
                                }
                                Spacer()
                                Text(priceText(asset.priceUSD))
                            }
                        }
                        .accessibilityLabel("\(asset.name), \(priceText(asset.priceUSD)), synthetic")
                        .swipeActions {
                            Button(model.favorites.contains(asset.id) ? "Unfavorite" : "Favorite") {
                                model.toggleFavorite(asset.id)
                            }
                        }
                    }
                }
            }
            .searchable(text: $model.query, prompt: "Search synthetic names or symbols")
            .navigationTitle("Synthetic market")
            .navigationDestination(for: String.self) { id in
                if let asset = model.snapshot.assets.first(where: { $0.id == id }) {
                    AssetDetail(asset: asset, isFavorite: model.favorites.contains(id)) {
                        model.toggleFavorite(id)
                    }
                } else {
                    Text("This asset is absent from the current snapshot. Go back and refresh.")
                }
            }
            .onAppear {
                if model.snapshot.assets.isEmpty { model.refresh() }
            }
            .onDisappear { model.cancel() }
        }
    }
}

@available(iOS 17.0, *)
struct AssetDetail: View {
    let asset: Asset
    let isFavorite: Bool
    let toggle: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(asset.name).font(.title)
                Text("\(asset.symbol): \(priceText(asset.priceUSD))")
                Text("Exact price: \(exactSampleText(asset.priceUSD))")
                Button(isFavorite ? "Remove favorite" : "Save favorite", action: toggle)
                    .accessibilityValue(isFavorite ? "Favorite" : "Not favorite")
                if asset.points.isEmpty {
                    Text("No synthetic history available.")
                } else {
                    Chart(asset.points, id: \.second) { point in
                        LineMark(x: .value("Synthetic second", point.second),
                                 y: .value("USD display value", NSDecimalNumber(decimal: point.amount).doubleValue))
                    }
                    .frame(height: 220)
                    .accessibilityLabel("Synthetic sample chart; exact sample values follow.")
                    ForEach(asset.points, id: \.second) { point in
                        Text("Second \(point.second): \(exactSampleText(point.amount))")
                    }
                }
                Text("Decimal amounts remain authoritative. The chart converts a copy to Double for drawing.")
            }
            .padding()
        }
        .navigationTitle(asset.symbol)
    }
}

