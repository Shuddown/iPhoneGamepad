# Build 6 validation

October 17, 2026. Baseline commit: `5fe6af8`.

- `bash Tools/verify-gamepad.sh`: PASS. Includes existing Xbox report/descriptor,
  multi-touch ownership/release, D-pad, deadzone, safe-area, and buffering checks.
  New checks cover layout JSON round trips, UserDefaults persistence and malformed
  data fallback, clamping oversized/offscreen edits at two screen sizes, minimum
  target dimensions, bounded snapping and menu exclusion, and floating stick
  neutral landing/full travel versus Standard mode's fixed center.
- Signed Debug device build: PASS with Xcode 27 for the connected iPhone 15.
- Unsigned Release build for generic iOS device: PASS.
- Installed build 6 over the existing app via USB and launched successfully on
  the physical iPhone (iOS 27.0.1).
- Opened the actual editor using the DEBUG-only `--layout-editor` launch argument,
  captured its screen, and inspected the landscape safe area, toolbar, labels,
  and selection outline. See [editor screenshot](layout-editor.png).
- Launched normally after final installation so the user can test both modes.
- A passive Mac monitor detected the installed build as `category=Xbox One`,
  `extendedGamepad=true`, with HID framework support true. This confirms native
  discovery. During the user's interaction the same monitor recorded changing
  native Game Controller button, trigger, stick, and D-pad values, including
  releases. This does not establish which mode was active or validate subjective
  accuracy.
- Bluetooth profile and transport sources have no changes from the committed
  emulator-tested redesign.
- `git diff --check`: PASS.

The new automated checks validate hit resolution and stick math, not actual
human thumb accuracy. Physical move/resize gestures, Save/Cancel interactions,
rapid combinations, and the subjective feel of forgiving input in an emulator
still require the user's hands-on check. No such result is claimed here.
