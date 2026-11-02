import Foundation

struct Identity: Equatable, Codable {
    let bundleID: String
    let build: String
    let environment: String
}

enum DeliveryError: Error { case wrongIdentity, invalidPages, unresolvedReview }

func checkIdentity(_ actual: Identity, expected: Identity) throws {
    guard actual == expected else { throw DeliveryError.wrongIdentity }
}

func residentBytes(pages: UInt64, pageSize: UInt64) throws -> UInt64 {
    guard pageSize > 0 else { throw DeliveryError.invalidPages }
    let product = pages.multipliedReportingOverflow(by: pageSize)
    guard !product.overflow else { throw DeliveryError.invalidPages }
    return product.partialValue
}

struct Review: Sendable {
    let author: String
    let reviewer: String
    let reviewedRevision: Int
    let testedRevision: Int
    let blockers: Int
}

func acceptReview(_ review: Review, currentRevision: Int) throws {
    guard review.author != review.reviewer, !review.reviewer.isEmpty,
          review.reviewedRevision == currentRevision,
          review.testedRevision == currentRevision,
          review.blockers == 0 else { throw DeliveryError.unresolvedReview }
}

enum Adoption { case pending, adopted, exception }
struct Consumer {
    let id: String
    let state: Adoption
}

func canRetire(_ consumers: [Consumer], compatibilityChecked: Bool) -> Bool {
    guard !consumers.isEmpty, compatibilityChecked,
          Set(consumers.map(\.id)).count == consumers.count else { return false }
    return consumers.allSatisfy { if case .adopted = $0.state { return true }; return false }
}

// Actual execution checks pure contracts, with intentionally synthetic inputs.
func expectFailure(_ body: () throws -> Void) {
    do { try body(); fatalError("Expected rejection") }
    catch { /* Expected typed failure; no OS termination is caught here. */ }
}

let expected = Identity(bundleID: "example.delivery.scratch", build: "42", environment: "sandbox")
try checkIdentity(expected, expected: expected)
expectFailure { try checkIdentity(Identity(bundleID: expected.bundleID, build: "41", environment: "sandbox"), expected: expected) }
let bytes = try residentBytes(pages: 8, pageSize: 16384)
precondition(bytes == 131072)
expectFailure { _ = try residentBytes(pages: .max, pageSize: 2) }
expectFailure { _ = try residentBytes(pages: 1, pageSize: 0) }
try acceptReview(Review(author: "writer", reviewer: "peer", reviewedRevision: 2, testedRevision: 2, blockers: 0), currentRevision: 2)
expectFailure { try acceptReview(Review(author: "writer", reviewer: "writer", reviewedRevision: 2, testedRevision: 2, blockers: 0), currentRevision: 2) }
expectFailure { try acceptReview(Review(author: "writer", reviewer: "peer", reviewedRevision: 1, testedRevision: 2, blockers: 0), currentRevision: 2) }
expectFailure { try acceptReview(Review(author: "writer", reviewer: "peer", reviewedRevision: 2, testedRevision: 1, blockers: 0), currentRevision: 2) }
expectFailure { try acceptReview(Review(author: "writer", reviewer: "peer", reviewedRevision: 2, testedRevision: 2, blockers: 1), currentRevision: 2) }
precondition(!canRetire([], compatibilityChecked: true))
precondition(!canRetire([Consumer(id: "a", state: .exception)], compatibilityChecked: true))
precondition(!canRetire([Consumer(id: "a", state: .adopted), Consumer(id: "a", state: .adopted)], compatibilityChecked: true))
precondition(!canRetire([Consumer(id: "a", state: .adopted)], compatibilityChecked: false))
precondition(canRetire([Consumer(id: "a", state: .adopted)], compatibilityChecked: true))
print("DeliveryExamples: synthetic identity, overflow, independent revision, and retirement checks passed")
