import CoreGraphics
import Foundation

/// Moonlight-style outer D-pad/face diamond and inner, lower thumbsticks.
/// Coordinates are calculated inside the safe area, including the home indicator.
struct GamepadLayout {
    var frames: [GamepadControl: CGRect] = [:]
    let bounds: CGRect

    init(bounds: CGRect, configuration: GamepadLayoutConfiguration = .init()) {
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
        for control in GamepadControl.allCases {
            guard let placement = configuration.controls[control.rawValue],
                let original = frames[control], bounds.width > 0, bounds.height > 0
            else { continue }
            let scale = placement.scale.isFinite ? min(2, max(0.6, placement.scale)) : 1
            let width = min(w, max(44, original.width * scale))
            let height = min(max(44, h - 48), max(44, original.height * scale))
            let x = placement.x.isFinite ? placement.x : 0.5
            let y = placement.y.isFinite ? placement.y : 0.5
            let cx = min(bounds.maxX - width / 2, max(ox + width / 2, ox + x * w))
            let cy = min(bounds.maxY - height / 2, max(oy + 48 + height / 2, oy + y * h))
            frames[control] = CGRect(
                x: max(ox, min(bounds.maxX - width, cx - width / 2)),
                y: max(oy + 48, min(bounds.maxY - height, cy - height / 2)),
                width: width, height: height)
        }
    }

    func control(at point: CGPoint) -> GamepadControl? {
        // Buttons win at borders; stick hit areas do not steal a neighboring key.
        let ordered = GamepadControl.allCases.sorted { (frames[$0]?.width ?? 0) < (frames[$1]?.width ?? 0) }
        return ordered.first { frames[$0]?.insetBy(dx: -4, dy: -4).contains(point) == true }
    }

    func control(at point: CGPoint, forgiving: Bool) -> GamepadControl? {
        if let direct = control(at: point) { return direct }
        guard forgiving, bounds.contains(point), point.y >= bounds.minY + 48 else { return nil }
        // Misses around menu controls must not be redirected to a neighboring stick.
        let menuKeys: [GamepadControl] = [.home, .start, .select]
        guard !menuKeys.contains(where: { frames[$0]?.insetBy(dx: -24, dy: -24).contains(point) == true }) else {
            return nil
        }
        // Expand only gameplay controls. Pause/menu keys always require a direct hit.
        let candidates = GamepadControl.allCases.filter { ![.home, .start, .select].contains($0) }
        let nearest = candidates.min { distance(to: $0, from: point) < distance(to: $1, from: point) }
        guard let nearest, distance(to: nearest, from: point) <= 24 else { return nil }
        return nearest
    }

    func distance(to control: GamepadControl, from point: CGPoint) -> CGFloat {
        guard let frame = frames[control] else { return .infinity }
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return hypot(dx, dy)
    }
}
