final class Worker {
    var count = 0
    nonisolated func step() async { count += 1 }
}
actor Owner {
    let worker = Worker()
    func run() async { await worker.step() }
}
