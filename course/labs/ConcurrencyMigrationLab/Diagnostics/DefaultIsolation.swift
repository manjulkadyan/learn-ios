func uiValue() -> Int { 1 }
nonisolated func outside() -> Int { uiValue() }
