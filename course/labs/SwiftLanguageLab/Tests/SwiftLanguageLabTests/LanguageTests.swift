import Testing
import SwiftLanguageLab

@Suite("Public language contracts")
struct LanguageTests {
    @Test func collectionsPreserveTheDeclaredOrder() {
        let readings = [Reading(topic: "Swift", minutes: 20), Reading(topic: "Actors", minutes: 15),
                        Reading(topic: "Swift", minutes: 10), Reading(topic: "Skipped", minutes: 0)]
        #expect(LanguageExamples.labels(for: readings) == ["Swift: 20", "Actors: 15", "Swift: 10"])
        let totals = LanguageExamples.totalsByTopic(readings)
        #expect(totals.map(\.topic) == ["Actors", "Swift"])
        #expect(totals.map(\.minutes) == [15, 30])
        #expect(LanguageExamples.distinctTopics(readings) == ["Actors", "Skipped", "Swift"])
        #expect(LanguageExamples.labels(for: []).isEmpty)
    }

    @Test func transformationsHaveDifferentFailureContracts() {
        #expect(LanguageExamples.parsePresentIntegers(["10", "bad", "-2"]) == [10, -2])
        #expect(LanguageExamples.firstEvenSquare(in: [3, 5, 4, 2]) == 16)
        #expect(LanguageExamples.firstEvenSquare(in: [3, 5]) == nil)
    }

    @Test func copiedValuesCanMutateIndependently() {
        var original = ReadingPlan(topics: ["Swift"])
        var copy = original
        copy.append("Actors")
        original.append("Files")
        #expect(original.topics == ["Swift", "Files"])
        #expect(copy.topics == ["Swift", "Actors"])
        var source = 10
        var destination = 4
        LanguageExamples.transfer(3, from: &source, to: &destination)
        #expect(source == 7 && destination == 7)
    }

    @Test func aStructDoesNotDeepCopyReferences() {
        let original = CounterEnvelope(counter: ReferenceCounter(1))
        let copy = original
        copy.counter.value = 9
        #expect(original.counter === copy.counter)
        #expect(original.counter.value == 9)
    }

    @Test func genericAndExistentialContracts() {
        var stack = Stack<String>()
        #expect(stack.pop() == nil)
        stack.push("first")
        stack.push("second")
        #expect(stack.count == 2)
        #expect(stack.pop() == "second")
        #expect(stack.pop() == "first")
        #expect(renderedLabel(TopicLabel(text: "generic")) == "generic")
        #expect(makeLabel("opaque").text == "opaque")
        #expect(renderLabels([TopicLabel(text: "topic"), OtherLabel(text: "other")]) == ["topic", "other"])
    }
}

private struct OtherLabel: LessonLabel { let text: String }
