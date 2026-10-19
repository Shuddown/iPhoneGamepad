import Foundation

enum GamepadSettings {
    static let advertisedNameKey = "Gamepad.advertisedName"
    static let developerModeKey = "Gamepad.developerLogging"
    static let knownHostsKey = "Gamepad.knownHosts"
    static let connectedHostsKey = "Gamepad.connectedHosts"
    static let forgivingKey = "Gamepad.forgiving"
    static let hapticsKey = "Gamepad.haptics"

    static func registerDefaults() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            advertisedNameKey: "iPhone Gamepad",
            hapticsKey: true,
        ])
    }
}
