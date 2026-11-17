import SwiftUI
import MapKit

// An alias selects the property-wrapper type instead of the newer same-name macro.
typealias LabState<Value> = SwiftUI.State<Value>

@available(iOS 17.0, *)
struct MapScreen: View {
    @StateObject private var model = MapModel()
    @StateObject private var location = LocationService()
    @LabState private var showMap = false
    @LabState private var query = ""
    @LabState private var useRealOrigin = false
    @LabState private var mode = TravelMode.walking
    @LabState private var camera: MapCameraPosition = .region(Self.initialRegion)
    @LabState private var region = Self.initialRegion

    static var initialRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: demoPlaces[0].coordinate.clCoordinate,
                           span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))
    }

    private var origin: Coordinate {
        useRealOrigin ? (location.coordinate ?? demoPlaces[0].coordinate) : demoPlaces[0].coordinate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Fictional places are local. Apple tiles, search and directions may use network data.")
                    if showMap {
                        Map(position: $camera, selection: $model.selection) {
                            ForEach(model.places) { place in
                                Marker(place.name, coordinate: place.coordinate.clCoordinate)
                                    .tag(place.id)
                            }
                            if let route = model.route {
                                MapPolyline(route.polyline).stroke(.blue, lineWidth: 5)
                            }
                        }
                        .frame(height: 300)
                        .onMapCameraChange(frequency: .onEnd) { region = $0.region }
                        .accessibilityLabel("Map of displayed places. Equivalent destination buttons follow.")
                        Button("Hide Apple map") { showMap = false }
                    } else {
                        Button("Show Apple map (may load network data)") { showMap = true }
                    }

                    ForEach(model.places) { place in
                        Button {
                            model.selection = place.id
                            camera = .region(MKCoordinateRegion(center: place.coordinate.clCoordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                        } label: {
                            HStack {
                                Text(place.name)
                                if model.selection == place.id { Image(systemName: "checkmark") }
                            }
                        }
                        .accessibilityLabel("Select \(place.name)")
                        .accessibilityValue(model.selection == place.id ? "Selected" : "Not selected")
                    }
                    TextField("Apple search query", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Button(model.isSearching ? "Replace Apple search" : "Search Apple map data") {
                        model.search(query: query, region: region)
                    }
                    Button("Cancel search") { model.cancelSearch() }
                    Text(model.searchMessage)
                    Button("Restore fictional saved places") { model.restoreFixtures() }

                    Button("Request my location once") { location.requestFromButton() }
                    Text(location.message)
                    Toggle("Use received location as route origin", isOn: $useRealOrigin)
                        .disabled(location.coordinate == nil)
                    Text(useRealOrigin ? "Route origin: received location." : "Route origin: fictional Lantern coordinate.")
                    Picker("Travel mode", selection: $mode) {
                        Text("Walking").tag(TravelMode.walking)
                        Text("Driving").tag(TravelMode.automobile)
                    }
                    .pickerStyle(.segmented)
                    Button(model.isRouting ? "Replace directions request" : "Request Apple directions") {
                        model.directions(origin: origin, mode: mode)
                    }
                    .disabled(model.selection == nil)
                    Text(model.routeMessage)
                    Button("Cancel / clear route") { model.invalidateRoute() }
                    Text("Estimates are informational. This lab provides no turn-by-turn navigation.")
                }
                .padding()
            }
            .navigationTitle("Fictional place explorer")
            .onChange(of: model.selection) { _, _ in model.invalidateRoute() }
            .onChange(of: mode) { _, _ in model.invalidateRoute() }
            .onChange(of: useRealOrigin) { _, _ in model.invalidateRoute() }
            .onChange(of: location.coordinate) { _, _ in model.invalidateRoute() }
            .onChange(of: query) { _, _ in model.cancelSearch(reason: .inputChanged) }
            .onDisappear { model.stop(); location.stop() }
        }
    }
}

