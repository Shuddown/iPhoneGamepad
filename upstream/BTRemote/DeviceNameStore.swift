import Combine
import Foundation

@MainActor
final class DeviceNameStore: ObservableObject {
    @Published private var names: [String: String]

    init() {
        names = UserDefaults.standard.dictionary(forKey: AppSettings.deviceNamesKey) as? [String: String] ?? [:]
    }

    func name(for id: UUID) -> String? {
        names[id.uuidString]
    }

    func setName(_ name: String, for id: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            names.removeValue(forKey: id.uuidString)
        } else {
            names[id.uuidString] = trimmed
        }
        UserDefaults.standard.set(names, forKey: AppSettings.deviceNamesKey)
    }

    func clear() {
        names = [:]
        UserDefaults.standard.removeObject(forKey: AppSettings.deviceNamesKey)
    }
}
