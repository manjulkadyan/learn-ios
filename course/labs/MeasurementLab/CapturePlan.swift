import os

// Teaching-only instrumentation. Not wired into SwiftUIWorkbench automatically.
// Add this file to your own scratch target before calling it from a practice action.
// Construct the fixture outside this function when measuring mapping alone.
@available(iOS 15.0, macOS 12.0, *)
func captureStableMapping(_ input: [String]) -> [String] {
    let poster = OSSignposter(subsystem: "example.course.measurement", category: "Mapping")
    let interval = poster.beginInterval("MapRows", id: poster.makeSignpostID())
    defer { poster.endInterval("MapRows", interval) }
    var result: [String] = []
    for value in input where !result.contains(value) {
        result.append(value)
    }
    return result
}

// A standalone expected-value check, not a performance observation.
@available(iOS 15.0, macOS 12.0, *)
func checkMappingContract() {
    precondition(captureStableMapping(["b", "a", "b", "c"]) == ["b", "a", "c"])
    precondition(captureStableMapping([]).isEmpty)
}
