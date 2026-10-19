import Combine
import CoreBluetooth
import Foundation
import os

/// Publishes a separate, independently removable gamepad service for each selected host.
@MainActor
final class GamepadPeripheral: NSObject, ObservableObject {
    @Published private(set) var state: CBManagerState = .unknown
    @Published private(set) var isAdvertising = false
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?
    @Published private(set) var batteryLevel: UInt8 = 100
    /// Only subscriptions to a host's own published gamepad count as connected.
    @Published private(set) var gamepadSubscribers: Set<UUID> = []
    @Published private(set) var requestedHosts: Set<UUID>
    @Published private(set) var knownHostIDs: Set<UUID>
    @Published private(set) var observedHostIDs: Set<UUID> = []

    var advertiseLocalName: String =
        UserDefaults.standard.string(forKey: GamepadSettings.advertisedNameKey) ?? "iPhone Gamepad"

    private let log = Logger(subsystem: "com.shudhesh.iphonegamepad", category: "GamepadPeripheral")
    private let defaults: UserDefaults
    private var hasStarted = false
    private var peripheralManager: CBPeripheralManager?
    private var batteryService: CBMutableService?
    private var deviceInformationService: CBMutableService?
    private var batteryCharacteristic: CBMutableCharacteristic?
    private var commonServicesReady = false
    private var withdrawOnPowerOn = false
    private var hostServices: [UUID: GamepadHostService] = [:]
    private var centralObjects: [UUID: CBCentral] = [:]
    private var subscriptions: [ObjectIdentifier: Set<UUID>] = [:]
    private var latestInput = GamepadReport.zero.data
    private var isReadyToSendNotification = true
    private var pendingReports = GamepadReportBuffer<ObjectIdentifier, (Data, CBMutableCharacteristic)>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        requestedHosts = Set(
            (defaults.stringArray(forKey: GamepadSettings.connectedHostsKey) ?? []).compactMap(UUID.init(uuidString:)))
        knownHostIDs = Set(
            (defaults.stringArray(forKey: GamepadSettings.knownHostsKey) ?? []).compactMap(UUID.init(uuidString:)))
        super.init()
        knownHostIDs.formUnion(requestedHosts)
    }

    func startIfNeeded() {
        if !hasStarted { start() }
    }

    func start() {
        hasStarted = true
        guard !isRunning else { return }
        isRunning = true
        latestInput = GamepadReport.zero.data
        peripheralManager = CBPeripheralManager(
            delegate: self, queue: nil,
            options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }

    func connectHost(_ hostID: UUID) {
        lastError = nil
        knownHostIDs.insert(hostID)
        requestedHosts.insert(hostID)
        saveHosts()
        start()
        publishHostIfNeeded(hostID)
    }

    /// Remove this host's actual HID service, leaving other hosts' controllers published.
    func disconnectHost(_ hostID: UUID) {
        requestedHosts.remove(hostID)
        saveHosts()
        if let session = hostServices[hostID] {
            if session.isPublished {
                _ = updateValue(GamepadReport.zero.data, for: session.input, owner: hostID)
                peripheralManager?.remove(session.service)
            }
            // A pending add is withdrawn in didAddService, even if it arrives late.
            hostServices.removeValue(forKey: hostID)
            forgetSubscriptions(for: session)
        }
        gamepadSubscribers.remove(hostID)
        trace("controller withdrawn for host: \(hostID)")
    }

    func stop() {
        sendGamepad(.zero)
        requestedHosts.removeAll()
        saveHosts()
        isRunning = false
        if peripheralManager?.state == .poweredOn {
            peripheralManager?.stopAdvertising()
            peripheralManager?.removeAllServices()
        }
        peripheralManager?.delegate = nil
        peripheralManager = nil
        clearRuntime()
        trace("all controller services withdrawn")
    }

    func promptPowerAlert() {
        guard state != .poweredOn else { return }
        peripheralManager?.delegate = nil
        peripheralManager = nil
        clearRuntime()
        isRunning = false
        start()
    }

    private func saveHosts() {
        defaults.set(knownHostIDs.map(\.uuidString).sorted(), forKey: GamepadSettings.knownHostsKey)
        defaults.set(requestedHosts.map(\.uuidString).sorted(), forKey: GamepadSettings.connectedHostsKey)
    }

    private func clearRuntime() {
        hostServices.removeAll()
        centralObjects.removeAll()
        subscriptions.removeAll()
        observedHostIDs.removeAll()
        gamepadSubscribers.removeAll()
        pendingReports.removeAll()
        latestInput = GamepadReport.zero.data
        batteryService = nil
        deviceInformationService = nil
        batteryCharacteristic = nil
        commonServicesReady = false
        isAdvertising = false
        isReadyToSendNotification = true
    }

    private func publishHostIfNeeded(_ hostID: UUID) {
        guard isRunning, commonServicesReady, requestedHosts.contains(hostID),
            hostServices[hostID] == nil, let peripheralManager,
            peripheralManager.state == .poweredOn
        else { return }
        let session = GamepadHostService(hostID: hostID)
        hostServices[hostID] = session
        peripheralManager.add(session.service)
        trace("publishing controller for host: \(hostID)")
    }

    private func forgetSubscriptions(for session: GamepadHostService) {
        for characteristic in session.service.characteristics ?? [] {
            let key = ObjectIdentifier(characteristic)
            subscriptions.removeValue(forKey: key)
            pendingReports.removeValue(for: key)
        }
    }

    private func session(for characteristic: CBCharacteristic) -> GamepadHostService? {
        hostServices.values.first { $0.contains(characteristic) }
    }

    private func refreshSubscribers() {
        gamepadSubscribers = Set(
            hostServices.values.compactMap { session in
                session.isPublished && requestedHosts.contains(session.hostID)
                    && subscriptions[ObjectIdentifier(session.input)]?.contains(session.hostID) == true
                    ? session.hostID : nil
            })
    }

    func sendGamepad(_ report: GamepadReport) {
        guard isRunning else { return }
        latestInput = report.data
        for session in hostServices.values where session.isPublished && requestedHosts.contains(session.hostID) {
            _ = updateValue(latestInput, for: session.input, owner: session.hostID)
        }
    }

    #if DEBUG
        /// Exercise the production lifecycle using explicitly supplied local test peer IDs.
        func runHostLifecycleProbeIfRequested(discovery: GamepadHostDiscovery) async {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "--host-lifecycle-probe"),
                arguments.count > index + 2,
                let first = UUID(uuidString: arguments[index + 1]),
                let second = UUID(uuidString: arguments[index + 2]), first != second
            else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            for host in [first, second] {
                connectHost(host)
                discovery.rememberHosts([host])
                discovery.connect(host)
            }
            for _ in 0..<60 {
                if gamepadSubscribers.isSuperset(of: [first, second]) { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
            }
            guard gamepadSubscribers.isSuperset(of: [first, second]) else {
                print("HOST_PROBE: both hosts did not subscribe")
                return
            }
            for phase in 0..<9 {
                if Task.isCancelled { return }
                if phase == 1 || phase == 3 {
                    disconnectHost(second)
                    discovery.disconnect(second)
                }
                if phase == 5 || phase == 7 {
                    disconnectHost(first)
                    discovery.disconnect(first)
                }
                if phase == 2 || phase == 4 {
                    connectHost(second)
                    discovery.connect(second)
                }
                if phase == 6 || phase == 8 {
                    connectHost(first)
                    discovery.connect(first)
                }
                print("HOST_PROBE: phase \(phase) start \(Date())")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                for _ in 0..<8 {
                    sendGamepad(GamepadReport(buttons: 1))
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    sendGamepad(.zero)
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
                print("HOST_PROBE: phase \(phase) end subscribers=\(gamepadSubscribers.count) \(Date())")
            }
        }

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

    func refreshAdvertising() {
        guard isRunning, commonServicesReady else { return }
        peripheralManager?.stopAdvertising()
        isAdvertising = false
        startAdvertising()
    }

    func updateBatteryLevel(_ level: UInt8) {
        batteryLevel = min(level, 100)
        if let batteryCharacteristic { _ = updateValue(Data([batteryLevel]), for: batteryCharacteristic) }
    }

    private func startAdvertising() {
        guard isRunning, commonServicesReady, !isAdvertising, let peripheralManager else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataLocalNameKey: advertiseLocalName,
            CBAdvertisementDataServiceUUIDsKey: [GamepadHIDProfile.hidService],
        ])
    }

    private func installServices() {
        guard isRunning, batteryService == nil, let peripheralManager else { return }
        let service = CBMutableService(type: GamepadHIDProfile.batteryService, primary: true)
        let level = CBMutableCharacteristic(
            type: GamepadHIDProfile.batteryLevel, properties: [.read, .notifyEncryptionRequired],
            value: nil, permissions: .readEncryptionRequired)
        service.characteristics = [level]
        batteryCharacteristic = level
        batteryService = service
        peripheralManager.add(service)
    }

    private func addDeviceInformation() {
        let service = CBMutableService(type: GamepadHIDProfile.deviceInformationService, primary: true)
        service.characteristics = [
            CBMutableCharacteristic(
                type: GamepadHIDProfile.manufacturerName, properties: .read,
                value: GamepadHIDProfile.manufacturerNameValue, permissions: .readable),
            CBMutableCharacteristic(
                type: GamepadHIDProfile.modelNumber, properties: .read,
                value: GamepadHIDProfile.modelNumberValue, permissions: .readable),
            CBMutableCharacteristic(
                type: GamepadHIDProfile.pnpID, properties: .read,
                value: GamepadHIDProfile.pnpIDValue, permissions: .readable),
        ]
        deviceInformationService = service
        peripheralManager?.add(service)
    }

    private func recipients(for characteristic: CBMutableCharacteristic, owner: UUID? = nil) -> [CBCentral] {
        (subscriptions[ObjectIdentifier(characteristic)] ?? [])
            .filter { owner == nil || $0 == owner }
            .compactMap { centralObjects[$0] }
    }

    @discardableResult
    private func updateValue(_ data: Data, for characteristic: CBMutableCharacteristic, owner: UUID? = nil) -> Bool {
        guard isRunning, let peripheralManager else { return false }
        let targets = recipients(for: characteristic, owner: owner)
        guard !targets.isEmpty else { return false }
        let key = ObjectIdentifier(characteristic)
        guard isReadyToSendNotification else {
            pendingReports.enqueue((data, characteristic), for: key)
            return false
        }
        let accepted = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: targets)
        if !accepted {
            isReadyToSendNotification = false
            pendingReports.enqueue((data, characteristic), for: key)
        }
        return accepted
    }

    private func drainPendingReports() {
        while let (_, (data, characteristic)) = pendingReports.popFirst() {
            let owner: UUID?
            if characteristic === batteryCharacteristic {
                owner = nil
            } else {
                guard let session = session(for: characteristic), session.isPublished,
                    requestedHosts.contains(session.hostID)
                else { continue }
                owner = session.hostID
            }
            guard !recipients(for: characteristic, owner: owner).isEmpty else { continue }
            if !updateValue(data, for: characteristic, owner: owner) {
                // updateValue keeps this characteristic's latest absolute state queued.
                return
            }
        }
    }

    private func observe(_ central: CBCentral) {
        centralObjects[central.identifier] = central
        observedHostIDs.insert(central.identifier)
    }

    private func trace(_ text: String) {
        guard defaults.bool(forKey: GamepadSettings.developerModeKey) else { return }
        log.info("\(text, privacy: .public)")
        #if DEBUG
            print("GamepadPeripheral: \(text)")
        #endif
    }
}

