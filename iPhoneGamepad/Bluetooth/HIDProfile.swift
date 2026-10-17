import CoreBluetooth
import Foundation

/// The emulator-tested Xbox BLE wire profile. No keyboard or pointer collections.
enum HIDProfile {
    static let inputReportID: UInt8 = 1
    static let outputReportID: UInt8 = 3
    // Full canonical UUIDs preserve the tested iOS service-publication behavior.
    nonisolated(unsafe) static let batteryService = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let deviceInformationService = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let hidService = CBUUID(string: "00001812-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let reportReference = CBUUID(string: "00002908-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let batteryLevel = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let hidInformation = CBUUID(string: "00002A4A-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let reportMap = CBUUID(string: "00002A4B-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let hidControlPoint = CBUUID(string: "00002A4C-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let report = CBUUID(string: "00002A4D-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let manufacturerName = CBUUID(string: "00002A29-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let modelNumber = CBUUID(string: "00002A24-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let pnpID = CBUUID(string: "00002A50-0000-1000-8000-00805F9B34FB")
    static let hidInformationValue = Data([0x11, 0x01, 0x00, 0x03])
    static let manufacturerNameValue = Data("iPhone Gamepad".utf8)
    static let modelNumberValue = Data("iPhoneGamepad-1.0".utf8)
    // Compatibility identity selects macOS's supported Xbox BLE driver.
    static let pnpIDValue = Data([0x02, 0x5E, 0x04, 0x13, 0x0B, 0x00, 0x05])
    static let reportMapData = XboxBLEProfile.descriptor
}

enum ReportType: UInt8 {
    case input = 1
    case output = 2
}
