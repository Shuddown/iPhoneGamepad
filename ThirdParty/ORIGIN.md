# Provenance

The Bluetooth service-publication and connection-event implementation began
with [jqssun/darwin-bt-remote](https://github.com/jqssun/darwin-bt-remote), revision
`ad7a76ce6132254fbd6085af87cea8d10aa8a82d`, under AGPL-3.0. The project license is
preserved at the repository root. The retained prototype commit records the
starting implementation; the current source is organized as a dedicated gamepad.

The tested prototype snapshot is commit `a6cf028`. The current application
removes the upstream keyboard, mouse, remote-control UI, Classic transport,
localization strings, distribution metadata, and unrelated resources.

The Xbox BLE descriptor comes from lemmingDev/ESP32-BLE-Gamepad,
`BleXInputDescriptors.h`, revision `65d517864f86dc55b161f8b32a1650e0eb3c25aa`, which
credits Mystfit/ESP32-BLE-CompositeHID. Both MIT notices are included alongside
this document. The descriptor and its input/output report identities are
unchanged from the emulator-tested prototype.
