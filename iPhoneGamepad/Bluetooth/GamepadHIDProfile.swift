import CoreBluetooth
import Foundation

/// GATT services and Xbox-compatible HID reports published by the gamepad.
enum GamepadHIDProfile {
    static let inputReportID: UInt8 = 1
    static let outputReportID: UInt8 = 3
    // Full service UUIDs allow publication through the tested CoreBluetooth workaround.
    // Characteristics and descriptors must use short UUIDs so hosts read the identity
    // and reports correctly; full forms caused stale/zero IDs on Mac and iPad.
    nonisolated(unsafe) static let batteryService = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let deviceInformationService = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let hidService = CBUUID(string: "00001812-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let reportReference = CBUUID(string: "2908")
    nonisolated(unsafe) static let batteryLevel = CBUUID(string: "2A19")
    nonisolated(unsafe) static let hidInformation = CBUUID(string: "2A4A")
    nonisolated(unsafe) static let reportMap = CBUUID(string: "2A4B")
    nonisolated(unsafe) static let hidControlPoint = CBUUID(string: "2A4C")
    nonisolated(unsafe) static let report = CBUUID(string: "2A4D")
    nonisolated(unsafe) static let manufacturerName = CBUUID(string: "2A29")
    nonisolated(unsafe) static let modelNumber = CBUUID(string: "2A24")
    nonisolated(unsafe) static let pnpID = CBUUID(string: "2A50")
    static let hidInformationValue = Data([0x11, 0x01, 0x00, 0x03])
    static let manufacturerNameValue = Data("iPhone Gamepad".utf8)
    static let modelNumberValue = Data("iPhoneGamepad-1.0".utf8)
    // Compatibility identity selects the supported Xbox BLE driver on tested hosts.
    static let pnpIDValue = Data([0x02, 0x5E, 0x04, 0x13, 0x0B, 0x00, 0x05])
    static let reportMapData = XboxBLEProfile.descriptor

    // Valid 16-byte input report with no gamepad collection. A host must not
    // register another host's service as a second controller.
    static let vendorReportMapData = Data([
        0x06, 0x00, 0xFF, 0x09, 0x01, 0xA1, 0x01, 0x85, 0x01,
        0x15, 0x00, 0x26, 0xFF, 0x00, 0x75, 0x08, 0x95, 0x10,
        0x09, 0x01, 0x81, 0x02, 0xC0,
    ])

    static func reportMap(for host: UUID, owner: UUID) -> Data {
        host == owner ? reportMapData : vendorReportMapData
    }

}

enum GamepadReportType: UInt8 {
    case input = 1
    case output = 2
}
