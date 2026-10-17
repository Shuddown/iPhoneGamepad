import Foundation
import CoreGraphics

enum GamepadControl: String, CaseIterable {
    case leftStick, rightStick, dpad
    case a, b, x, y, l1, r1, l2, r2, l3, r3, select, start, home

    var buttonNumber: Int? {
        switch self {
        case .a: 1
        case .b: 2
        case .x: 3
        case .y: 4
        case .l1: 5
        case .r1: 6
        case .select: 9
        case .start: 10
        case .l3: 11
        case .r3: 12
        case .home: 13
        default: nil
        }
    }

    var label: String {
        switch self {
        case .leftStick: "Left stick"
        case .rightStick: "Right stick"
        case .dpad: "Directional pad"
        case .select: "Select"
        case .start: "Start"
        case .home: "Home"
        default: rawValue.uppercased()
        }
    }

    var isFaceButton: Bool { [.a, .b, .x, .y].contains(self) }
}

/// Moonlight-style outer D-pad/face diamond and inner, lower thumbsticks.
/// Coordinates are calculated inside the safe area, including the home indicator.
struct GamepadLayout {
    var frames: [GamepadControl: CGRect] = [:]
    let bounds: CGRect

    init(bounds: CGRect) {
        self.bounds = bounds
        let w = bounds.width
        let h = bounds.height
        let ox = bounds.minX
        let oy = bounds.minY
        let stick = min(132, max(100, h * 0.36))
        let pad = min(124, max(100, h * 0.34))
        let face = min(56, max(44, h * 0.145))
        let spacing = face * 0.94
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: ox + x - width / 2, y: oy + y - height / 2, width: width, height: height)
        }
        frames[.leftStick] = rect(w * 0.33, h * 0.75, stick, stick)
        frames[.rightStick] = rect(w * 0.67, h * 0.75, stick, stick)
        frames[.dpad] = rect(w * 0.115, h * 0.53, pad, pad)
        let fx = w * 0.875
        let fy = h * 0.49
        frames[.a] = rect(fx, fy + spacing, face, face)
        frames[.b] = rect(fx + spacing, fy, face, face)
        frames[.x] = rect(fx - spacing, fy, face, face)
        frames[.y] = rect(fx, fy - spacing, face, face)
        let shoulder = min(100, max(72, w * 0.12))
        frames[.l2] = rect(shoulder * 0.5 + 8, 73, shoulder, 44)
        frames[.l1] = rect(shoulder * 1.5 + 20, 73, shoulder, 44)
        frames[.r1] = rect(w - shoulder * 1.5 - 20, 73, shoulder, 44)
        frames[.r2] = rect(w - shoulder * 0.5 - 8, 73, shoulder, 44)
        frames[.l3] = rect(w * 0.115, h * 0.88, 58, 44)
        frames[.r3] = rect(w * 0.875, h * 0.88, 58, 44)
        frames[.select] = rect(w * 0.5 - 39, h * 0.34, 60, 44)
        frames[.start] = rect(w * 0.5 + 39, h * 0.34, 60, 44)
        frames[.home] = rect(w * 0.5, h * 0.56, 46, 46)
    }

    func control(at point: CGPoint) -> GamepadControl? {
        // Buttons win at borders; stick hit areas do not steal a neighboring key.
        let ordered = GamepadControl.allCases.sorted { (frames[$0]?.width ?? 0) < (frames[$1]?.width ?? 0) }
        return ordered.first { frames[$0]?.insetBy(dx: -4, dy: -4).contains(point) == true }
    }
}

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
                result.leftX = Self.axis(contact.x); result.leftY = Self.axis(contact.y)
            case .rightStick:
                result.rightX = Self.axis(contact.x); result.rightY = Self.axis(contact.y)
            case .l2: result.leftTrigger = max(result.leftTrigger, UInt8((max(0, min(1, contact.pressure)) * 255).rounded()))
            case .r2: result.rightTrigger = max(result.rightTrigger, UInt8((max(0, min(1, contact.pressure)) * 255).rounded()))
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

    private static func axis(_ value: Double) -> Int8 {
        let clamped = max(-1, min(1, value))
        let magnitude = abs(clamped)
        guard magnitude > 0.10 else { return 0 }
        let adjusted = (magnitude - 0.10) / 0.90
        return Int8((adjusted * (clamped < 0 ? -127 : 127)).rounded())
    }
}
