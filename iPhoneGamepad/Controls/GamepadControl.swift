import CoreGraphics
import Foundation

enum GamepadControl: String, CaseIterable, Codable {
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
