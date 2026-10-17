import CoreGraphics
import Foundation

struct GamepadContact {
    var control: GamepadControl
    var x: Double = 0
    var y: Double = 0
    var pressure: Double = 1
}

/// Touch ownership preserves held inputs while other fingers press, move or lift.
struct GamepadInputState {
    private(set) var contacts: [Int: GamepadContact] = [:]
    mutating func set(_ contact: GamepadContact, for id: Int) { contacts[id] = contact }
    mutating func remove(_ id: Int) { contacts.removeValue(forKey: id) }
    mutating func reset() { contacts.removeAll() }

    var report: GamepadReport {
        var result = GamepadReport.zero
        for contact in contacts.values {
            if let number = contact.control.buttonNumber { result.setButton(number, pressed: true) }
            switch contact.control {
            case .leftStick:
                result.leftX = Self.axis(contact.x)
                result.leftY = Self.axis(contact.y)
            case .rightStick:
                result.rightX = Self.axis(contact.x)
                result.rightY = Self.axis(contact.y)
            case .l2:
                result.leftTrigger = max(result.leftTrigger, UInt8((max(0, min(1, contact.pressure)) * 255).rounded()))
            case .r2:
                result.rightTrigger = max(
                    result.rightTrigger, UInt8((max(0, min(1, contact.pressure)) * 255).rounded()))
            case .dpad:
                if hypot(contact.x, contact.y) > 0.23 {
                    let angle = atan2(contact.x, -contact.y)
                    result.hat = UInt8((Int((angle / (.pi / 4)).rounded()) + 8) % 8)
                }
            default: break
            }
        }
        return result
    }

    static func stickContact(
        _ control: GamepadControl, point: CGPoint, frame: CGRect,
        origin: CGPoint, floating: Bool
    ) -> GamepadContact {
        let center = floating ? origin : CGPoint(x: frame.midX, y: frame.midY)
        let travel = max(1, frame.width * 0.32)
        let x = (point.x - center.x) / travel
        let y = (point.y - center.y) / travel
        let magnitude = max(1, hypot(x, y))
        return GamepadContact(control: control, x: x / magnitude, y: y / magnitude)
    }

    private static func axis(_ value: Double) -> Int8 {
        let clamped = max(-1, min(1, value))
        let magnitude = abs(clamped)
        guard magnitude > 0.10 else { return 0 }
        let adjusted = (magnitude - 0.10) / 0.90
        return Int8((adjusted * (clamped < 0 ? -127 : 127)).rounded())
    }
}
