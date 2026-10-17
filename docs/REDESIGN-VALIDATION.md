# Gamepad-only redesign validation

October 17, 2026 — iPhone 15, iOS 27.0.1; Mac, macOS 27.0.1; Xcode 27.0.

- Baseline committed before any redesign: `a6cf028`.
- Debug device build, development signing, USB installation and launch: passed.
- Release iOS build with signing disabled: passed.
- Xbox BLE descriptor compared byte-for-byte with `a6cf028`: identical.
- HID input/output report IDs and PnP compatibility identity: retained.
- Report tests: neutral state, signed stick conversion, trigger scaling and button mapping passed.
- Touch tests: simultaneous sticks/buttons, two fingers on one button, individual lift,
  cancellation/reset, eight-way D-pad and gradual deadzone passed.
- Layout tests: all controls within safe bounds and targets at least 44 points on
  representative SE, iPhone 15 and Pro Max landscape sizes. Stick/D-pad and stick/face
  hit rectangles do not overlap at those sizes.
- Screenshot captured and visually inspected on the physical iPhone:
  [landscape.png](landscape.png). Both landscape orientations are supported.
- Mac monitor detected the installed application as an Xbox-compatible
  `GCController` with an extended gamepad profile after the cleanup.
- The baseline was confirmed by the user to work in an emulator. The redesigned
  screen has been offered for another emulator check; this document does not
  claim that user confirmation has already been received.

Removed application code/resources include the keyboard, mouse/trackpad, media
controls, Bluetooth Classic backend, Mac-host app target, obsolete strings and
localizations, remote UI, publishing metadata, old screenshots, and original icon.
The compatibility BLE transport and the in-app scan/connect flow are retained.

The only original preference key retained in application code is an explicit
one-time advertised-name migration. Original copyright/license attribution is
kept in ThirdParty and LICENSE.
