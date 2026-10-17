import SwiftUI
import UIKit

struct GamepadSurface: UIViewRepresentable {
    var resetToken: Int
    var haptics: Bool
    var onReport: (GamepadReport) -> Void

    func makeUIView(context: Context) -> GamepadSurfaceView {
        let view = GamepadSurfaceView()
        view.onReport = onReport
        return view
    }

    func updateUIView(_ view: GamepadSurfaceView, context: Context) {
        view.onReport = onReport
        view.haptics = haptics
        if view.resetToken != resetToken {
            view.resetToken = resetToken
            view.releaseAll(emit: false)
        }
    }

    static func dismantleUIView(_ view: GamepadSurfaceView, coordinator: ()) { view.releaseAll() }
}

final class GamepadSurfaceView: UIView {
    var onReport: (GamepadReport) -> Void = { _ in }
    var haptics = true
    var resetToken = 0
    private var input = GamepadInputState()
    private var layout = GamepadLayout(bounds: .zero)
    private var nextID = 0
    private var owners: [ObjectIdentifier: (id: Int, control: GamepadControl, origin: CGPoint)] = [:]
    private var lastSize = CGSize.zero
    private let feedback = UIImpactFeedbackGenerator(style: .soft)
    private let ink = UIColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1)
    private let accent = UIColor(red: 0.49, green: 0.85, blue: 0.72, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isOpaque = true
        accessibilityIdentifier = "gamepad.surface"
        backgroundColor = UIColor(red: 0.055, green: 0.065, blue: 0.09, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastSize {
            lastSize = bounds.size
            releaseAll()
        }
        let safeBounds = bounds.inset(by: safeAreaInsets).insetBy(dx: 12, dy: 10)
        layout = GamepadLayout(bounds: safeBounds)
        rebuildAccessibility()
        setNeedsDisplay()
    }

    func releaseAll(emit: Bool = true) {
        owners.removeAll()
        input.reset()
        if emit { onReport(.zero) }
        setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            guard let control = layout.control(at: point) else { continue }
            if [.leftStick, .rightStick, .dpad].contains(control), owners.values.contains(where: { $0.control == control }) { continue }
            nextID += 1
            owners[ObjectIdentifier(touch)] = (nextID, control, point)
            update(touch)
            if haptics { feedback.impactOccurred(intensity: 0.6) }
        }
        publish()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach(update)
        publish()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { end(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { end(touches) }

    private func end(_ touches: Set<UITouch>) {
        for touch in touches {
            if let owner = owners.removeValue(forKey: ObjectIdentifier(touch)) { input.remove(owner.id) }
        }
        publish()
    }

    private func update(_ touch: UITouch) {
        let key = ObjectIdentifier(touch)
        guard var owner = owners[key], let frame = layout.frames[owner.control] else { return }
        let point = touch.location(in: self)
        if owner.control.isFaceButton, let next = layout.control(at: point), next.isFaceButton {
            owner.control = next
            owners[key] = owner
        }
        var contact = GamepadContact(control: owner.control)
        switch owner.control {
        case .leftStick, .rightStick:
            let travel = frame.width * 0.32
            let x = (point.x - frame.midX) / travel
            let y = (point.y - frame.midY) / travel
            let magnitude = max(1, hypot(x, y))
            contact.x = x / magnitude; contact.y = y / magnitude
        case .dpad:
            contact.x = (point.x - frame.midX) / (frame.width / 2)
            contact.y = (point.y - frame.midY) / (frame.height / 2)
        case .l2, .r2:
            // Full press at touch-down. Pull down to feather the analog trigger.
            contact.pressure = max(0, min(1, 1 - (point.y - owner.origin.y) / 110))
        default:
            guard layout.frames[owner.control]?.insetBy(dx: -18, dy: -18).contains(point) == true else {
                input.remove(owner.id)
                return
            }
        }
        input.set(contact, for: owner.id)
    }

    private func publish() {
        onReport(input.report)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        backgroundColor?.setFill()
        context.fill(bounds)
        // Restrained grip wells keep groups readable without looking like a form.
        for control in [GamepadControl.leftStick, .rightStick] {
            if let frame = layout.frames[control] {
                UIColor.white.withAlphaComponent(0.018).setFill()
                UIBezierPath(ovalIn: frame.insetBy(dx: -26, dy: -26)).fill()
            }
        }
        for control in GamepadControl.allCases {
            guard let frame = layout.frames[control] else { continue }
            switch control {
            case .leftStick, .rightStick: drawStick(control, in: frame)
            case .dpad: drawDpad(in: frame)
            default: drawButton(control, in: frame)
            }
        }
    }

    private func drawStick(_ control: GamepadControl, in frame: CGRect) {
        let report = input.report
        let x = Double(control == .leftStick ? report.leftX : report.rightX) / 127
        let y = Double(control == .leftStick ? report.leftY : report.rightY) / 127
        let active = input.contacts.values.contains { $0.control == control }
        let rim = UIBezierPath(ovalIn: frame)
        ink.setFill(); rim.fill()
        (active ? accent.withAlphaComponent(0.65) : UIColor.white.withAlphaComponent(0.14)).setStroke()
        rim.lineWidth = 1.5; rim.stroke()
        let inner = frame.insetBy(dx: 11, dy: 11)
        UIColor.white.withAlphaComponent(0.035).setStroke()
        UIBezierPath(ovalIn: inner).stroke()
        let travel = frame.width * 0.28
        let knob = CGRect(x: frame.midX + x * travel - frame.width * 0.22,
                          y: frame.midY + y * travel - frame.height * 0.22,
                          width: frame.width * 0.44, height: frame.height * 0.44)
        let cap = UIBezierPath(ovalIn: knob)
        UIColor(red: 0.21, green: 0.24, blue: 0.29, alpha: 1).setFill(); cap.fill()
        UIColor.white.withAlphaComponent(active ? 0.32 : 0.18).setStroke(); cap.stroke()
        drawText(control == .leftStick ? "L" : "R", in: knob, font: .systemFont(ofSize: 15, weight: .medium), color: .white.withAlphaComponent(0.55))
    }

    private func drawDpad(in frame: CGRect) {
        let third = frame.width / 3
        let path = UIBezierPath()
        let points = [CGPoint(x: third, y: 0), CGPoint(x: third * 2, y: 0),
                      CGPoint(x: third * 2, y: third), CGPoint(x: third * 3, y: third),
                      CGPoint(x: third * 3, y: third * 2), CGPoint(x: third * 2, y: third * 2),
                      CGPoint(x: third * 2, y: third * 3), CGPoint(x: third, y: third * 3),
                      CGPoint(x: third, y: third * 2), CGPoint(x: 0, y: third * 2),
                      CGPoint(x: 0, y: third), CGPoint(x: third, y: third)]
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: point.x + frame.minX, y: point.y + frame.minY)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        ink.setFill(); path.fill()
        UIColor.white.withAlphaComponent(0.2).setStroke(); path.lineWidth = 1.5; path.stroke()
        let hat = input.report.hat
        for (index, symbol, dx, dy) in [(0, "▲", 1, 0), (2, "▶", 2, 1), (4, "▼", 1, 2), (6, "◀", 0, 1)] {
            let active = hat < 8 && ((Int(hat) - index + 8) % 8 <= 1 || (index - Int(hat) + 8) % 8 <= 1)
            let cell = CGRect(x: frame.minX + CGFloat(dx) * third, y: frame.minY + CGFloat(dy) * third, width: third, height: third)
            drawText(symbol, in: cell, font: .systemFont(ofSize: 13, weight: .bold), color: active ? accent : .white.withAlphaComponent(0.5))
        }
    }

    private func drawButton(_ control: GamepadControl, in frame: CGRect) {
        let active = input.contacts.values.contains { $0.control == control }
        let color: UIColor
        switch control {
        case .a: color = accent
        case .b: color = UIColor(red: 0.98, green: 0.46, blue: 0.44, alpha: 1)
        case .x: color = UIColor(red: 0.40, green: 0.68, blue: 1, alpha: 1)
        case .y: color = UIColor(red: 0.98, green: 0.80, blue: 0.39, alpha: 1)
        default: color = .white.withAlphaComponent(0.7)
        }
        let path = control.isFaceButton || control == .home
            ? UIBezierPath(ovalIn: frame)
            : UIBezierPath(roundedRect: frame, cornerRadius: control == .l3 || control == .r3 ? 18 : 14)
        (active ? color.withAlphaComponent(0.22) : ink).setFill(); path.fill()
        (active ? color : UIColor.white.withAlphaComponent(0.16)).setStroke()
        path.lineWidth = active ? 2 : 1; path.stroke()
        if control == .l2 || control == .r2 {
            let value = Double(control == .l2 ? input.report.leftTrigger : input.report.rightTrigger) / 255
            if value > 0 {
                let meter = CGRect(x: frame.minX + 12, y: frame.maxY - 7, width: (frame.width - 24) * value, height: 2)
                accent.setFill(); UIBezierPath(roundedRect: meter, cornerRadius: 1).fill()
            }
        }
        let label: String
        switch control {
        case .select: label = "⧉"
        case .start: label = "☰"
        case .home: label = "⌂"
        default: label = control.label
        }
        let size: CGFloat = control.isFaceButton ? 23 : (control == .select || control == .start || control == .home ? 22 : 14)
        drawText(label, in: frame, font: .systemFont(ofSize: size, weight: .semibold), color: color)
    }

    private func drawText(_ text: String, in frame: CGRect, font: UIFont, color: UIColor) {
        let size = (text as NSString).size(withAttributes: [.font: font])
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: color])
    }

    private func rebuildAccessibility() {
        accessibilityElements = GamepadControl.allCases.compactMap { control -> UIAccessibilityElement? in
            guard let frame = layout.frames[control] else { return nil }
            let element = GamepadAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = control.label
            element.accessibilityIdentifier = "gamepad.\(control.rawValue)"
            element.accessibilityFrameInContainerSpace = frame
            element.accessibilityTraits = control.buttonNumber == nil ? .adjustable : .button
            element.activate = { [weak self] in self?.accessibilityPress(control) }
            return element
        }
    }

    private func accessibilityPress(_ control: GamepadControl) {
        nextID += 1
        let id = nextID
        input.set(GamepadContact(control: control, x: control == .dpad ? 1 : 0), for: id)
        publish()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.input.remove(id); self?.publish()
        }
    }
}

private final class GamepadAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return true }
}
