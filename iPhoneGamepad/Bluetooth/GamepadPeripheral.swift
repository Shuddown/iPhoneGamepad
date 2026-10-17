import Combine
import CoreBluetooth
import Foundation
import os

/// Publishes the iPhone as a Bluetooth gamepad and delivers its input reports.
@MainActor
final class GamepadPeripheral: NSObject, ObservableObject {
    @Published private(set) var state: CBManagerState = .unknown
    @Published private(set) var isAdvertising = false
    @Published private(set) var isHIDServiceAdded = false
    /// central identifier: the set of characteristic UUIDs it is currently subscribed to
    @Published private(set) var subscribedCentrals: [UUID: Set<CBUUID>] = [:]
    /// broadcasts skip inactive hosts
    @Published private(set) var inactiveCentrals: Set<UUID> = []
    @Published private(set) var connectedCentrals: Set<UUID> = []
    @Published private(set) var lastError: String?
    @Published private(set) var batteryLevel: UInt8 = 100
    @Published private(set) var gamepadSubscribers: Set<UUID> = []

    private var centralObjects: [UUID: CBCentral] = [:]
    private var subscriptions: [UUID: Set<ObjectIdentifier>] = [:]

    var advertiseLocalName: String =
        UserDefaults.standard.string(forKey: GamepadSettings.advertisedNameKey) ?? "iPhone Gamepad"

    private let log = Logger(subsystem: "com.shudhesh.iphonegamepad", category: "GamepadPeripheral")
    private var peripheralManager: CBPeripheralManager?
    private var batteryService: CBMutableService?
    private var deviceInformationService: CBMutableService?
    private var gamepadService: CBMutableService?
    private var isHIDServiceAllowed = false
    private var isReadyToSendNotification = true

    private var reportCharacteristics: [UInt8: CBMutableCharacteristic] = [:]
    private var batteryLevelCharacteristic: CBMutableCharacteristic?
    private var serviceChangedService: CBMutableService?
    private var serviceChangedArmed = false
    private static let serviceChangedGrace: UInt64 = 2_000_000_000

    /// last-sent payloads for reads and new subscriptions
    private var cachedReports: [UInt8: Data] = [
        GamepadHIDProfile.inputReportID: GamepadReport.zero.data,
        GamepadHIDProfile.outputReportID: Data(repeating: 0, count: 8),
    ]

    private var pendingReports = GamepadReportBuffer<ObjectIdentifier, (Data, CBMutableCharacteristic)>()

