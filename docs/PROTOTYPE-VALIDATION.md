# Baseline validation

The emulator-tested starting point is preserved in commit `a6cf028`.

- Physical iPhone 15: iOS 27.0.1 (24A446), Developer Mode enabled.
- Mac: macOS 27.0.1 (26A434).
- Xcode 27.0 (27A266a).
- USB development installation and launch passed.
- Bluetooth HID service registration, advertising, and subscription passed.
- macOS received button presses/releases, both sticks, D-pad, and analog triggers.
- Generic HID reports worked through IOHIDManager but not the native controller API.
- The final Xbox BLE compatibility profile delivered live `GCController` events.
- The controlled trigger test produced `(1.0, 0.5014663)` through the native API.
- The user confirmed emulator gameplay works before the layout redesign.
- The working connection route is the in-app device scanner. Normal Mac Bluetooth
  settings did not list the iPhone; that menu is not required.

[Selected device-test output](../Tests/DEVICE-VALIDATION.log) is preserved.
The current controller layout and build commands are in the root README.
Individual games, App Store submission, and other iOS versions are not covered
by these results. Old source and full prototype notes remain in the baseline
commit; they are not part of the current gamepad-only application.
