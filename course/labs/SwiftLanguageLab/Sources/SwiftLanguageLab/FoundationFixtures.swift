import Foundation

public enum FoundationFixtureError: Error, Equatable, Sendable {
    case invalidDate
    case invalidNumber
}

public enum FoundationFixtures {
    /// Noon to noon across a named historical DST transition, not a civil-date data model.
    public static func springCivilDaySeconds() throws -> TimeInterval {
        guard let zone = TimeZone(identifier: "America/New_York") else {
            throw FoundationFixtureError.invalidDate
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let start = calendar.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 12)),
              let end = calendar.date(byAdding: .day, value: 1, to: start),
              calendar.component(.hour, from: end) == 12 else {
            throw FoundationFixtureError.invalidDate
        }
        return end.timeIntervalSince(start)
    }

    /// This parser handles the named well-formed fixtures, not a strict whole-input grammar.
    public static func decimal(_ text: String, locale: String) throws -> Decimal {
        let formatter = numberFormatter(locale: locale)
        guard let number = formatter.number(from: text) else {
            throw FoundationFixtureError.invalidNumber
        }
        return number.decimalValue
    }

    public static func formatted(_ value: Decimal, locale: String) throws -> String {
        guard let text = numberFormatter(locale: locale).string(from: NSDecimalNumber(decimal: value)) else {
            throw FoundationFixtureError.invalidNumber
        }
        return text
    }

    private static func numberFormatter(locale: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        formatter.generatesDecimalNumbers = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    /// NSRange conversion checks UTF-16 validity; this adds a grapheme-boundary policy.
    public static func isCharacterAligned(_ range: NSRange, in text: String) -> Bool {
        guard let swiftRange = Range(range, in: text) else { return false }
        let boundaries = Set(text.indices).union([text.endIndex])
        return boundaries.contains(swiftRange.lowerBound) && boundaries.contains(swiftRange.upperBound)
    }
}

/// Creates only a new unique synthetic directory. cleanup removes only that directory.
public struct TemporaryWorkspace: Sendable {
    public let directory: URL

    public init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-language-lab-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    public func cleanup() throws { try FileManager.default.removeItem(at: directory) }
}

public struct PracticeDocument: Codable, Equatable, Sendable {
    public let version: Int
    public let topics: [String]
    public init(version: Int = 1, topics: [String]) {
        self.version = version
        self.topics = topics
    }
}

public enum FileLoad: Equatable, Sendable { case missing, value(PracticeDocument) }

public enum FileStoreError: Error, Equatable, Sendable {
    case readFailed(String)
    case corrupt(String)
    case unsupportedVersion(Int)
    case writeFailed(String)
}

/// One fixed filename in a supplied synthetic workspace; no user-controlled path.
/// Atomic replacement does not serialize multiple read/modify/write owners.
public struct FixtureFileStore: Sendable {
    public typealias Writer = @Sendable (Data, URL) throws -> Void
    public let file: URL
    private let writer: Writer

    public init(workspace: TemporaryWorkspace,
                writer: @escaping Writer = { try $0.write(to: $1, options: .atomic) }) {
        file = workspace.directory.appendingPathComponent("snapshot.json")
        self.writer = writer
    }

    public func load() throws -> FileLoad {
        let data: Data
        do { data = try Data(contentsOf: file) }
        catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain &&
                (nsError.code == CocoaError.fileReadNoSuchFile.rawValue ||
                 nsError.code == CocoaError.fileNoSuchFile.rawValue) { return .missing }
            throw FileStoreError.readFailed(String(describing: error))
        }
        let document: PracticeDocument
        do { document = try JSONDecoder().decode(PracticeDocument.self, from: data) }
        catch { throw FileStoreError.corrupt(String(describing: error)) }
        guard document.version == 1 else { throw FileStoreError.unsupportedVersion(document.version) }
        return .value(document)
    }

    public func save(_ document: PracticeDocument) throws {
        guard document.version == 1 else { throw FileStoreError.unsupportedVersion(document.version) }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try writer(encoder.encode(document), file)
        } catch { throw FileStoreError.writeFailed(String(describing: error)) }
    }
}
