import Foundation

enum GamepadSettings {
    static let advertisedNameKey = "Gamepad.advertisedName"
    static let developerModeKey = "Gamepad.developerLogging"
    static let useServiceChangedKey = "Gamepad.refreshServices"
    static let hapticsKey = "Gamepad.haptics"

    static func registerDefaults() {
        let defaults = UserDefaults.standard
        // Preserve the tested prototype's advertised name when upgrading in place.
        if defaults.object(forKey: advertisedNameKey) == nil,
           let previousName = defaults.string(forKey: "BTRemote.advertisedName") {
            defaults.set(previousName, forKey: advertisedNameKey)
        }
        defaults.register(defaults: [advertisedNameKey: "iPhone Gamepad",
                                     useServiceChangedKey: true, hapticsKey: true])
    }
}
