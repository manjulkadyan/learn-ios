struct Token: ~Copyable {
    let value: Int
    borrowing func read() -> Int { value }
    consuming func extract() -> Int { value }
}
func use() -> Int {
    let token = Token(value: 4)
    let value = token.extract()
    #if INVALID
    return value + token.read()
    #else
    return value
    #endif
}
