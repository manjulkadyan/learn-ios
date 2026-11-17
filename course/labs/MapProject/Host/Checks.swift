import Foundation

@main
struct MapChecks {
    static func main() throws {
        func rejects(_ work: () throws -> Void) -> Bool {
            do { try work(); return false } catch { return true }
        }
        precondition(rejects { _ = try Coordinate(latitude: .nan, longitude: 0) })
        precondition(rejects { _ = try Coordinate(latitude: 91, longitude: 0) })
        precondition(rejects {
            _ = try JSONDecoder().decode(Coordinate.self,
                from: Data(#"{"latitude":37,"longitude":181}"#.utf8))
        })
        _ = try Coordinate(latitude: -90, longitude: 180)
        print("PASS coordinate validation, decoded invalid input, inclusive bounds")

        precondition(rejects { _ = try checkedPlaces([demoPlaces[0], demoPlaces[0]]) })
        _ = try checkedPlaces(demoPlaces)
        let reordered = try checkedPlaces(Array(demoPlaces.reversed()))
        precondition(reordered[1].id == demoPlaces[0].id)
        print("PASS duplicate rejection and stable identity after reorder")

        var search = RequestGate()
        var route = RequestGate()
        let oldSuccess = search.begin()
        let current = search.begin()
        let routeToken = route.begin()
        precondition(!search.accepts(oldSuccess)) // delayed success
        precondition(search.accepts(current))
        search.invalidate() // blank query / screen exit
        precondition(!search.accepts(current)) // delayed error
        precondition(route.accepts(routeToken)) // independent request lane
        route.invalidate() // selection changed
        precondition(!route.accepts(routeToken))
        print("PASS old success/error, cancellation invalidation, independent lanes")

        var snapshot = PlaceSearchSnapshot()
        let acceptedToken = snapshot.begin()
        let acceptedPlaces = Array(demoPlaces.reversed())
        let accepted = try snapshot.accept(acceptedPlaces, token: acceptedToken)
        precondition(accepted)
        let cancelledToken = snapshot.begin()
        precondition(snapshot.isSearching && snapshot.message == "Searching Apple map data…")
        snapshot.cancel()
        precondition(!snapshot.isSearching)
        precondition(snapshot.message == "Search cancelled; previous places remain.")
        precondition(snapshot.places == acceptedPlaces)
        let oldAccepted = try snapshot.accept([], token: cancelledToken)
        precondition(!oldAccepted && !snapshot.fail(token: cancelledToken))
        precondition(snapshot.message == "Search cancelled; previous places remain.")
        let editedToken = snapshot.begin()
        snapshot.cancel(reason: .inputChanged)
        precondition(!snapshot.isSearching && snapshot.message.hasPrefix("Query changed;"))
        precondition(snapshot.places == acceptedPlaces)
        precondition(!snapshot.fail(token: editedToken))
        snapshot.showEmptyQueryPrompt()
        precondition(snapshot.message == "Enter a query; saved results remain available.")
        precondition(snapshot.places == acceptedPlaces)
        let invalidToken = snapshot.begin()
        precondition(rejects {
            _ = try snapshot.accept([demoPlaces[0], demoPlaces[0]], token: invalidToken)
        })
        precondition(snapshot.fail(token: invalidToken))
        precondition(!snapshot.isSearching && snapshot.places == acceptedPlaces)
        print("PASS search cancel/edit/blank status, retained places, late-result and invalid-catalog recovery")

        let walk = RouteKey(origin: demoPlaces[0].coordinate,
                            destination: demoPlaces[1].coordinate, mode: .walking)
        let drive = RouteKey(origin: walk.origin, destination: walk.destination, mode: .automobile)
        let reversed = RouteKey(origin: walk.destination, destination: walk.origin, mode: .walking)
        var cache = TimedCache<RouteKey, RouteSummary>(lifetime: 60)
        let synthetic = RouteSummary(metres: 420, seconds: 300)
        cache.insert(synthetic, for: walk, now: 100)
        precondition(cache.value(for: walk, now: 159) == synthetic)
        precondition(cache.value(for: drive, now: 159) == nil)
        precondition(cache.value(for: reversed, now: 159) == nil)
        precondition(cache.value(for: walk, now: 160) == nil)
        cache.insert(synthetic, for: walk, now: 100)
        precondition(cache.value(for: walk, now: 99) == nil)
        print("PASS cache mode/direction, exact expiry, backward clock rejection")

        cache.insert(synthetic, for: walk, now: 100)
        let acceptedEntry = cache.entry(for: walk, now: 159)!
        let freshText = routeEstimateText(synthetic, freshness: .fresh)
        let cachedText = routeEstimateText(acceptedEntry.value,
            freshness: .cached(age: 159 - acceptedEntry.insertedAt, lifetime: cache.lifetime))
        let estimate = "Apple estimate: about 420 metres; 5 minutes."
        precondition(freshText == estimate + " Fresh response.")
        precondition(cachedText == estimate + " Cached response, 59 seconds old (expiry at 60 seconds).")
        precondition(cache.entry(for: walk, now: 160) == nil)
        precondition(routeEstimateText(synthetic, freshness: .cached(age: 60, lifetime: 60))
            == "Cached route expired or invalid; request directions again.")
        precondition(routeEstimateText(RouteSummary(metres: .nan, seconds: 300), freshness: .fresh)
            == "Route estimate unavailable; request directions again.")
        print("PASS fresh/cache-hit text retains distance/duration/age, exact expiry and invalid-summary recovery")
        print("MapProject: 6 behavior groups passed; no MapKit or location requests")
    }
}

