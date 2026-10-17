import Foundation

/// HOGP payload excludes the report ID; the characteristic's Report Reference supplies it.
struct GamepadReport: Sendable, Equatable {
    static let reportID: UInt8 = 1
    var buttons: UInt16 = 0
    /// Clockwise from up (0...7); 8 is the HID null/centered value.
    var hat: UInt8 = 8
    var leftX: Int8 = 0
    var leftY: Int8 = 0
    var rightX: Int8 = 0
    var rightY: Int8 = 0
    var leftTrigger: UInt8 = 0
    var rightTrigger: UInt8 = 0

    static let zero = GamepadReport()

    /// Known Xbox BLE layout lets macOS select its supported controller driver.
    var data: Data {
        var bytes: [UInt8] = []
        func append16(_ value: UInt16) {
            bytes.append(UInt8(truncatingIfNeeded: value))
            bytes.append(UInt8(value >> 8))
        }
        for axis in [leftX, leftY, rightX, rightY] {
            let scaled = Int(max(-127, axis)) * 32767 / 127 + 32768
            append16(UInt16(scaled))
        }
        append16(UInt16(UInt32(leftTrigger) * 1023 / 255))
        append16(UInt16(UInt32(rightTrigger) * 1023 / 255))
        bytes.append(hat < 8 ? hat + 1 : 0)
        // UI's logical button order -> the gaps in Xbox's button usage map.
        let mapping = [0, 1, 3, 4, 6, 7, 8, 9, 10, 11, 13, 14, 12]
        var mapped: UInt16 = 0
        for (source, target) in mapping.enumerated() where buttons & (1 << source) != 0 {
            mapped |= 1 << target
        }
        append16(mapped)
        bytes.append(0) // Share button
        return Data(bytes)
    }

    mutating func setButton(_ number: Int, pressed: Bool) {
        guard (1...16).contains(number) else { return }
        let mask = UInt16(1) << (number - 1)
        if pressed { buttons |= mask } else { buttons &= ~mask }
    }


}

/// Coalesces absolute state separately for each characteristic while BLE is backpressured.
struct PendingHIDReports<Key: Hashable, Value> {
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
