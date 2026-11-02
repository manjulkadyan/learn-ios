func exchange(_ first: inout Int, _ second: inout Int) {
    let saved = first
    first = second
    second = saved
}
func invalid() {
    var value = 1
    exchange(&value, &value) // Compile only; do not create a runtime trap demonstration.
}
