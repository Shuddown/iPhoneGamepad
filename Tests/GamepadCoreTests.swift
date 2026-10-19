import CoreGraphics
import Foundation

@main
enum GamepadCoreTests {
    @MainActor
    static func main() {
        let owner = UUID()
        let other = UUID()
        precondition(GamepadHIDProfile.reportMap(for: owner, owner: owner) == XboxBLEProfile.descriptor)
        let vendor = GamepadHIDProfile.reportMap(for: other, owner: owner)
        precondition(vendor != XboxBLEProfile.descriptor && reportBitCounts(vendor)["input:1"] == 128)
        let ownerService = GamepadHostService(hostID: owner)
        let otherService = GamepadHostService(hostID: other)
        let reconnected = GamepadHostService(hostID: owner)
        precondition(ownerService.contains(ownerService.input) && !ownerService.contains(otherService.input))
        precondition(
            !reconnected.contains(ownerService.input), "Delayed callbacks must not match a reconnected service")
        precondition(ownerService.reportMap.value == nil, "The report map must be resolved for the requesting host")
        var removalQueue = GamepadReportBuffer<String, Int>()
        removalQueue.enqueue(1, for: "removed")
        removalQueue.enqueue(2, for: "retained")
        removalQueue.removeValue(for: "removed")
        precondition(removalQueue.popFirst()?.1 == 2 && removalQueue.popFirst() == nil)

        precondition(
            GamepadHIDProfile.reportMapData.starts(with: Data([5, 1, 9, 5, 0xA1, 1])),
            "Game Pad must be the primary collection for GCController discovery")
        precondition(Array(GamepadReport.zero.data) == [0, 128, 0, 128, 0, 128, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0])
        var xbox = GamepadReport(leftX: -127, leftY: 127, leftTrigger: 255, rightTrigger: 128)
        xbox.setButton(3, pressed: true)  // X uses Xbox bit 3, not bit 2.
        xbox.setButton(11, pressed: true)  // Left stick click uses bit 13.
        xbox.hat = 7
        precondition(Array(xbox.data) == [1, 0, 255, 255, 0, 128, 0, 128, 255, 3, 1, 2, 8, 8, 32, 0])
        let xboxSizes = reportBitCounts(XboxBLEProfile.descriptor)
        precondition(
            xboxSizes["input:1"] == 128 && xboxSizes["output:3"] == 64,
            "Xbox BLE input/output characteristics must match the descriptor")
        precondition(GamepadReport.zero.data.count * 8 == xboxSizes["input:1"])

        // Independent fingers preserve another held button and both sticks.
        var input = GamepadInputState()
        input.set(GamepadContact(control: .a), for: 1)
        input.set(GamepadContact(control: .a), for: 2)
        input.set(GamepadContact(control: .leftStick, x: 1, y: -1), for: 3)
        input.set(GamepadContact(control: .rightStick, x: -1, y: 1), for: 4)
        input.remove(1)
        precondition(input.report.buttons == 1)
        precondition(input.report.leftX == 127 && input.report.rightX == -127)
        input.remove(2)
        precondition(input.report.buttons == 0 && input.report.leftY == -127)
        input.set(GamepadContact(control: .dpad, x: 1, y: -1), for: 5)
        precondition(input.report.hat == 1, "One sliding D-pad touch must support diagonals")
        input.set(GamepadContact(control: .l2, pressure: 0.5), for: 6)
        precondition(input.report.leftTrigger == 128)
        input.reset()
        precondition(input.report == .zero, "Cancellation or backgrounding releases all controls")
        input.set(GamepadContact(control: .leftStick, x: 0.05), for: 1)
        precondition(input.report.leftX == 0)
        input.set(GamepadContact(control: .leftStick, x: 0.11), for: 1)
        precondition(input.report.leftX > 0 && input.report.leftX < 5, "Deadzone boundary must be gradual")

        // Layout edits persist and stay usable after resizing the display.
        let editBounds = CGRect(x: 20, y: 10, width: 710, height: 352)
        var custom = GamepadLayoutConfiguration()
        custom.place(.a, center: CGPoint(x: -500, y: 9999), scale: 100, in: editBounds)
        custom.place(.leftStick, center: CGPoint(x: 250, y: 250), scale: 0.01, in: editBounds)
        let encoded = try! JSONEncoder().encode(custom)
        precondition(try! JSONDecoder().decode(GamepadLayoutConfiguration.self, from: encoded) == custom)
        for area in [editBounds, CGRect(x: 12, y: 10, width: 643, height: 355)] {
            let edited = GamepadLayout(bounds: area, configuration: custom)
            for control in [GamepadControl.a, .leftStick] {
                let frame = edited.frames[control]!
                precondition(
                    area.contains(frame) && frame.width >= 44 && frame.height >= 44, "Frame: \(frame), area: \(area)")
                precondition(frame.minY >= area.minY + 48, "Editor must preserve the toolbar space")
            }
        }
        let prefs = UserDefaults(suiteName: "GamepadLayoutTests")!
        prefs.removePersistentDomain(forName: "GamepadLayoutTests")
        custom.save(to: prefs)
        precondition(GamepadLayoutConfiguration.load(from: prefs) == custom)
        prefs.set(Data("invalid".utf8), forKey: "Gamepad.layout")
        precondition(GamepadLayoutConfiguration.load(from: prefs) == .init())
        prefs.removePersistentDomain(forName: "GamepadLayoutTests")

        // Forgiving hits cover the full surface beyond the safe layout bounds.
        let fullSurface = CGRect(x: 0, y: 0, width: 852, height: 393)
        let assisted = GamepadLayout(bounds: editBounds, touchBounds: fullSurface)
        let a = assisted.frames[.a]!
        let miss = CGPoint(x: a.midX, y: a.maxY + 12)
        precondition(assisted.control(at: miss, forgiving: false) == nil)
        precondition(assisted.control(at: miss, forgiving: true) == .a)
        let home = assisted.frames[.home]!
        precondition(assisted.control(at: CGPoint(x: home.maxX + 12, y: home.midY), forgiving: true) != .home)
        precondition(assisted.control(at: CGPoint(x: editBounds.midX, y: editBounds.maxY - 5), forgiving: true) != nil)
        for control in [GamepadControl.l2, .r2, .l3, .r3] {
            let frame = assisted.frames[control]!
            let point = CGPoint(x: frame.midX, y: control == .l2 || control == .r2 ? 1 : fullSurface.maxY - 1)
            precondition(assisted.control(at: point, forgiving: false) == nil)
            precondition(assisted.control(at: point, forgiving: true) == control)
            precondition(
                assisted.isButtonActive(control, at: point, forgiving: true), "A snapped miss must stay pressed")
        }
        for x in stride(from: CGFloat(1), to: fullSurface.maxX, by: 17) {
            for y in stride(from: CGFloat(1), to: fullSurface.maxY, by: 17) {
                precondition(assisted.control(at: CGPoint(x: x, y: y), forgiving: true) != nil)
            }
        }
        precondition(assisted.control(at: CGPoint(x: -1, y: 100), forgiving: true) == nil)
        precondition(assisted.control(at: CGPoint(x: home.midX, y: home.midY), forgiving: true) == .home)
        precondition(assisted.control(at: CGPoint(x: a.midX, y: a.midY), forgiving: true) == .a)

        let stickFrame = assisted.frames[.leftStick]!
        let landing = CGPoint(x: stickFrame.midX + 25, y: stickFrame.midY - 15)
        let neutralLanding = GamepadInputState.stickContact(
            .leftStick, point: landing, frame: stickFrame, origin: landing, floating: true)
        input.reset()
        input.set(neutralLanding, for: 1)
        precondition(
            input.report.leftX == 0 && input.report.leftY == 0,
            "Floating stick must start neutral wherever the thumb lands")
        let pushed = CGPoint(x: landing.x + stickFrame.width, y: landing.y)
        input.set(
            GamepadInputState.stickContact(
                .leftStick, point: pushed, frame: stickFrame, origin: landing, floating: true), for: 1)
        precondition(input.report.leftX == 127 && input.report.leftY == 0)
        input.set(
            GamepadInputState.stickContact(
                .leftStick, point: landing, frame: stickFrame, origin: landing, floating: false), for: 1)
        precondition(input.report.leftX > 0 && input.report.leftY < 0, "Standard mode must retain the fixed center")

        // Ensure standard phone sizes have no controls under the notch/home area.
        for size in [CGSize(width: 643, height: 355), CGSize(width: 710, height: 352), CGSize(width: 784, height: 389)]
        {
            let bounds = CGRect(origin: CGPoint(x: 12, y: 10), size: size)
            let layout = GamepadLayout(bounds: bounds)
            for control in GamepadControl.allCases {
                let frame = layout.frames[control]!
                precondition(bounds.contains(frame), "Clipped control \(control) at \(size)")
                precondition(frame.width >= 44 && frame.height >= 44)
            }
            let centerX = bounds.midX
            for (left, right) in [
                (GamepadControl.l1, GamepadControl.r1), (.l2, .r2), (.l3, .r3), (.leftStick, .rightStick),
            ] {
                precondition(abs(layout.frames[left]!.midX + layout.frames[right]!.midX - centerX * 2) < 0.001)
            }
            let padCenter = layout.frames[.dpad]!.midX
            let faceCenter = layout.frames[.a]!.midX
            precondition(abs((layout.frames[.l1]!.midX + layout.frames[.l2]!.midX) / 2 - padCenter) < 0.001)
            precondition(abs((layout.frames[.r1]!.midX + layout.frames[.r2]!.midX) / 2 - faceCenter) < 0.001)
            precondition(layout.frames[.l3]!.midX == padCenter && layout.frames[.r3]!.midX == faceCenter)
            precondition(abs(layout.frames[.dpad]!.midY - layout.frames[.x]!.midY) < 0.001)
            precondition(!layout.frames[.leftStick]!.intersects(layout.frames[.dpad]!))
            for control in [GamepadControl.a, .b, .x, .y] {
                precondition(!layout.frames[.rightStick]!.intersects(layout.frames[control]!))
            }
        }

        var pending = GamepadReportBuffer<Int, Data>()
        pending.enqueue(xbox.data, for: 1)
        pending.enqueue(Data([1]), for: 3)
        pending.enqueue(GamepadReport.zero.data, for: 1)
        let first = pending.popFirst()
        precondition(first?.0 == 1 && first?.1 == GamepadReport.zero.data)
        precondition(pending.popFirst()?.0 == 3)
        precondition(pending.popFirst() == nil)
        pending.enqueue(xbox.data, for: 1)
        pending.removeAll()
        precondition(pending.popFirst() == nil)
        print(
            "PASS: Xbox wire profile, multi-touch release, diagonals, deadzone, safe-area layouts, editor persistence/clamping, forgiving hits, floating sticks, and report buffering"
        )
    }

    private static func reportBitCounts(_ descriptor: Data) -> [String: Int] {
        let bytes = Array(descriptor)
        var offset = 0
        var size = 0
        var count = 0
        var id = 0
        var totals: [String: Int] = [:]
        while offset < bytes.count {
            let prefix = Int(bytes[offset])
            offset += 1
            let code = prefix & 3
            let length = code == 3 ? 4 : code
            precondition(offset + length <= bytes.count)
            var value = 0
            for index in 0..<length { value |= Int(bytes[offset + index]) << (8 * index) }
            offset += length
            switch prefix & 0xFC {
            case 0x74: size = value
            case 0x94: count = value
            case 0x84: id = value
            case 0x80: totals["input:\(id)", default: 0] += size * count
            case 0x90: totals["output:\(id)", default: 0] += size * count
            default: break
            }
        }
        return totals
    }
}
