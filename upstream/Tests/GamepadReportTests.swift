import Foundation

@main
enum GamepadReportTests {
    static func main() {
        precondition(HIDProfile.reportMapData.starts(with: Data([5, 1, 9, 5, 0xA1, 1])),
                     "Game Pad must be the primary collection for GCController discovery")
        precondition(ReportID.gamepad.rawValue == GamepadReport.reportID)
        precondition(ReportID.gamepad.descriptor(.input) == Data([7, 1]))
        // Decode the descriptor's HID short items as a host would, checking the
        // payload's bit layout rather than just comparing a descriptor constant.
        let bytes = Array(GamepadReport.descriptor)
        var index = 0
        var size = 0
        var count = 0
        var reportID = 0
        var inputBits = 0
        var collections = 0
        var inputFields: [(Int, Int, Int)] = []
        var usages: [Int] = []
        while index < bytes.count {
            let prefix = Int(bytes[index]); index += 1
            let lengthCode = prefix & 3
            let length = lengthCode == 3 ? 4 : lengthCode
            precondition(index + length <= bytes.count, "Truncated HID item")
            var value = 0
            for offset in 0..<length { value |= Int(bytes[index + offset]) << (offset * 8) }
            index += length
            switch prefix & 0xFC {
            case 0x74: size = value
            case 0x94: count = value
            case 0x84: reportID = value
            case 0x08: usages.append(value)
            case 0xA0: collections += 1
            case 0xC0: collections -= 1
            case 0x80:
                precondition(reportID == 7)
                inputFields.append((size, count, value))
                inputBits += size * count
            default: break
            }
        }
        precondition(collections == 0)
        precondition(usages.contains(5), "No Game Pad application usage")
        precondition(inputBits == 72, "HID host expects a different payload size")
        precondition(inputFields.count == 5)
        precondition(inputFields[0].0 == 1 && inputFields[0].1 == 16)
        precondition(inputFields[1].0 == 4 && inputFields[1].2 & 0x40 != 0, "Hat must allow a null state")
        precondition(inputFields[2].2 & 1 != 0, "Hat padding must be constant")
        precondition(inputFields[3].0 == 8 && inputFields[3].1 == 4)
        precondition(inputFields[4].0 == 8 && inputFields[4].1 == 2)
        precondition(Array(GamepadReport.zero.data) == [0, 0, 8, 0, 0, 0, 0, 0, 0])

        var report = GamepadReport(leftX: -127, leftY: 127, rightX: -128, rightY: 64, leftTrigger: 128, rightTrigger: 255)
        report.setButton(1, pressed: true)
        report.setButton(16, pressed: true)
        report.hat = 7
        precondition(Array(report.data) == [1, 128, 7, 129, 127, 129, 64, 128, 255])
        report.setButton(1, pressed: false)
        precondition(report.buttons == 0x8000, "Releasing A must preserve another held button")
        report.setButton(0, pressed: true)
        report.setButton(17, pressed: true)
        precondition(report.buttons == 0x8000)
        report.hat = 255
        precondition(report.data[2] == 8)

        precondition(Array(GamepadReport.zero.xboxData) == [0, 128, 0, 128, 0, 128, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0])
        var xbox = GamepadReport(leftX: -127, leftY: 127, leftTrigger: 255, rightTrigger: 128)
        xbox.setButton(3, pressed: true) // X uses Xbox bit 3, not bit 2.
        xbox.setButton(11, pressed: true) // Left stick click uses bit 13.
        xbox.hat = 7
        precondition(Array(xbox.xboxData) == [1, 0, 255, 255, 0, 128, 0, 128, 255, 3, 1, 2, 8, 8, 32, 0])
        let xboxSizes = reportBitCounts(XboxBLEProfile.descriptor)
        precondition(xboxSizes["input:1"] == 128 && xboxSizes["output:3"] == 64,
                     "Xbox BLE input/output characteristics must match the descriptor")
        precondition(GamepadReport.zero.xboxData.count * 8 == xboxSizes["input:1"])

        // Congestion: releasing the gamepad must survive an unrelated report.
        var pending = PendingHIDReports<Int, Data>()
        pending.enqueue(report.data, for: 7)
        pending.enqueue(Data([1]), for: 2)
        pending.enqueue(GamepadReport.zero.data, for: 7)
        let first = pending.popFirst()
        precondition(first?.0 == 7 && first?.1 == GamepadReport.zero.data)
        precondition(pending.popFirst()?.0 == 2)
        precondition(pending.popFirst() == nil)
        pending.enqueue(report.data, for: 7)
        pending.removeAll()
        precondition(pending.popFirst() == nil)
        print("PASS: HID descriptor layout, neutral state, axes, buttons, hat, and congested report delivery")
    }

    private static func reportBitCounts(_ descriptor: Data) -> [String: Int] {
        let bytes = Array(descriptor)
        var offset = 0
        var size = 0
        var count = 0
        var id = 0
        var totals: [String: Int] = [:]
        while offset < bytes.count {
            let prefix = Int(bytes[offset]); offset += 1
            let code = prefix & 3
            let length = code == 3 ? 4 : code
            precondition(offset + length <= bytes.count)
            var value = 0
            for index in 0..<length { value |= Int(bytes[offset + index]) << (8 * index) }
            offset += length
            switch prefix & 0xFC {
            case 0x74: size = value
            case 0x94: count = value
            case 0x84: id = value
            case 0x80: totals["input:\(id)", default: 0] += size * count
            case 0x90: totals["output:\(id)", default: 0] += size * count
            default: break
            }
        }
        return totals
    }
}
