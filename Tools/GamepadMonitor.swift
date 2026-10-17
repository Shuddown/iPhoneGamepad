import Foundation
import GameController
import IOKit.hid

// Run as a native macOS command-line tool; no virtual device or input injection.
setbuf(stdout, nil)
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matches = [4, 5].map { usage in
    [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: usage]
}
IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
IOHIDManagerRegisterDeviceMatchingCallback(
    manager,
    { _, result, _, device in
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) ?? "unknown" as CFString
        print("HID gamepad/joystick attached: \(name), status=\(result)")
        print("GameController framework support: \(GCController.supportsHIDDevice(device))")
    }, nil)
IOHIDManagerRegisterDeviceRemovalCallback(
    manager,
    { _, _, _, _ in
        print("HID gamepad/joystick removed")
    }, nil)
IOHIDManagerRegisterInputValueCallback(
    manager,
    { _, result, _, value in
        guard result == kIOReturnSuccess else { return }
        let element = IOHIDValueGetElement(value)
        print(
            "input page=\(IOHIDElementGetUsagePage(element)) usage=\(IOHIDElementGetUsage(element)) value=\(IOHIDValueGetIntegerValue(value))"
        )
    }, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("HID manager open status: \(status). Watching gamepads for 120 seconds…")
GCController.shouldMonitorBackgroundEvents = true
func monitor(_ controller: GCController) {
    print(
        "GCController connected: \(controller.vendorName ?? "unknown"), category=\(controller.productCategory), extendedGamepad=\(controller.extendedGamepad != nil)"
    )
    let profile = controller.physicalInputProfile
    print("GC buttons: \(profile.buttons.keys.sorted()); axes: \(profile.axes.keys.sorted())")
    profile.valueDidChangeHandler = { profile, element in
        for (name, button) in profile.buttons where button === element {
            print("GC button \(name)=\(button.value)")
        }
        for (name, axis) in profile.axes where axis === element {
            print("GC axis \(name)=\(axis.value)")
        }
        for (name, pad) in profile.dpads where pad === element {
            print("GC pad \(name)=(\(pad.xAxis.value),\(pad.yAxis.value))")
        }
    }
}
let observer = NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) {
    notification in
    guard let controller = notification.object as? GCController else { return }
    monitor(controller)
}
for controller in GCController.controllers() { monitor(controller) }
GCController.startWirelessControllerDiscovery(completionHandler: nil)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 120))
GCController.stopWirelessControllerDiscovery()
NotificationCenter.default.removeObserver(observer)
IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
