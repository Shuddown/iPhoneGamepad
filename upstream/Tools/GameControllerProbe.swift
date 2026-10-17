import AppKit
import GameController

// A foreground app exercises the same controller API as native Mac games.
setbuf(stdout, nil)
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 360),
                      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
window.title = "iPhone Gamepad — Game Controller Test"
let label = NSTextField(wrappingLabelWithString: "Checking Game Controller devices…")
label.frame = NSRect(x: 20, y: 20, width: 660, height: 320)
label.autoresizingMask = [.width, .height]
label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
window.contentView?.addSubview(label)
window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
GCController.shouldMonitorBackgroundEvents = true
var retained: [GCController] = []
var lastCount = -1

func show(_ controller: GCController) {
    let profile = controller.physicalInputProfile
    let buttons = profile.buttons.filter { $0.value.isPressed }.map(\.key).sorted().joined(separator: ", ")
    let axes = profile.axes.map { "\($0.key): \(String(format: "%.2f", $0.value.value))" }.sorted().joined(separator: "\n")
    label.stringValue = "\(controller.vendorName ?? "Unknown controller")\nCategory: \(controller.productCategory)\nExtended gamepad: \(controller.extendedGamepad != nil)\nPressed: \(buttons)\n\(axes)"
}

func refresh() {
    let controllers = GCController.controllers()
    if controllers.count != lastCount {
        lastCount = controllers.count
        print("GCController count: \(controllers.count)")
    }
    if controllers.isEmpty {
        label.stringValue = "No controller exposed through GCController yet.\n\nA device may still work through generic HID/SDL.\nUse GamepadMonitor to check that separately."
        retained.removeAll()
    }
    for controller in controllers where !retained.contains(where: { $0 === controller }) {
        retained.append(controller)
        print("GCController connected: \(controller.vendorName ?? "unknown"), category=\(controller.productCategory), extendedGamepad=\(controller.extendedGamepad != nil)")
        show(controller)
        controller.physicalInputProfile.valueDidChangeHandler = { _, _ in
            show(controller)
            print("GC input changed")
        }
        controller.extendedGamepad?.valueChangedHandler = { gamepad, _ in
            show(controller)
            print("GC extended input: A=\(gamepad.buttonA.value) B=\(gamepad.buttonB.value) left=(\(gamepad.leftThumbstick.xAxis.value),\(gamepad.leftThumbstick.yAxis.value)) right=(\(gamepad.rightThumbstick.xAxis.value),\(gamepad.rightThumbstick.yAxis.value)) triggers=(\(gamepad.leftTrigger.value),\(gamepad.rightTrigger.value))")
        }
    }
}

let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in refresh() }
app.run()
