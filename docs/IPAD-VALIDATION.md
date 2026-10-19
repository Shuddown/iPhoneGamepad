# iPad / Delta controller recognition investigation

October 18, 2026. iPhone 15 on iOS 27.0.1; iPad (A16) on iPadOS 27.0;
Delta 1.7.6 (build 152). Both devices were inspected over USB. Controller
communication itself used Bluetooth.

## Initial failure

- The iPhone's in-app setup listed the iPad as connected.
- The iPhone's peripheral delegate reported input-report subscriptions from two
  hosts. The Mac separately detected the phone as an Xbox-compatible controller.
  The phone's global Connected label therefore cannot establish which host has
  accepted a native game controller.
- Delta's Player 1 settings displayed No Connected Controllers.
- A temporary diagnostic app on the physical iPad independently polled
  `GCController.controllers()`, which returned zero controllers. This reproduces
  the failure below Delta's controller-selection UI.
- A separate GATT inspection on the iPad found both the system's Device
  Information service and the app's full-UUID Device Information service.
- The system service returned Apple Inc. and the iPhone hardware model. The
  app's service returned iPhone Gamepad and PnP bytes `02 5e 04 13 0b 00 05`,
  matching the intended Xbox-compatible identity.

Selected system-log evidence, with the device name omitted:

```text
gamecontrollerd: Check <IOHIDDevice ...> is a supported game controller {
    vendorID = 0,
    productID = 0,
    version = 0,
    manufacturer = 'Apple Inc.',
    product = '[iPhone device name]',
    transport = 'BluetoothLowEnergy',
}
gamecontrollerd: ... is NOT a supported game controller.
```

The iPad receives the HID service/report map and subscribes, but its native
controller registration does not use the app's intended vendor/product IDs.
Bluetooth connection or subscription is not equivalent to native gamepad support.

## Compatibility experiments

1. Restarted the existing iPhone build with developer logging and its explicit
   A/stick/trigger/D-pad diagnostic sequence. Native iPad controller count
   remained zero; the system log rejected the zero-ID device.
2. Built an isolated experimental variant that explicitly included the app's
   Device Information and Battery services in the HID service. Publication and
   subscription succeeded, but iPadOS again registered zero vendor/product IDs
   and rejected native game-controller support.
3. A temporary peripheral probe on the iPad attempted to publish a secondary
   Device Information service with short UUID `180A`. CoreBluetooth returned
   `The specified UUID is not allowed for this operation.`

4. Kept the full 128-bit service UUIDs, but changed characteristics and
   descriptors to standard short UUIDs. The Mac recovered Xbox identity and live
   input. The iPad initially retained its zero-ID identity.
5. The user turned Bluetooth fully off/on in iPad Settings, then reconnected
   through the iPhone app. No Bluetooth device-list entry or Forget operation
   was available or required. The iPad then registered vendor `1118` (`045E`),
   product `2835` (`0B13`), version `1280` (`0500`), and manufacturer iPhone Gamepad.
   The diagnostic reported **one Xbox One controller, extended profile true**.
   Its logs recorded live A/B/X/Y presses and movement of both sticks; the user
   independently confirmed that the values changed.

The short-characteristic/descriptor UUID change is now in the application.
The observed successful combination is this profile and a refreshed Bluetooth
connection; the test does not isolate every effect of cached identity data.
The service-inclusion variant and secondary-service probe are not incorporated.
The user subsequently confirmed that Delta lists the controller. Gameplay
verification is still pending.

A single generic-manager log line still said “NOT a supported game controller”
after the identity became correct, but the Xbox driver subsequently registered
a native controller. That line alone is therefore insufficient to diagnose
failure; controller enumeration and changing values are the decisive checks.

## What the original Mac fix contributed

The original darwin-bt-remote implemented keyboard/mouse HID. Its full service
UUID publication workaround, service ordering, and in-app connection-event
registration were inherited. Our early generic gamepad descriptor delivered
raw HID input but no working native Game Controller values. The successful
Mac prototype used the Xbox BLE descriptor, input report 1/output report 3,
Microsoft-compatible PnP identity, and matching 16-byte input serializer.
Those components were retained for this iPad test; changing the representation
of characteristic/descriptor UUIDs and refreshing the connection was sufficient
to obtain working native iPad input. No keyboard emulation was needed.

Delta's [controller guidance](https://faq.deltaemulator.com/using-delta/controllers)
requires OS-supported controllers and also supports keyboard input. Its
[controller manager](https://github.com/rileytestut/DeltaCore/blob/main/DeltaCore/Game%20Controllers/ExternalGameControllerManager.swift)
uses the system Game Controller API for native controllers. Keyboard emulation
would be a separate compatibility approach, with digital rather than analog
input; it is not established by the native-gamepad tests above.

## Earlier input-only workaround (superseded)

The previous nearby-device “disconnect” canceled only the app's central-role
setup link. The host could retain its system HID subscription and continue
receiving broadcasts. Build 11 separated setup links from actual HID subscribers and provided
per-host input toggles plus a global pause.
Paused hosts receive neutral input, are excluded from subsequent notifications,
and receive neutral input-report reads. Neutral releases remain pending while
the BLE queue is full; reopening settings does not resume global input.

Build 11 was installed on the physical iPhone. With the Mac and iPad subscribed,
the user turned off the Mac under **Send controls to** and confirmed:
**“Mac stops; iPad continues.”** This validates independent host input routing.
It does not establish physical Bluetooth disconnection; a paused controller can
remain registered on the host. Core routing/report tests, Swift formatting, and
the signed iPhone build passed. Hardware queue-saturation testing was not done.

## Service teardown and simple Connect/Disconnect

The next experiment stopped advertising, removed all app-published services,
and released the peripheral manager. Both hosts had subscribed before teardown.
The Mac reported HID removal, a native Game Controller disconnect, and controller
count zero. A passive iPad diagnostic (no separate GATT inspection connection)
also changed from one Xbox controller to zero controllers.

Build 13 used this teardown for a single **Disconnect** action.
The input-only workaround above was removed. Build 13 completed two UI
disconnect/reconnect cycles; both hosts reported controller counts
`1 → 0 → 1 → 0 → 1` without a Bluetooth restart. Reconnection validation and
research references are recorded in [DISCONNECT.md](DISCONNECT.md).


## Independent controller removal

The per-device service architecture now replaces the global-only UI. The
production lifecycle passed two iPad disconnect/reconnect cycles while Mac
input continued: native iPad controller counts were `1 → 0 → 1 → 0 → 1`.
Two Mac-only cycles removed the Mac HID controller while the iPad retained one
native controller with live A-button input. Reconnecting the Mac restored its
HID device and input. This removes a controller service; a shared Bluetooth
link may remain. Full details and limits are in [DISCONNECT.md](DISCONNECT.md).
