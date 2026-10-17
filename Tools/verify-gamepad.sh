#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/validation
gamepad_sources=(
  iPhoneGamepad/Bluetooth/GamepadReport.swift
  iPhoneGamepad/Bluetooth/GamepadReportBuffer.swift
  iPhoneGamepad/Bluetooth/XboxBLEProfile.swift
  iPhoneGamepad/Bluetooth/GamepadHIDProfile.swift
  iPhoneGamepad/Controls/GamepadControl.swift
  iPhoneGamepad/Controls/GamepadLayout.swift
  iPhoneGamepad/Controls/GamepadLayoutConfiguration.swift
  iPhoneGamepad/Controls/GamepadInputState.swift
  Tests/GamepadCoreTests.swift
)
swiftc "${gamepad_sources[@]}" -o .build/validation/GamepadCoreTests
.build/validation/GamepadCoreTests
swiftc Tools/GamepadMonitor.swift -o .build/validation/GamepadMonitor
mkdir -p .build/validation/GameControllerProbe.app/Contents/MacOS
swiftc Tools/GameControllerProbe.swift -o .build/validation/GameControllerProbe.app/Contents/MacOS/GameControllerProbe
cat > .build/validation/GameControllerProbe.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.iphonegamepad.probe</string>
<key>CFBundleExecutable</key><string>GameControllerProbe</string>
<key>CFBundleName</key><string>Game Controller Probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>GCSupportsControllerUserInteraction</key><true/>
</dict></plist>
PLIST
codesign --force --sign - .build/validation/GameControllerProbe.app
echo 'Built .build/validation/GamepadMonitor and GameControllerProbe.app'
