# Contributing

Start with the README's build and connection instructions. A physical iPhone
and host are needed to validate Bluetooth behavior; UI builds and core tests
alone cannot establish it.

## Local checks

```sh
bash Tools/format-swift.sh
bash Tools/format-swift.sh --check
bash Tools/verify-gamepad.sh
xcodegen generate
xcodebuild -project iPhoneGamepad.xcodeproj -scheme iPhoneGamepad \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath .build/release \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Use Xcode's bundled `swift-format` with the checked-in configuration. Generated
Xcode projects, build products, signing material, and local configuration do not
belong in commits. Keep your team and bundle identifier overrides local.

## Changes and pull requests

Describe the problem, resulting behavior, and checks performed. For controller
changes, include the iPhone model, iOS version, host OS, and game or emulator
used. Distinguish actual-device results from automated checks or expected behavior.
Avoid posting device identifiers, provisioning data, or credentials in reports.

Keep a focused diff and preserve simultaneous input, releases, cancellation,
and neutral state when leaving gameplay. New tests should cover meaningful
behavior rather than duplicate implementation details.

## Bluetooth compatibility

The current service tree, canonical UUID representation, encryption properties,
report IDs, Xbox descriptor, PnP identity, and packet encoder were tested together.
Changes to these can affect pairing, cached GATT data, or native controller
recognition even if raw HID packets still arrive. Validate both controller
discovery and changing button/axis values on a physical host. Reconnects and
releases matter as well as initial button presses.

Do not claim Windows, Linux, other iOS versions, rumble, or App Store support
without evidence. Consult [the architecture notes](docs/BLUETOOTH.md) and
[preserved device results](docs/PROTOTYPE-VALIDATION.md).

## Attribution

Preserve the AGPL project license and third-party notices. Add provenance and
license information for any new external code or assets.
