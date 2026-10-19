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


## Build 37: symmetry and full-surface forgiving input

- Captured the running physical iPhone before and after the change. The updated
  [gamepad screenshot](gamepad.png) shows shoulder pairs centered above their
  D-pad/face groups, shared horizontal centers for L3/R3, matching group heights,
  and mirrored left/right columns. Existing custom placements remain intact.
- Core checks pass for mirror symmetry, shoulder-pair alignment, unclipped
  controls and stick/button separation at three landscape sizes.
- Forgiving checks cover a grid across the entire touch surface, including
  outside the safe layout bounds, above L2/R2, below L3/R3, and side margins.
  They also verify that distant snapped button touches remain pressed and
  Home still requires a direct hit. Standard mode retains its original targets.
- Signed Debug build, core checks, Swift formatting and whitespace checks pass.
  Build 37 was installed and launched on the connected iPhone. The actual screen
  was captured and inspected; human touch accuracy still needs hands-on use.