extension GamepadPeripheral: @preconcurrency CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral === peripheralManager else { return }
        state = peripheral.state
        trace("Bluetooth state: \(state.rawValue)")
        if state == .poweredOn, isRunning {
            if withdrawOnPowerOn {
                peripheral.removeAllServices()
                withdrawOnPowerOn = false
            }
            installServices()
        } else if state != .poweredOn {
            clearRuntime()
            withdrawOnPowerOn = true
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard peripheral === peripheralManager else { return }
        let session = hostServices.values.first { $0.service === service }
        let current = service === batteryService || service === deviceInformationService || session != nil
        guard current else {
            if error == nil, let obsolete = service as? CBMutableService { peripheral.remove(obsolete) }
            return
        }
        if let error {
            lastError = error.localizedDescription
            if let session { hostServices.removeValue(forKey: session.hostID) }
            trace("service publication failed: \(error)")
            return
        }
        if service === batteryService {
            addDeviceInformation()
        } else if service === deviceInformationService {
            commonServicesReady = true
            for hostID in requestedHosts.sorted(by: { $0.uuidString < $1.uuidString }) { publishHostIfNeeded(hostID) }
            startAdvertising()
        } else if let session {
            session.isPublished = true
            refreshSubscribers()
            trace("controller service ready for host: \(session.hostID)")
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard peripheral === peripheralManager else { return }
        isAdvertising = error == nil && isRunning
        if let error { lastError = error.localizedDescription }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager, central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard peripheral === peripheralManager,
            characteristic === batteryCharacteristic || session(for: characteristic) != nil
        else { return }
        observe(central)
        subscriptions[ObjectIdentifier(characteristic), default: []].insert(central.identifier)
        if let session = session(for: characteristic), characteristic === session.input {
            refreshSubscribers()
            if central.identifier == session.hostID {
                _ = updateValue(GamepadReport.zero.data, for: session.input, owner: session.hostID)
                trace("host subscribed to its gamepad: \(session.hostID)")
            }
        } else if characteristic === batteryCharacteristic, let batteryCharacteristic {
            _ = updateValue(Data([batteryLevel]), for: batteryCharacteristic)
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager, central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard peripheral === peripheralManager else { return }
        subscriptions[ObjectIdentifier(characteristic)]?.remove(central.identifier)
        refreshSubscribers()
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard peripheral === peripheralManager else { return }
        isReadyToSendNotification = true
        drainPendingReports()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard peripheral === peripheralManager else { return }
        observe(request.central)
        let value: Data?
        switch request.characteristic.uuid {
        case GamepadHIDProfile.batteryLevel: value = Data([batteryLevel])
        case GamepadHIDProfile.hidInformation: value = GamepadHIDProfile.hidInformationValue
        case GamepadHIDProfile.reportMap:
            value = session(for: request.characteristic).map {
                GamepadHIDProfile.reportMap(for: request.central.identifier, owner: $0.hostID)
            }
        case GamepadHIDProfile.report:
            if let session = session(for: request.characteristic) {
                value =
                    request.characteristic === session.input
                    ? (request.central.identifier == session.hostID ? latestInput : GamepadReport.zero.data)
                    : Data(repeating: 0, count: 8)
            } else {
                value = nil
            }
        default: value = nil
        }
        guard let value else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        guard request.offset <= value.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = value.subdata(in: request.offset..<value.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard peripheral === peripheralManager else { return }
        for request in requests { observe(request.central) }
        // Output reports and suspend/resume are accepted; force feedback is not implemented.
        if let first = requests.first { peripheral.respond(to: first, withResult: .success) }
    }
}
