protocol Caption { func caption() -> String }
@MainActor struct Row: @MainActor Caption {
    let name: String
    func caption() -> String { name }
}
@MainActor func valid(_ row: Row) -> String { row.caption() }
#if INVALID
@concurrent func render<T: Caption & Sendable>(_ value: T) async -> String { value.caption() }
@MainActor func invalid(_ row: Row) async -> String { await render(row) }
#endif
