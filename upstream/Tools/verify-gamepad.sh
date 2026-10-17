#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/validation
swiftc BTRemote/LowEnergy/GamepadReport.swift BTRemote/LowEnergy/XboxBLEProfile.swift BTRemote/LowEnergy/HIDProfile.swift Tests/GamepadReportTests.swift -o .build/validation/GamepadReportTests
.build/validation/GamepadReportTests
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
