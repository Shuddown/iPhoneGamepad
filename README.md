# iPhone Gamepad prototype

The implementation is a modified clone in [upstream](upstream), based on
[jqssun/darwin-bt-remote](https://github.com/jqssun/darwin-bt-remote) at
`ad7a76ce6132254fbd6085af87cea8d10aa8a82d`.

It uses the iPhone as a direct Bluetooth LE HID controller. The default profile
uses the Xbox BLE descriptor and compatibility identity so macOS selects its
supported controller driver. No Mac bridge or virtual-HID entitlement is needed.
USB is used to install/debug the iPhone app, not to carry controller input.

Tested on a physical iPhone 15 running iOS 27.0.1 and a Mac running macOS 27.0.1,
using Xcode 27. See [the implementation and validation notes](upstream/GAMEPAD.md).

Open `upstream/BTRemote.xcodeproj` in Xcode (run `xcodegen generate` inside
`upstream` if needed). The installed development app is **iPhone Gamepad**.

The downloaded Git history is preserved in `.git/upstream-history`. The tested
source snapshot is tracked by this workspace's repository. Inspect changes with:

```sh
git status --short
git diff
```

The original project's AGPL-3.0 license remains applicable. Third-party BLE
descriptor notices are preserved in `upstream/ThirdParty`.
