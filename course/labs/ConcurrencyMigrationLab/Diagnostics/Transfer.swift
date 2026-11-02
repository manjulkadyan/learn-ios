final class Payload { var number = 0 }
actor Sink {
    private var payload: Payload?
    func install(_ payload: sending Payload) { self.payload = payload }
}
func transfer(to sink: Sink) async {
    let payload = Payload()
    await sink.install(payload)
    #if INVALID
    print(payload.number) // Compile only: never run the invalid transfer.
    #endif
}