    func start() {
        isHIDServiceAllowed = true
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(
                delegate: self,
                queue: nil,
                options: [CBPeripheralManagerOptionShowPowerAlertKey: true]
            )
        } else if state == .poweredOn {
            if isHIDServiceAdded {
                startAdvertisingNow()
            } else {
                installServices()
            }
        }
    }

    func stop() {
        sendGamepad(.zero)
        isHIDServiceAllowed = false
        peripheralManager?.stopAdvertising()
        isAdvertising = false
    }

    func promptPowerAlert() {
        guard state != .poweredOn else { return }
        resetForRestart()
        start()
    }

    private func resetForRestart() {
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
        isAdvertising = false
        isHIDServiceAdded = false
        isReadyToSendNotification = true
        pendingReports.removeAll()
        batteryService = nil
        deviceInformationService = nil
        gamepadService = nil
        serviceChangedService = nil
        serviceChangedArmed = false
        batteryLevelCharacteristic = nil
        reportCharacteristics.removeAll()
        subscribedCentrals.removeAll()
        inactiveCentrals.removeAll()
        connectedCentrals.removeAll()
        centralObjects.removeAll()
        subscriptions.removeAll()
        gamepadSubscribers.removeAll()
    }

    func sendGamepad(_ report: GamepadReport) {
        broadcast(report.data, reportID: GamepadHIDProfile.inputReportID)
    }

    #if DEBUG
        /// USB-launched diagnostic only; never runs during ordinary app use.
        func runGamepadProbeIfRequested() async {
            guard ProcessInfo.processInfo.arguments.contains("--gamepad-probe") else { return }
            for _ in 0..<60 {
                if !gamepadSubscribers.isEmpty { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
            }
            guard !gamepadSubscribers.isEmpty else {
                print("Gamepad probe: no host subscribed within 30 seconds")
                return
            }
            let samples = [
                GamepadReport.zero, GamepadReport(buttons: 1), .zero,
                GamepadReport(leftX: 127, leftY: -127), .zero,
                GamepadReport(rightX: -127, rightY: 127), .zero,
                GamepadReport(leftTrigger: 255, rightTrigger: 128), .zero,
                GamepadReport(hat: 2), .zero,
            ]
            defer { sendGamepad(.zero) }
            for sample in samples {
                if Task.isCancelled { return }
                let payload = sample.data
                print("Gamepad probe: \(payload.map { String(format: "%02x", $0) }.joined())")
                sendGamepad(sample)
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    #endif

    func toggleActive(_ uuid: UUID) {
        if inactiveCentrals.contains(uuid) {
            inactiveCentrals.remove(uuid)
        } else {
            inactiveCentrals.insert(uuid)
        }
    }

    func updateBatteryLevel(_ level: UInt8) {
        let clamped = min(level, 100)
        batteryLevel = clamped
        let asHIDReport = Data([clamped])
        if let batteryLevelCharacteristic { _ = updateValue(asHIDReport, for: batteryLevelCharacteristic) }
    }

    /// if host connects but never subscribes (stale GATT cache), cycle a temp service to fire Service Changed so it re-discovers
    func scheduleServiceChanged() {
        guard UserDefaults.standard.bool(forKey: GamepadSettings.useServiceChangedKey), !serviceChangedArmed else {
            return
        }
        serviceChangedArmed = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.serviceChangedGrace)
            self?._cycleServiceChangedIfUnsubscribed()
        }
    }

    private func _cycleServiceChangedIfUnsubscribed() {
        guard subscribedCentrals.isEmpty else { return }
        _cycleServiceChanged()
    }

    private func _cycleServiceChanged() {
        guard let peripheralManager else { return }
        if let svc = serviceChangedService {
            peripheralManager.remove(svc)
            peripheralManager.add(svc)
        } else {
            let svc = buildServiceChangedTrigger()
            serviceChangedService = svc
            peripheralManager.add(svc)
        }
        trace("Service Changed cycled")
    }

    /// temp service used to perturb the GATT to trigger Service Changed
    private func buildServiceChangedTrigger() -> CBMutableService {
        let service = CBMutableService(type: CBUUID(nsuuid: UUID()), primary: true)
        service.characteristics = [
            CBMutableCharacteristic(
                type: CBUUID(nsuuid: UUID()),
                properties: [.read, .notifyEncryptionRequired],
                value: nil,
                permissions: .readEncryptionRequired
            )
        ]
        return service
    }

    private func installServices() {
        guard let peripheralManager, !isHIDServiceAdded, batteryService == nil else { return }
        let battery = buildBatteryService()
        batteryService = battery
        peripheralManager.add(battery)
    }

    private func buildDeviceInfoService() -> CBMutableService {
        let service = CBMutableService(type: GamepadHIDProfile.deviceInformationService, primary: true)
        service.characteristics = [
            CBMutableCharacteristic(
                type: GamepadHIDProfile.manufacturerName,
                properties: .read,
                value: GamepadHIDProfile.manufacturerNameValue,
                permissions: .readable
            ),
            CBMutableCharacteristic(
                type: GamepadHIDProfile.modelNumber,
                properties: .read,
                value: GamepadHIDProfile.modelNumberValue,
                permissions: .readable
            ),
            CBMutableCharacteristic(
                type: GamepadHIDProfile.pnpID,
                properties: .read,
                value: GamepadHIDProfile.pnpIDValue,
                permissions: .readable
            ),
        ]
        return service
    }

    private func buildBatteryService() -> CBMutableService {
        let service = CBMutableService(type: GamepadHIDProfile.batteryService, primary: true)
        let level = CBMutableCharacteristic(
            type: GamepadHIDProfile.batteryLevel,
            properties: [.read, .notifyEncryptionRequired],
            value: nil,
            permissions: .readEncryptionRequired
        )
        service.characteristics = [level]
        batteryLevelCharacteristic = level
        return service
    }

    private func buildHIDService(includingBattery battery: CBMutableService?) -> CBMutableService {
        // Keep the tested GATT layout and Xbox report identities unchanged.
        let service = CBMutableService(type: GamepadHIDProfile.hidService, primary: true)
        let info = CBMutableCharacteristic(
            type: GamepadHIDProfile.hidInformation, properties: .read,
            value: GamepadHIDProfile.hidInformationValue, permissions: .readEncryptionRequired)
        let map = CBMutableCharacteristic(
            type: GamepadHIDProfile.reportMap, properties: .read,
            value: GamepadHIDProfile.reportMapData, permissions: .readEncryptionRequired)
        let control = CBMutableCharacteristic(
            type: GamepadHIDProfile.hidControlPoint, properties: .writeWithoutResponse,
            value: nil, permissions: .writeEncryptionRequired)
        let input = makeReportCharacteristic(GamepadHIDProfile.inputReportID, type: .input)
        let output = CBMutableCharacteristic(
            type: GamepadHIDProfile.report, properties: [.read, .write, .writeWithoutResponse],
            value: nil, permissions: [.readEncryptionRequired, .writeEncryptionRequired])
        output.descriptors = [
            CBMutableDescriptor(
                type: GamepadHIDProfile.reportReference,
                value: Data([GamepadHIDProfile.outputReportID, 2]) as NSData)
        ]
        service.characteristics = [info, map, control, input, output]
        reportCharacteristics[GamepadHIDProfile.inputReportID] = input
        reportCharacteristics[GamepadHIDProfile.outputReportID] = output
        return service
    }

    private func makeReportCharacteristic(_ id: UInt8, type: GamepadReportType) -> CBMutableCharacteristic {
        let char = CBMutableCharacteristic(
            type: GamepadHIDProfile.report,
            properties: [.read, .notifyEncryptionRequired],
            value: nil,
            permissions: .readEncryptionRequired
        )
        char.descriptors = [
            CBMutableDescriptor(
                type: GamepadHIDProfile.reportReference, value: NSData(data: Data([id, type.rawValue])))
        ]
        return char
    }

    private func startAdvertisingNow() {
        guard let peripheralManager, !isAdvertising else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataLocalNameKey: advertiseLocalName,
            // hidService must stay first if more than one service is being advertised
            CBAdvertisementDataServiceUUIDsKey: [GamepadHIDProfile.hidService],
        ])
    }

    private func broadcast(_ data: Data, reportID: UInt8) {
        cachedReports[reportID] = data
        guard let char = reportCharacteristics[reportID] else { return }
        _ = updateValue(data, for: char)
    }

    @discardableResult
    private func updateValue(_ data: Data, for char: CBMutableCharacteristic) -> Bool {
        guard let peripheralManager else { return false }
        let recipients = activeRecipients(for: char)
        guard !recipients.isEmpty else { return false }
        if !isReadyToSendNotification {
            pendingReports.enqueue((data, char), for: ObjectIdentifier(char))
            return false
        }
        let accepted = peripheralManager.updateValue(data, for: char, onSubscribedCentrals: recipients)
        if !accepted {
            isReadyToSendNotification = false
            pendingReports.enqueue((data, char), for: ObjectIdentifier(char))
        }
        return accepted
    }

    private func drainPendingBroadcast() {
        guard let peripheralManager else { return }
        while let (key, (data, char)) = pendingReports.popFirst() {
            let recipients = activeRecipients(for: char)
            guard !recipients.isEmpty else { continue }
            if !peripheralManager.updateValue(data, for: char, onSubscribedCentrals: recipients) {
                isReadyToSendNotification = false
                pendingReports.enqueue((data, char), for: key)
                return
            }
        }
    }

    private func trace(_ message: @autoclosure () -> String) {
        guard UserDefaults.standard.bool(forKey: GamepadSettings.developerModeKey) else { return }
        let text = message()
        log.info("\(text, privacy: .public)")
        #if DEBUG
            print("GamepadPeripheral: \(text)")
        #endif
    }

    private func _trackInteraction(from central: CBCentral) {
        centralObjects[central.identifier] = central
        guard !connectedCentrals.contains(central.identifier) else { return }
        connectedCentrals.insert(central.identifier)
        trace("central tracked: \(central.identifier)")
    }

    private func activeRecipients(for char: CBMutableCharacteristic) -> [CBCentral] {
        subscribedCentrals.keys
            .filter { !inactiveCentrals.contains($0) }
            .filter { subscriptions[$0]?.contains(ObjectIdentifier(char)) == true }
            .compactMap { centralObjects[$0] }
    }

    private func reportID(forCharacteristic char: CBCharacteristic) -> UInt8? {
        for (id, c) in reportCharacteristics where c.uuid == char.uuid && c === char as AnyObject {
            return id
        }
        // fallback for restored characteristics
        if char.uuid == GamepadHIDProfile.report,
            let descriptor = (char as? CBMutableCharacteristic)?
                .descriptors?
                .first(where: { $0.uuid == GamepadHIDProfile.reportReference }),
            let value = descriptor.value as? Data,
            let id = value.first
        {
            return id
        }
        return nil
    }
}

