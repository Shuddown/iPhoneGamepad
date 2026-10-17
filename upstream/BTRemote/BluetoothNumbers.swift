import CoreBluetooth
import Foundation

enum BluetoothNumbers {
    static func company(_ code: UInt16) -> String? {
        companies[code]
    }

    static func service(_ uuid: CBUUID) -> String? {
        services[uuid.uuidString.uppercased()]
    }

    private static let companies: [UInt16: String] = {
        let entries: [CompanyEntry] = load("company_ids")
        return Dictionary(
            entries.compactMap { (0 ... 0xFFFF).contains($0.code) ? (UInt16($0.code), $0.name) : nil },
            uniquingKeysWith: { first, _ in first }
        )
    }()

    private static let services: [String: String] = {
        let entries: [ServiceEntry] = load("service_uuids")
        return Dictionary(entries.map { ($0.uuid.uppercased(), $0.name) }, uniquingKeysWith: { first, _ in first })
    }()

    private static func load<T: Decodable>(_ resource: String) -> [T] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([T].self, from: data)
        else { return [] }
        return decoded
    }

    private struct CompanyEntry: Decodable {
        let code: Int
        let name: String
    }

    private struct ServiceEntry: Decodable {
        let uuid: String
        let name: String
    }
}
