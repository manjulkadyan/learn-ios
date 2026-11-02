import Foundation
import CoreGraphics
import ImageIO
import os

// Shared by the scratch app and host checks; no network or company dependency.
enum LabError: Error { case cancelled, image, output, fixture }
final class ProfileOperation: Operation, @unchecked Sendable {
    // Immutable captures; the flag is the only mutable subclass state, protected by lock.
    private let lock = NSLock()
    private var requested = false
    var cancellationRequested: Bool { lock.lock(); defer { lock.unlock() }; return requested }
    func requestCancellation() { lock.lock(); requested = true; lock.unlock() }
    let action: (ProfileOperation) -> Void
    init(action: @escaping (ProfileOperation) -> Void) { self.action = action; super.init() }
    override func main() { action(self) }
}
enum Pressure: String { case nominal, fair, serious, critical }
enum Admission {
    static func limit(requested: Int, pressure: Pressure, lowPower: Bool, speculative: Bool) -> Int {
        if speculative && (lowPower || pressure == .serious || pressure == .critical) { return 0 }
        if pressure == .serious || pressure == .critical || lowPower { return 1 }
        return pressure == .fair ? min(2, requested) : max(1, min(4, requested))
    }
}
enum Workload {
    static let poster = OSSignposter(subsystem: "org.example.ProfilingLab", category: "Workload")
    static let fixtureID = "rows-6000-unique1500-square2048-v1"
    static func inputs() -> [String] { (0..<6000).map { "Row \($0 % 1500) café" } }
    static func expected() -> [String] { (0..<1500).map { "Row \($0) café" } }
    static func unique(_ input: [String], indexed: Bool, cancelled: () -> Bool) throws -> [String] {
        let state = poster.beginInterval("Projection", id: poster.makeSignpostID())
        defer { poster.endInterval("Projection", state) }
        var seen = Set<String>(), output: [String] = []
        for (index, value) in input.enumerated() {
            if index % 64 == 0 && cancelled() { throw LabError.cancelled }
            if indexed ? seen.insert(value).inserted : !output.contains(value) { output.append(value) }
        }
        if cancelled() { throw LabError.cancelled }
        return output
    }
    static func prepareImage(at url: URL) throws {
        // Explicit Prepare action only: fixture creation is outside Work intervals.
        guard let context = CGContext(data: nil, width: 2048, height: 2048,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw LabError.image }
        context.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2048, height: 2048))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { throw LabError.image }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw LabError.image }
    }
    static func decode(at url: URL, thumbnail: Bool) throws -> CGImage {
        let state = poster.beginInterval("Decode", id: poster.makeSignpostID())
        defer { poster.endInterval("Decode", state) }
        guard let source = CGImageSourceCreateWithURL(url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary) else { throw LabError.image }
        let result: CGImage?
        if thumbnail {
            result = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 240,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        } else {
            result = CGImageSourceCreateImageAtIndex(source, 0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
        guard let result else { throw LabError.image }
        return result
    }
    static func roundTrip(_ rows: [String], at url: URL, cancelled: () -> Bool) throws {
        let state = poster.beginInterval("Disk", id: poster.makeSignpostID())
        defer { poster.endInterval("Disk", state) }
        if cancelled() { throw LabError.cancelled }
        let data = try JSONEncoder().encode(rows)
        try data.write(to: url, options: .atomic)
        // Atomic replacement is not a power-loss durability claim.
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = try JSONDecoder().decode([String].self, from: Data(contentsOf: url))
        guard loaded == rows else { throw LabError.output }
        if cancelled() { throw LabError.cancelled }
    }
}
final class RetentionProbe {
    let payload = Data(repeating: 0x41, count: 2 * 1024 * 1024)
    var callback: (() -> Int)?
    func hold() { callback = { self.payload.count } }
    func stop() { callback = nil }
}
struct RawRecord: Codable {
    let id: String, ordinal: Int, variant: String, fixture: String, boundary: String
    let source: String, configuration: String, outcome: String
    let elapsedMS: Double?
    let correct: Bool?
    let pressureStart: String, pressureEnd: String
    let device: String, osBuild: String, revision: String, cachePolicy: String
    let workers: Int, lowPower: Bool
}
struct RawEnvelope: Codable { let schema: Int; let records: [RawRecord] }
