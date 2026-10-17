# iPhone Gamepad

A dedicated landscape Bluetooth gamepad for iPhone. Connect to your Mac from
inside the app, then use the phone as an Xbox-compatible controller in games
and emulators. No desktop receiver or virtual controller driver is needed.

The emulator-tested starting point is preserved in commit `a6cf028`.

## Controls

- D-pad and A/B/X/Y at the outer edges; two lower, inward thumbsticks.
- Shoulder buttons across the top, with Select, Start, Home, L3, and R3.
- L2/R2 press fully when touched; drag down to feather their analog values.
- A single sliding D-pad touch supports all eight directions.
- Simultaneous touches preserve held buttons and both sticks. Lifting,
  cancellation, opening settings, or leaving the app releases the controls.
- All controls respect the landscape safe area and have at least 44-point targets.

Tap **Connect** at the top to scan for your Mac, connect, and adjust touch
feedback. The iPhone does not have to appear in the Mac's normal Bluetooth list.
The app prevents automatic screen sleep while playing.

The design follows the on-screen control arrangements in Moonlight iOS and
PPSSPP. See [layout references](docs/LAYOUT-REFERENCES.md).

## Build

Requires Xcode and XcodeGen. The app targets iOS 16 or later; physical-device
Bluetooth testing has been performed on an iPhone 15 with iOS 27.0.1 and a Mac
with macOS 27.0.1.

```sh
xcodegen generate
open iPhoneGamepad.xcodeproj
```

Select your development team and connected iPhone in Xcode. The bundle identifier
is unchanged from the tested prototype (`com.shudhesh.iphonegamepad`), preserving
its installation and permissions. For a command-line device build:

```sh
xcodebuild -project iPhoneGamepad.xcodeproj -scheme iPhoneGamepad \
  -configuration Debug -destination 'id=YOUR_IPHONE_UDID' \
  -derivedDataPath .build/device -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID build
xcrun devicectl device install app --device YOUR_IPHONE_UDID \
  .build/device/Build/Products/Debug-iphoneos/iPhoneGamepad.app
```

## Verify

```sh
bash Tools/verify-gamepad.sh
.build/validation/GamepadMonitor
open .build/validation/GameControllerProbe.app
```

Tests cover the Xbox BLE packet format, stick ranges, trigger scaling, button
mapping, touch ownership/release, D-pad diagonals, deadzone behavior, safe-area
layout sizes, and report buffering. The two Mac tools inspect actual HID and
Game Controller input, respectively. The tests do not substitute for testing an
individual game or emulator.

Only gamepad HID collections and characteristics are published. Keyboard,
mouse, trackpad, media keys, desktop hosting, and Bluetooth Classic code have
been removed. Rumble output is accepted for protocol compatibility but is not
rendered; gyro aiming is not implemented.

The transport depends on undocumented iOS HID service-publication behavior and
uses an Xbox BLE compatibility identity to select macOS's controller driver.
Successful testing on current hardware is not a guarantee of future OS or App
Store compatibility. [Prototype test evidence](docs/PROTOTYPE-VALIDATION.md) is
retained separately from the current product instructions.

## License and attribution

AGPL-3.0; see [LICENSE](LICENSE). Upstream provenance and MIT notices for the BLE
report descriptor are preserved in [ThirdParty](ThirdParty).
