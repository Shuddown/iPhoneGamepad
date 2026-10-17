# iPhone Gamepad extension

This prototype adds a touchscreen gamepad to darwin-bt-remote. It uses
CoreBluetooth's peripheral role and the upstream full-length Bluetooth UUID
workaround. There is no jailbreak, Mac receiving service, or Mac virtual HID
device. The iPhone is the Bluetooth HID peripheral.

## Physical-device validation — October 17, 2026

- iPhone 15: iOS 27.0.1 (24A446), Developer Mode enabled.
- Mac: macOS 27.0.1 (26A434).
- Compiler: Xcode 27.0 (27A266a), Swift 6 project configuration.
- Baseline upstream iOS build: passed before modifications.
- Development signing, installation over USB, and device launch: passed.
- Bluetooth permission, HID service registration, advertising, and host subscription: passed on the physical iPhone.
- Raw macOS HID input: buttons, D-pad, four stick axes, and both analog triggers received; button/trigger releases and stick recentering observed.
- Final Xbox BLE profile: `GCController` discovers an Xbox-compatible extended gamepad and receives live input, including A/B, sticks, and analog triggers.
- User confirmed the Mac's native test window updates when operating the phone's controls.
- Reconnection using the iPhone app's setup flow was exercised again after reinstall/relaunch. The native API received the controlled trigger pair `(1.0, 0.5014663)`.
- No individual commercial game, App Store submission, other phone, or older iOS version was tested. This is direct evidence for this device/OS pair, not a guarantee for all iOS releases.

The generic 9-byte HID profile worked through IOHIDManager but did not deliver
input through Game Controller. Moving its collection first caused an MFi-style
controller object to appear, but its values stayed at zero. A gamepad-only
generic GATT service also failed to deliver native controller input. The final
implementation therefore uses the Xbox Series X BLE report format and its
VID/PID compatibility identity (`045E:0B13`, USB ID source). The product name can
still appear as the iPhone's system name in macOS Bluetooth settings. The phone
is not Microsoft hardware, and the compatibility identity should be reviewed
before distributing a product.

Selected actual native-API output is in [Tests/DEVICE-VALIDATION.log](Tests/DEVICE-VALIDATION.log).

## Use

1. Open **iPhone Gamepad** on the phone and allow Bluetooth access.
2. Use **Setup → Devices** inside the iPhone app to connect to the Mac and accept
   any pairing confirmation. This is the route tested here. The iPhone did not
   appear in the Mac's normal Bluetooth device list; that list is not required.
   If rebuilding changes the descriptor and input stops updating, reconnect
   using the in-app setup flow and restart the controller test app. macOS may
   retain stale identity/descriptor metadata during development.
3. Open the **Gamepad** tab. The status should say **Host subscribed to gamepad**.
4. Use both sticks, A/B/X/Y, L1/R1, L2/R2, D-pad, Select/Start, and L3/R3.
   L2/R2 are analog bars: touch/drag along a bar to vary its value; release to zero.
5. Keep the app foreground. Opening another screen, leaving the app, or pressing
   **Release all controls** sends a neutral report. The gamepad screen prevents
   automatic screen sleep while visible.

The app sends full absolute states, preserving other held inputs when one
control changes. Gesture cancellation releases controls. Backpressure stores
the latest state separately for each characteristic, preventing another report
from replacing a pending gamepad release. Extremely short press/release pairs
can still be coalesced under congestion; no latency bound is claimed.

Rumble commands are accepted but not rendered. Gyroscope aiming is not
implemented. The default build is gamepad-only; upstream keyboard and mouse
sources are retained for comparison. Do not enable the composite service while
using the Xbox report map; its report IDs overlap with the legacy profiles.

## Build and install

Requirements: Xcode, XcodeGen, a paired physical iPhone with Developer Mode,
and an Apple development signing identity. A free account allows at most three
development apps and has time-limited provisioning.

```sh
xcodegen generate
xcodebuild -project BTRemote.xcodeproj -scheme BTRemote \
  -configuration Debug -destination 'id=YOUR_IPHONE_UDID' \
  -derivedDataPath .build/device -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  PRODUCT_BUNDLE_IDENTIFIER=com.example.iphonegamepad build
xcrun devicectl device install app --device YOUR_IPHONE_UDID \
  .build/device/Build/Products/Debug-iphoneos/BTRemote.app
```

Keep a unique bundle identifier so this prototype does not replace the upstream
app. In Xcode, select your connected iPhone and your development team to run it.

## Reproduce checks

```sh
bash Tools/verify-gamepad.sh
.build/validation/GamepadMonitor
open .build/validation/GameControllerProbe.app
```

The script tests descriptor bit layout, neutral values, signed ranges, Xbox
button mapping and trigger conversion, and report buffering. It also builds
two Mac tools:

- **GamepadMonitor** reads HID input and prints whether Game Controller supports
  the device. Composite keyboard/mouse profiles may need Input Monitoring
  permission; the final gamepad-only profile avoids those usages.
- **GameControllerProbe.app** uses the actual Game Controller API to display live
  button/axis values. A listed controller alone is not proof of working input.

For repeatable transport diagnostics in a Debug build, launch over USB:

```sh
xcrun devicectl device process launch --device YOUR_IPHONE_UDID \
  --console --terminate-existing com.example.iphonegamepad -- \
  -BTRemote.developerMode YES -BTRemote.hasSeenWelcome YES --gamepad-probe
```

This explicit flag waits for a host, sends a short A/stick/trigger/D-pad sequence,
then releases all controls. Ordinary launches and Release builds do not run it.

## Source and licenses

- Upstream: jqssun/darwin-bt-remote at `ad7a76ce6132254fbd6085af87cea8d10aa8a82d`, AGPL-3.0.
- Xbox descriptor: lemmingDev/ESP32-BLE-Gamepad's `BleXInputDescriptors.h`,
  revision `65d517864f86dc55b161f8b32a1650e0eb3c25aa`, which credits
  Mystfit/ESP32-BLE-CompositeHID. Original MIT notices are in
  [ThirdParty](ThirdParty).
- `GamepadReport.swift` retains the original generic report and implements
  conversion to the Xbox layout. `XboxBLEProfile.swift` holds the compatible
  input/output descriptor. `HIDProfile.swift` selects the default profile.

This still depends on undocumented iOS service-publication behavior. Successful
testing on iOS 27.0.1 establishes current feasibility; App Store eligibility and
future OS behavior remain unverified.
