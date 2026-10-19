import Combine
import CoreBluetooth
import Foundation
import os

/// Discovers gamepad hosts and registers the connection events needed for pairing.
@MainActor
final class GamepadHostDiscovery: NSObject, ObservableObject {
    @Published private(set) var state: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var discovered: [DiscoveredGamepadHost] = []
    @Published private(set) var connected: Set<UUID> = []
    @Published private(set) var connecting: Set<UUID> = []
    @Published private(set) var lastError: String?

    static let restoreIdentifier = "iPhoneGamepad.central.v1"

    private let log = Logger(subsystem: "com.shudhesh.iphonegamepad", category: "GamepadHostDiscovery")
    private var centralManager: CBCentralManager?
    private var scanRequested = false
    private var rememberedHosts: Set<UUID> = []
    private var peripheralCache: [UUID: CBPeripheral] = [:]

    private func trace(_ message: @autoclosure () -> String) {
        guard UserDefaults.standard.bool(forKey: GamepadSettings.developerModeKey) else { return }
        let text = message()
        log.info("\(text, privacy: .public)")
    }

    func start() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: GamepadHostDiscovery.restoreIdentifier,
                CBCentralManagerOptionShowPowerAlertKey: true,
            ]
        )
    }

    func startScan() {
        scanRequested = true
        guard let centralManager, centralManager.state == .poweredOn else {
            start()
            return
        }
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
        trace("scan started")
    }

    func stopScan() {
        scanRequested = false
        centralManager?.stopScan()
        isScanning = false
        trace("scan stopped")
    }

    func connect(_ identifier: UUID) {
        guard let centralManager else { return }
        let peripheral =
            peripheralCache[identifier]
            ?? centralManager.retrievePeripherals(withIdentifiers: [identifier]).first
        guard let peripheral else {
            lastError = "This device is no longer available. Scan again."
            return
        }
        peripheralCache[identifier] = peripheral
        connecting.insert(identifier)
        centralManager.connect(
            peripheral,
            options: [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            ])
        trace("connect requested: \(peripheral.identifier)")
    }

    func disconnect(_ identifier: UUID) {
        guard let centralManager, let peripheral = peripheralCache[identifier] else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func disconnectAll() {
        stopScan()
        for identifier in connected.union(connecting) { disconnect(identifier) }
    }

    /// Resolve the same local peer identifiers used by peripheral-role subscribers.
    /// This retains manual connection controls even while another host is active.
    func rememberHosts(_ identifiers: Set<UUID>) {
        rememberedHosts.formUnion(identifiers)
        guard let centralManager, centralManager.state == .poweredOn else { return }
        for peer in centralManager.retrievePeripherals(withIdentifiers: Array(identifiers)) {
            peripheralCache[peer.identifier] = peer
            upsertDiscovered(peripheral: peer, advertisementData: [:], rssi: 0)
        }
    }

    func refreshConnectedHosts(
        servicesFilter: [CBUUID] = [GamepadHIDProfile.hidService, CBUUID(string: "180A"), CBUUID(string: "1800")]
    ) {
        guard let centralManager else { return }
        let known = centralManager.retrieveConnectedPeripherals(withServices: servicesFilter)
        for peripheral in known {
            peripheralCache[peripheral.identifier] = peripheral
            upsertDiscovered(peripheral: peripheral, advertisementData: [:], rssi: 0)
        }
    }

    private func upsertDiscovered(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: Int
    ) {
        let resolvedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let companyID = Self.companyID(from: advertisementData)
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        trace(
            "discovered: \(peripheral.identifier) name=\(resolvedName ?? "nil") company=\(companyID ?? 0) services=\(services) rssi=\(rssi)"
        )
        let entry = DiscoveredGamepadHost(
            id: peripheral.identifier,
            name: resolvedName ?? "Unnamed device",
            isNamed: resolvedName != nil,
            rssi: rssi,
            advertisedServices: services,
            companyID: companyID,
            txPower: txPower,
            isConnectable: isConnectable
        )
        if let index = discovered.firstIndex(where: { $0.id == entry.id }) {
            let existing = discovered[index]
            discovered[index] = DiscoveredGamepadHost(
                id: entry.id,
                name: entry.isNamed ? entry.name : existing.name,
                isNamed: existing.isNamed || entry.isNamed,
                rssi: rssi == 0 ? existing.rssi : rssi,
                advertisedServices: services.isEmpty ? existing.advertisedServices : services,
                companyID: companyID ?? existing.companyID,
                txPower: txPower ?? existing.txPower,
                isConnectable: isConnectable ?? existing.isConnectable
            )
        } else {
            discovered.append(entry)
        }
    }

    private static func companyID(from advertisementData: [String: Any]) -> UInt16? {
        guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, data.count >= 2 else {
            return nil
        }
        let bytes = [UInt8](data.prefix(2))
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }
}

extension GamepadHostDiscovery: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        trace("central state -> \(central.state.rawValue)")
        if central.state == .poweredOn {
            // must happen before HID services are added
            #if os(iOS)
                central.registerForConnectionEvents(options: nil)
            #endif
            refreshConnectedHosts()
            rememberHosts(rememberedHosts)
            if scanRequested { startScan() }
        }
        if central.state != .poweredOn {
            isScanning = false
            connected.removeAll()
            connecting.removeAll()
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        trace("central willRestoreState: \(dict.keys.sorted())")
        if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restored {
                peripheralCache[peripheral.identifier] = peripheral
                upsertDiscovered(peripheral: peripheral, advertisementData: [:], rssi: 0)
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        peripheralCache[peripheral.identifier] = peripheral
        upsertDiscovered(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: rssi.intValue
        )
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connecting.remove(peripheral.identifier)
        connected.insert(peripheral.identifier)
        trace("connected: \(peripheral.identifier)")
        peripheralCache[peripheral.identifier] = peripheral
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connecting.remove(peripheral.identifier)
        connected.remove(peripheral.identifier)
        if let error {
            log.error("disconnected with error: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        } else {
            trace("disconnected: \(peripheral.identifier)")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connecting.remove(peripheral.identifier)
        if let error {
            lastError = "Could not connect: \(error.localizedDescription)"
            log.error("failed to connect: \(error.localizedDescription, privacy: .public)")
        }
    }
}
