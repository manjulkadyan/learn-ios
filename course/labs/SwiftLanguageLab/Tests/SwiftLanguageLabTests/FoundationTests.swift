import Foundation
import Testing
import SwiftLanguageLab

@Suite("Foundation fixtures without client data")
struct FoundationTests {
    @Test func civilDaysDoNotAlwaysEqual86400Seconds() throws {
        #expect(try FoundationFixtures.springCivilDaySeconds() == 82_800)
    }

    @Test("Explicit locale parses and formats the same decimal", arguments: ["en_US", "de_DE"])
    func localeIsAnInput(locale: String) throws {
        let expected = try #require(Decimal(string: "1234.50", locale: Locale(identifier: "en_US_POSIX")))
        let text = locale == "de_DE" ? "1.234,50" : "1,234.50"
        #expect(try FoundationFixtures.decimal(text, locale: locale) == expected)
        let formatted = try FoundationFixtures.formatted(expected, locale: locale)
        #expect(try FoundationFixtures.decimal(formatted, locale: locale) == expected)
        #expect(formatted.contains(locale == "de_DE" ? ",50" : ".50"))
    }

    @Test func unicodeEqualityDoesNotImplyIdenticalBytes() {
        let composed = "é"
        let decomposed = "e\u{301}"
        #expect(composed == decomposed)
        #expect(composed.count == 1 && decomposed.count == 1)
        #expect(Array(composed.utf8) != Array(decomposed.utf8))
        #expect(decomposed.utf8.count == 3)
    }

    @Test func foundationRangesNeedTheExactStringAndBoundaryPolicy() throws {
        let text = "A👩🏽‍💻B"
        #expect(text.count == 3)
        let b = try #require(text.range(of: "B"))
        let range = NSRange(b, in: text)
        #expect(range.location == 8 && range.length == 1)
        #expect(Range(range, in: text) == b)
        #expect(FoundationFixtures.isCharacterAligned(range, in: text))
        #expect(!FoundationFixtures.isCharacterAligned(NSRange(location: 100, length: 1), in: text))
        #expect(!FoundationFixtures.isCharacterAligned(NSRange(location: 0, length: 1), in: "e\u{301}"))
    }

    @Test func directoriesAreUniqueAndCleanupIsBounded() throws {
        let first = try TemporaryWorkspace()
        let second = try TemporaryWorkspace()
        defer { try? first.cleanup(); try? second.cleanup() }
        #expect(first.directory != second.directory)
        try first.cleanup()
        #expect(!FileManager.default.fileExists(atPath: first.directory.path))
        #expect(FileManager.default.fileExists(atPath: second.directory.path))
    }

    @Test func missingIsDifferentFromSuccessfulEmptyAndCorrupt() throws {
        let workspace = try TemporaryWorkspace()
        defer { try? workspace.cleanup() }
        let store = FixtureFileStore(workspace: workspace)
        #expect(try store.load() == .missing)
        let empty = PracticeDocument(topics: [])
        try store.save(empty)
        #expect(try store.load() == .value(empty))
        try Data("{broken fixture".utf8).write(to: store.file)
        do {
            _ = try store.load()
            Issue.record("Corrupt bytes must not become missing or empty success")
        } catch FileStoreError.corrupt { /* Expected typed failure. */ }
    }

    @Test func unsupportedVersionsAndMalformedFieldsDoNotDecodeAsCurrent() throws {
        let workspace = try TemporaryWorkspace()
        defer { try? workspace.cleanup() }
        let store = FixtureFileStore(workspace: workspace)
        try Data(#"{"version":2,"topics":[]}"#.utf8).write(to: store.file)
        #expect(throws: FileStoreError.unsupportedVersion(2)) { try store.load() }
        try Data(#"{"version":1,"topics":42}"#.utf8).write(to: store.file)
        do {
            _ = try store.load()
            Issue.record("A numeric topics field must be corrupt")
        } catch FileStoreError.corrupt { /* Expected. */ }
        #expect(throws: FileStoreError.unsupportedVersion(2)) {
            try store.save(PracticeDocument(version: 2, topics: []))
        }
    }

    @Test func injectedWriteFailurePreservesThePreviousSnapshot() throws {
        let workspace = try TemporaryWorkspace()
        defer { try? workspace.cleanup() }
        let store = FixtureFileStore(workspace: workspace)
        let previous = PracticeDocument(topics: ["previous synthetic topic"])
        try store.save(previous)
        let failing = FixtureFileStore(workspace: workspace) { _, _ in
            throw GateFailure.synthetic("fixture write denied")
        }
        do {
            try failing.save(PracticeDocument(topics: ["replacement"]))
            Issue.record("Injected failure must be observable")
        } catch FileStoreError.writeFailed { /* Expected, with original error context. */ }
        #expect(try store.load() == .value(previous))
    }

    @Test func aDirectoryAtTheFilePathProducesARealWriteAndReadFailure() throws {
        let workspace = try TemporaryWorkspace()
        defer { try? workspace.cleanup() }
        let store = FixtureFileStore(workspace: workspace)
        try FileManager.default.createDirectory(at: store.file, withIntermediateDirectories: false)
        do {
            try store.save(PracticeDocument(topics: ["synthetic"]))
            Issue.record("Atomic file replacement cannot overwrite a directory")
        } catch FileStoreError.writeFailed { /* No permissions or disk-full assumptions. */ }
        do {
            _ = try store.load()
            Issue.record("An unreadable directory is not a missing document")
        } catch FileStoreError.readFailed { /* Expected. */ }
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: store.file.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }
}
