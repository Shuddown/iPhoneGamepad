import CoreGraphics
import Foundation

/// Moonlight-style outer D-pad/face diamond and inner, lower thumbsticks.
/// Coordinates are calculated inside the safe area, including the home indicator.
struct GamepadLayout {
    var frames: [GamepadControl: CGRect] = [:]
    let bounds: CGRect
    let touchBounds: CGRect

    init(bounds: CGRect, configuration: GamepadLayoutConfiguration = .init(), touchBounds: CGRect? = nil) {
        self.bounds = bounds
        self.touchBounds = touchBounds ?? bounds
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
        frames[.leftStick] = rect(w * 0.33, h * 0.77, stick, stick)
        frames[.rightStick] = rect(w * 0.67, h * 0.77, stick, stick)
        let shoulder = min(100, max(72, w * 0.12))
        // Center each shoulder pair on the same column as its D-pad/face diamond.
        let leftColumn = max(w * 0.135, shoulder + 10)
        let rightColumn = w - leftColumn
        let groupY = h * 0.51
        frames[.dpad] = rect(leftColumn, groupY, pad, pad)
        let fx = rightColumn
        let fy = groupY
        frames[.a] = rect(fx, fy + spacing, face, face)
        frames[.b] = rect(fx + spacing, fy, face, face)
        frames[.x] = rect(fx - spacing, fy, face, face)
        frames[.y] = rect(fx, fy - spacing, face, face)
        let shoulderOffset = (shoulder + 12) / 2
        frames[.l2] = rect(leftColumn - shoulderOffset, 73, shoulder, 44)
        frames[.l1] = rect(leftColumn + shoulderOffset, 73, shoulder, 44)
        frames[.r1] = rect(rightColumn - shoulderOffset, 73, shoulder, 44)
        frames[.r2] = rect(rightColumn + shoulderOffset, 73, shoulder, 44)
        frames[.l3] = rect(leftColumn, h * 0.88, 58, 44)
        frames[.r3] = rect(rightColumn, h * 0.88, 58, 44)
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
        guard forgiving, touchBounds.contains(point) else { return nil }
        // Partition all available background space between gameplay controls.
        // Toolbar buttons intercept their own touches; menu keys require a direct hit.
        let candidates = GamepadControl.allCases.filter { ![.home, .start, .select].contains($0) }
        return candidates.min { distance(to: $0, from: point) < distance(to: $1, from: point) }
    }

    func isButtonActive(_ control: GamepadControl, at point: CGPoint, forgiving: Bool) -> Bool {
        let menuKey = [GamepadControl.home, .start, .select].contains(control)
        guard forgiving && !menuKey else {
            return frames[control]?.insetBy(dx: -18, dy: -18).contains(point) == true
        }
        guard touchBounds.contains(point), let target = self.control(at: point, forgiving: true),
            ![.home, .start, .select].contains(target)
        else { return false }
        // Keep the same enlarged region during a hold, with room for thumb jitter.
        return distance(to: control, from: point) <= distance(to: target, from: point) + 8
    }

    func distance(to control: GamepadControl, from point: CGPoint) -> CGFloat {
        guard let frame = frames[control] else { return .infinity }
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return hypot(dx, dy)
    }
}
