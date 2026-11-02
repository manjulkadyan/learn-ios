import Foundation
import SwiftLanguageLab

@main
struct SwiftWorkbench {
    static func main() async throws {
        let mode = CommandLine.arguments.dropFirst().first ?? "all"
        guard ["all", "language", "gates", "foundation"].contains(mode) else {
            throw WorkbenchError.unknownMode(mode)
        }
        if mode == "all" || mode == "language" {
            let readings = [Reading(topic: "Swift", minutes: 20), Reading(topic: "Swift", minutes: 10),
                            Reading(topic: "Files", minutes: 0)]
            print("labels:", LanguageExamples.labels(for: readings))
            var original = ReadingPlan(topics: ["Swift"])
            var copy = original
            copy.append("Actors")
            original.append("Files")
            print("value plans:", original.topics, copy.topics)
            var stack = Stack<String>()
            stack.push("synthetic")
            print("generic pop:", stack.pop() ?? "empty")
        }
        if mode == "all" || mode == "gates" {
            let loader = LatestLoader(account: "A", cancelSuperseded: false)
            let a = CompletionGate<[String]>(cancellationPolicy: .ignore)
            let b = CompletionGate<[String]>(cancellationPolicy: .ignore)
            let first = try await loader.start(using: a)
            await a.waitUntilStarted()
            let second = try await loader.start(using: b)
            await b.waitUntilStarted()
            try await b.succeed(["new B"])
            await second.wait()
            try await a.fail(GateFailure.synthetic("old A"))
            await first.wait()
            print("after old error:", await loader.snapshot().phase)
        }
        if mode == "all" || mode == "foundation" {
            print("civil day seconds:", try FoundationFixtures.springCivilDaySeconds())
            print("German decimal:", try FoundationFixtures.decimal("1.234,50", locale: "de_DE"))
            let workspace = try TemporaryWorkspace()
            // Runtime fixture cleanup, including thrown load/save paths.
            defer { try? workspace.cleanup() }
            let store = FixtureFileStore(workspace: workspace)
            print("before save:", try store.load())
            try store.save(PracticeDocument(topics: ["synthetic Swift"]))
            print("after save:", try store.load())
        }
    }
}

enum WorkbenchError: Error { case unknownMode(String) }
