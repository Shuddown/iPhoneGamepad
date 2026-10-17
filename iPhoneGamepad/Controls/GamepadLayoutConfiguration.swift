import CoreGraphics
import Foundation

/// Normalized centers survive display size changes; size is relative to the standard layout.
struct GamepadLayoutConfiguration: Codable, Equatable {
    struct Placement: Codable, Equatable {
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
    }
    var controls: [String: Placement] = [:]

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "Gamepad.layout"),
            let value = try? JSONDecoder().decode(Self.self, from: data)
        else { return .init() }
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "Gamepad.layout")
    }

    mutating func place(_ control: GamepadControl, center: CGPoint, scale: CGFloat, in bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        controls[control.rawValue] = Placement(
            x: (center.x - bounds.minX) / bounds.width,
            y: (center.y - bounds.minY) / bounds.height, scale: scale)
    }
}