extension GamepadPeripheral: @preconcurrency CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        state = peripheral.state
        trace("CB state -> \(peripheral.state.rawValue)")
        if peripheral.state == .poweredOn, isHIDServiceAllowed, !isHIDServiceAdded {
            installServices()
        }
        if peripheral.state != .poweredOn {
            isAdvertising = false
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            log.error("didAddService(\(service.uuid)) error: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            #if DEBUG
                print("GamepadPeripheral: service registration failed: \(service.uuid): \(error)")
            #endif
            return
        }
        trace("service added: \(service.uuid)")
        switch service.uuid {
        case GamepadHIDProfile.batteryService:
            let dis = buildDeviceInfoService()
            deviceInformationService = dis
            peripheral.add(dis)
        case GamepadHIDProfile.deviceInformationService:
            let hid = buildHIDService(includingBattery: batteryService)
            gamepadService = hid
            peripheral.add(hid)
        case GamepadHIDProfile.hidService:
            isHIDServiceAdded = true
            startAdvertisingNow()
        default:
            break
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            isAdvertising = false
            lastError = error.localizedDescription
            log.error("startAdvertising error: \(error.localizedDescription, privacy: .public)")
        } else {
            isAdvertising = true
            trace("advertising as \(advertiseLocalName)")
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        _trackInteraction(from: central)
        subscribedCentrals[central.identifier, default: []].insert(characteristic.uuid)
        subscriptions[central.identifier, default: []].insert(ObjectIdentifier(characteristic))
        if reportID(forCharacteristic: characteristic) == GamepadHIDProfile.inputReportID {
            gamepadSubscribers.insert(central.identifier)
        }
        trace("subscribe: \(central.identifier) -> \(characteristic.uuid)")
        if let id = reportID(forCharacteristic: characteristic),
            let cached = cachedReports[id],
            let char = reportCharacteristics[id]
        {
            _ = updateValue(cached, for: char)
        } else if characteristic.uuid == GamepadHIDProfile.batteryLevel, let batteryLevelCharacteristic {
            _ = updateValue(Data([batteryLevel]), for: batteryLevelCharacteristic)
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        trace("unsubscribe: \(central.identifier) <- \(characteristic.uuid)")
        subscriptions[central.identifier]?.remove(ObjectIdentifier(characteristic))
        if reportID(forCharacteristic: characteristic) == GamepadHIDProfile.inputReportID {
            gamepadSubscribers.remove(central.identifier)
        }
        if subscriptions[central.identifier]?.isEmpty != false {
            subscriptions.removeValue(forKey: central.identifier)
            subscribedCentrals.removeValue(forKey: central.identifier)
            centralObjects.removeValue(forKey: central.identifier)
            inactiveCentrals.remove(central.identifier)
            connectedCentrals.remove(central.identifier)
            serviceChangedArmed = false
        } else {
            // Several report characteristics share 0x2A4D; removing one must not
            // mark a host disconnected while its other reports remain subscribed.
            let remaining = subscriptions[central.identifier] ?? []
            let characteristics =
                Array(reportCharacteristics.values)
                + [batteryLevelCharacteristic].compactMap { $0 }
            subscribedCentrals[central.identifier] = Set(
                characteristics
                    .filter { remaining.contains(ObjectIdentifier($0)) }.map(\.uuid))
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        isReadyToSendNotification = true
        drainPendingBroadcast()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        trace("read: \(request.central.identifier) -> \(request.characteristic.uuid)")
        _trackInteraction(from: request.central)
        scheduleServiceChanged()
        let value = readValue(forRequest: request)
        guard let value else {
            peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
            return
        }
        guard request.offset <= value.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = value.subdata(in: request.offset..<value.count)
        peripheral.respond(to: request, withResult: .success)
    }

    private func readValue(forRequest request: CBATTRequest) -> Data? {
        switch request.characteristic.uuid {
        case GamepadHIDProfile.batteryLevel: return Data([batteryLevel])
        case GamepadHIDProfile.hidInformation: return GamepadHIDProfile.hidInformationValue
        case GamepadHIDProfile.reportMap: return GamepadHIDProfile.reportMapData
        case GamepadHIDProfile.manufacturerName: return GamepadHIDProfile.manufacturerNameValue
        case GamepadHIDProfile.modelNumber: return GamepadHIDProfile.modelNumberValue
        case GamepadHIDProfile.pnpID: return GamepadHIDProfile.pnpIDValue
        case GamepadHIDProfile.report:
            if let id = reportID(forCharacteristic: request.characteristic) {
                return cachedReports[id] ?? Data()
            }
            return Data()
        default: return Data()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            trace("write: \(request.central.identifier) -> \(request.characteristic.uuid)")
            _trackInteraction(from: request.central)
            // Accept the compatible output report; force feedback is not implemented.
        }
        if let first = requests.first {
            peripheral.respond(to: first, withResult: .success)
        }
    }

}
