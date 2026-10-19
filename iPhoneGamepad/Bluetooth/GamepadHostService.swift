import CoreBluetooth
import Foundation

/// One independently removable controller. Other hosts see a vendor-defined HID collection.
@MainActor
final class GamepadHostService {
    let hostID: UUID
    let service: CBMutableService
    let reportMap: CBMutableCharacteristic
    let input: CBMutableCharacteristic
    let output: CBMutableCharacteristic
    var isPublished = false

    init(hostID: UUID) {
        self.hostID = hostID
        service = CBMutableService(type: GamepadHIDProfile.hidService, primary: true)
        let information = CBMutableCharacteristic(
            type: GamepadHIDProfile.hidInformation, properties: .read,
            value: GamepadHIDProfile.hidInformationValue, permissions: .readEncryptionRequired)
        reportMap = CBMutableCharacteristic(
            type: GamepadHIDProfile.reportMap, properties: .read,
            value: nil, permissions: .readEncryptionRequired)
        let controlPoint = CBMutableCharacteristic(
            type: GamepadHIDProfile.hidControlPoint, properties: .writeWithoutResponse,
            value: nil, permissions: .writeEncryptionRequired)
        input = CBMutableCharacteristic(
            type: GamepadHIDProfile.report, properties: [.read, .notifyEncryptionRequired],
            value: nil, permissions: .readEncryptionRequired)
        input.descriptors = [
            CBMutableDescriptor(
                type: GamepadHIDProfile.reportReference,
                value: Data([GamepadHIDProfile.inputReportID, 1]) as NSData)
        ]
        output = CBMutableCharacteristic(
            type: GamepadHIDProfile.report, properties: [.read, .write, .writeWithoutResponse],
            value: nil, permissions: [.readEncryptionRequired, .writeEncryptionRequired])
        output.descriptors = [
            CBMutableDescriptor(
                type: GamepadHIDProfile.reportReference,
                value: Data([GamepadHIDProfile.outputReportID, 2]) as NSData)
        ]
        service.characteristics = [information, reportMap, controlPoint, input, output]
    }

    func contains(_ characteristic: CBCharacteristic) -> Bool {
        service.characteristics?.contains(where: { $0 === characteristic }) == true
    }
}
