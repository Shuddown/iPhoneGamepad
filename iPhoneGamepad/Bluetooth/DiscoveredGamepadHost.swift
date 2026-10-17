import CoreBluetooth
import Foundation

struct DiscoveredGamepadHost: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isNamed: Bool
    var rssi: Int
    var advertisedServices: [CBUUID]
    var companyID: UInt16?
    var txPower: Int?
    var isConnectable: Bool?
}
