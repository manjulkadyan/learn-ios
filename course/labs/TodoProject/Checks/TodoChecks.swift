import Foundation

enum CheckFailure: Error { case failed(String) }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckFailure.failed(message) }
}
func expectError(_ expected: TodoError, _ body: () throws -> Void) throws {
    do { try body(); throw CheckFailure.failed("Expected \(expected)") }
    catch let error as TodoError { try require(error == expected, "wrong error \(error)") }
}
final class FaultStore: TodoStoring {
    var items: [Todo] = []
    var failLoad = false
    var failSave = false
    var saveCount = 0
    func load() throws -> LoadedTodos {
        if failLoad { throw CheckFailure.failed("injected read failure") }
        return LoadedTodos(items: items, needsMigrationSave: false)
    }
    func save(_ next: [Todo]) throws {
        if failSave { throw CheckFailure.failed("injected write failure") }
        items = next
        saveCount += 1
    }
}

@main @MainActor
struct TodoChecks {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw CheckFailure.failed("Pass a unique scratch directory") }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let c = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let d = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let first = try Todo(id: a, title: "  Pack bag\n")
        try require(first.title == "Pack bag", "trim")
        try expectError(.emptyTitle) { _ = try Todo(title: " \n ") }
        try expectError(.titleTooLong) { _ = try Todo(title: String(repeating: "x", count: 81)) }
        _ = try Todo(title: String(repeating: "👩🏽‍💻", count: 80))
        let second = try Todo(id: b, title: "Pack bag")
        try Todo.validate([first, second])
        try expectError(.duplicateID) { try Todo.validate([first, first]) }

        let store = FaultStore()
        let model = TodoViewModel(store: store)
        try require(model.load(), "initial load")
        try require(model.add(title: "Pack bag", id: a), "add A")
        try require(model.add(title: "Check lamp", id: b), "add B")
        try require(model.add(title: "Fill bottle", id: c), "add C")
        try require(model.add(title: "Lock door", id: d), "add D")
        try require(model.move(from: IndexSet([1, 3]), to: 0), "noncontiguous move")
        try require(model.items.map(\.id) == [b, d, a, c], "preserve original moving order")
        try require(model.move(from: IndexSet([0]), to: 4), "move to end")
        try require(model.items.map(\.id) == [d, a, c, b], "destination adjustment")
        let before = model.items
        try require(!model.move(from: IndexSet([9]), to: 0), "reject invalid index")
        try require(!model.add(title: "Duplicate", id: a), "reject duplicate identity")
        try require(model.items == before, "invalid command unchanged")
        try require(model.rename(id: a, to: "Pack blue bag"), "rename")
        try require(model.toggle(id: a), "toggle by id after moves")
        try require(model.items.first(where: { $0.id == a })?.isComplete == true, "correct row toggled")
        try require(model.remainingCount == 3, "derived count")
        try require(model.delete(ids: [a]), "delete A")
        try require(!model.rename(id: a, to: "Stale editor"), "stale editor rejected")
        try require(model.items.count == 3, "stale editor creates nothing")

        store.failSave = true
        try require(model.rename(id: b, to: "Inspect lamp"), "valid command despite failed save")
        try require(model.isDirty && model.storageError != nil, "failed save visible")
        try require(!model.load(), "cannot overwrite unsaved memory")
        store.failSave = false
        try require(model.save() && !model.isDirty, "retry saves current snapshot")
        try require(store.items.first(where: { $0.id == b })?.title == "Inspect lamp", "latest snapshot durable")
        let blockedStore = FaultStore()
        blockedStore.failLoad = true
        let blocked = TodoViewModel(store: blockedStore)
        try require(!blocked.load(), "load failure")
        try require(!blocked.add(title: "Would erase store", id: a), "commands blocked")
        try require(!blocked.save() && blockedStore.saveCount == 0, "no replacement after read failure")
        blockedStore.failLoad = false
        try require(blocked.load() && blocked.add(title: "Recovered", id: a), "explicit load recovery")

        let disk = FileTodoStore(url: root.appendingPathComponent("data/tasks.json"))
        let missing = try disk.load()
        try require(missing.items.isEmpty, "missing file is first launch")
        try disk.save([first, second])
        let roundTrip = try disk.load()
        try require(roundTrip.items == [first, second], "round trip and duplicate titles")
        let old = """
        {"version":1,"tasks":[{"id":"\(a.uuidString)","name":"  Pack bag  ","done":true}]}
        """
        try Data(old.utf8).write(to: disk.url)
        let migrated = try disk.load()
        try require(migrated.needsMigrationSave && migrated.items[0].id == a && migrated.items[0].isComplete, "migration preserves id/status")
        try require(migrated.items[0].title == "Pack bag", "migration normalization")
        try require(try Data(contentsOf: disk.url) == Data(old.utf8), "load never rewrites original")
        try disk.save(migrated.items)
        let current = try disk.load()
        try require(!current.needsMigrationSave, "explicit version two save")
        let future = Data("{\"version\":99,\"items\":[]}".utf8)
        try future.write(to: disk.url)
        try expectError(.unsupportedVersion(99)) { _ = try disk.load() }
        let corrupt = Data("not JSON".utf8)
        try corrupt.write(to: disk.url)
        let corruptModel = TodoViewModel(store: disk)
        try require(!corruptModel.load() && !corruptModel.save(), "corrupt store protected")
        try require(try Data(contentsOf: disk.url) == corrupt, "original corrupt bytes retained")
        let duplicateBytes = try JSONEncoder().encode(TodoEnvelope(version: 2, items: [first, first]))
        try duplicateBytes.write(to: disk.url)
        try expectError(.duplicateID) { _ = try disk.load() }
        let invalidBytes = Data("{\"version\":2,\"items\":[{\"id\":\"\(a.uuidString)\",\"title\":\"   \",\"isComplete\":false}]}".utf8)
        try invalidBytes.write(to: disk.url)
        try expectError(.emptyTitle) { _ = try disk.load() }
        print("PASS Todo: identity, validation, ordered moves, stale edits, save retry, load protection, disk round trip, migration, future/corrupt/duplicate rejection")
    }
}
