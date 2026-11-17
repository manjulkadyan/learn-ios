import Foundation
import Combine

// The session is ephemeral and intercepts only fixture.invalid. No sockets,
// DNS lookup or remote requests are used by these adapter checks.
final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "fixture.invalid"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let status = path == "/status" ? 503 : 200
        let type = path == "/type" ? "text/html" : "application/json"
        let data = path == "/corrupt" ? Data("broken".utf8) : syntheticMarketJSON
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": type])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct MarketServiceChecks {
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let good = URL(string: "https://fixture.invalid/good")!
        let expected = try AssetDecoder.decode(syntheticMarketJSON)
        var received: [Asset]?
        for try await value in HTTPMarketService(endpoint: good, session: session).assets().values {
            received = value
        }
        precondition(received == expected)
        let asyncRows = try await AsyncHTTPMarketService.assets(endpoint: good, session: session)
        precondition(asyncRows == expected)
        print("PASS actual Combine and async URLSession adapters through offline URLProtocol")

        for path in ["status", "type", "corrupt"] {
            let endpoint = URL(string: "https://fixture.invalid/\(path)")!
            var rejected = false
            do {
                _ = try await AsyncHTTPMarketService.assets(endpoint: endpoint, session: session)
            } catch { rejected = true }
            precondition(rejected)
            rejected = false
            do {
                for try await _ in HTTPMarketService(endpoint: endpoint, session: session).assets().values {}
            } catch { rejected = true }
            precondition(rejected)
        }
        print("PASS adapter status, MIME and malformed JSON failure for both boundaries")
        print("MarketProject: 2 offline adapter groups passed; no remote endpoint contacted")
    }
}
