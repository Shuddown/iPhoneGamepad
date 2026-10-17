/// Coalesces absolute state separately for each characteristic while BLE is backpressured.
struct GamepadReportBuffer<Key: Hashable, Value> {
    private var order: [Key] = []
    private var values: [Key: Value] = [:]

    mutating func enqueue(_ value: Value, for key: Key) {
        if values[key] == nil { order.append(key) }
        values[key] = value
    }

    mutating func popFirst() -> (Key, Value)? {
        guard !order.isEmpty else { return nil }
        let key = order.removeFirst()
        guard let value = values.removeValue(forKey: key) else { return nil }
        return (key, value)
    }

    mutating func removeAll() {
        order.removeAll()
        values.removeAll()
    }
}
