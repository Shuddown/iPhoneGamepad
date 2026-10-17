import Foundation

enum GamepadSettings {
    static let advertisedNameKey = "Gamepad.advertisedName"
    static let developerModeKey = "Gamepad.developerLogging"
    static let useServiceChangedKey = "Gamepad.refreshServices"
    static let forgivingKey = "Gamepad.forgiving"
    static let hapticsKey = "Gamepad.haptics"

    static func registerDefaults() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            advertisedNameKey: "iPhone Gamepad",
            useServiceChangedKey: true, hapticsKey: true,
        ])
    }
}
