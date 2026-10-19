# Connect and disconnect

Research and physical-device tests, October 18, 2026.

## Examples and platform APIs

The examples reviewed support a simple connection UI. This is a small sample,
not a survey establishing what most controller apps do.

- [PocketPad's settings](https://github.com/Dathaze20/PocketPad/blob/main/app/src/main/java/com/dathaze/pocketpad/MainActivity.kt)
  offer Connect paired and Disconnect. Its
  [HID manager](https://github.com/Dathaze20/PocketPad/blob/main/app/src/main/java/com/dathaze/pocketpad/hid/HidGamepadManager.kt)
  implements disconnect with Android's `BluetoothHidDevice.disconnect(device)`.
- [TabletHID's BLE manager](https://github.com/Neuro-Mechatronics-Interfaces/TabletHID/blob/main/app/src/main/java/com/tablet/hid/bluetooth/BleHidManager.kt)
  stops advertising and invokes `BluetoothGattServer.cancelConnection(device)`.
  It keeps its GATT server for subsequent reconnection. Android exposes this
  server-side connection cancellation; iOS's `CBPeripheralManager` does not
  expose an equivalent per-central cancellation operation.
- [Sony's controller guide](https://controller.dl.playstation.net/controller/lang/en/)
  describes pairing and turning a DualSense controller on/off with its PS button.
  [8BitDo's manual](https://download.8bitdo.com/Manual/Controller/Ultimate/Ultimate-Bluetooth-Controller.pdf)
  similarly describes a Home-button power-off action. The hardware owns its
  Bluetooth controller and can shut it down. As another firmware example,
  [NimBLE's server API](https://h2zero.github.io/NimBLE-Arduino/class_nim_b_l_e_server.html)
  exposes `disconnect(connectionHandle)`.

Disconnecting, stopping discoverability, and forgetting a saved pairing are
separate operations. A normal disconnect does not require the host to erase its
pairing record. [Apple's controller guidance](https://support.apple.com/en-ie/111099)
separately describes Forget This Device and controller connection switching.

## What this iPhone app can control

Apple documents that [cancelPeripheralConnection](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/cancelperipheralconnection(_:))
cancels the app's local connection and does not guarantee immediate physical
link disconnection. This app uses that central role to initiate setup, while the
host reads and subscribes to the iPhone's peripheral-role HID service.

[stopAdvertising](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/stopadvertising())
only stops advertising; it does not withdraw the published gamepad.
[removeAllServices](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/removeallservices())
removes services published by this app. Apple's documentation explicitly notes
that apps share the GATT database and this operation leaves other apps' services
alone. [CBPeripheralManager](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager)
provides service publication, advertising, and notifications, with no public
per-central disconnect or remote unpair operation.

The app now presents per-device **Connect / Disconnect** actions, plus
**Disconnect all**. Each selected device owns an independently published HID
service. Its Report Map is a gamepad only when read by that owner; other hosts
see a vendor-defined collection. Removing the selected instance withdraws its
controller without removing the other host's gamepad. Reconnecting creates new
service/characteristic objects and routes input only to the owner.

The device list and scanning remain available while another host is connected.
A row says Connected only after its owner subscribes to its own input report.
Pending connection requests can also be cancelled with Disconnect. Selected and
previously selected host IDs are remembered across app launches.

**This is controller removal, not a guarantee of physical Bluetooth link
termination.** The shared link may carry other services. The user explicitly
selected this behavior after the prototype passed two cycles per host. Neither
host exposed this iPhone as an ordinary Bluetooth-settings device during testing;
no Forget operation was required or requested.

## Hardware evidence

Devices: iPhone 15 / iOS 27.0.1; iPad A16 / iPadOS 27.0; Mac / macOS 27.0.1.

An isolated teardown build first confirmed two HID input subscribers, then
withdrew the services and released the peripheral manager. The Mac reported:

```text
HID gamepad/joystick removed
GC_DISCONNECT: controller disconnected; remaining=0
GC_COUNT: 0
```

A passive diagnostic on the iPad independently changed from one Xbox One
controller with an extended profile to `Native controllers: 0`. It did not open
its own GATT inspection connection during this test. These observations
establish native controller removal on these hosts, not proof that every
underlying shared Bluetooth link was terminated.

The production UI build (13) uses the same teardown. On installation and launch
after the teardown experiment, both hosts registered the Xbox controller again
without a Bluetooth power cycle. The signed Debug build, unsigned Release build,
core report/input tests, formatting check, and whitespace check passed. The installed build then completed two UI disconnect/reconnect cycles: the
phone logged service withdrawal and republication twice, the Mac observed
`1 → 0 → 1 → 0 → 1` native controllers, and the passive iPad diagnostic observed
the same sequence. No Bluetooth restart was needed. No companion receiver is needed for normal
operation; the diagnostics only observe native controller registration.

## Per-device limitation

The user confirmed that Connect and Disconnect work, then requested those
operations per device in the device list. The previously working input toggles
do not meet that request: they leave the native controller registered.

The earlier single-service withdrawal method affected every subscriber to the
shared HID service. The public `CBPeripheralManager` API has no per-central disconnect.
Further experiments found a private operation that actually tears down one
host's link, but the host automatically reconnects. A stable per-device **physical link termination** was not validated by those
experiments. Independent controller removal was subsequently validated below.

## Private API and reconnect experiments

These experiments ran in an isolated local project copy on the same physical
devices. No private API was added to the main application. The observations
below describe these OS versions and do not establish behavior on every release.

| Experiment | Observed result |
| --- | --- |
| `CBCentralManager.cancelPeripheralConnection:force:` after acquiring an app-owned connection to the selected subscriber | Selected host unsubscribes; native/raw controller disappears; other host remains subscribed. Selected host reconnects automatically. Tested targeting both Mac and iPad. |
| Stop gamepad advertising before forced cancellation, retaining services | Automatic reconnection still occurs. Stopping this app's advertising does not establish that the iPhone's system radio is no longer connectable. |
| Private cancellation options: force plus `kCBCancelConnectOptionDoNotAutoConnectBuiltInServices` | Automatic reconnection still occurs. |
| Private per-peer connection options, `CBConnectPeripheralOptionEnableAutoReconnect = false` | Daemon accepts the options request; automatic reconnection still occurs. Later analysis of macOS 27 shows this handler reads a different key, so acceptance did not establish that this auto-reconnect setting was applied. |
| Recognized per-peer option `kCBConnectOptionDisableWakeOnLeLinkDrop = true` | iPhone daemon logs the selected peer changing from 0 to 1. The iPad still reconnects; the flag returns to 0 after disconnect. This setting does not establish an incoming connection block. |
| Register connection events for only the other host | Automatic reconnection still occurs. This filters event registration, not incoming connections. |
| Clear HID Information's NormallyConnectable bit (flags `0x01`) | Both hosts demonstrably read the changed value. Targeted Mac disconnect still automatically reconnects. |
| Clear both NormallyConnectable and RemoteWake (flags `0x00`) | Both hosts read the changed value. Targeted iPad disconnect still automatically reconnects. |
| Modern private `CBConnection.disconnectWithCompletion` | Returns XPC connection invalidated (`NSOSStatusErrorDomain`, -71148). The examined daemon implementation gates its system interface on Apple Bluetooth entitlements. |
| Reject the selected host's HID Information and Report Map reads after targeted force cancellation | The iPad still reconnects and subscribes to input. Native controller enumeration was already zero before this experiment, so its count cannot establish selective native removal. |
| Read-only query through `CBManager.sendRawCommand:data:completionHandler:` | Runtime code begins with `mov w0, #0; ret`; the method is a stub and returns false. No HCI command is sent. |
| Private debug query for incoming-deny-list support | The daemon receives `CBMsgIdDebugCommand`, but no handler execution/result was observed. Examined implementation requires a privileged session and a platform gate; the method's true return only means the message was sent. |
| Legacy `BluetoothManager` session/device lookup | No session after ten seconds; selected subscriber lookup returns no device. |
| Explicit legacy `BTSessionAttachWithQueue` | Initial return is 0, but system logs show service bootstrap lookup failure, invalid XPC connection, session handle 0, and attach result 515. No usable session or disconnect follows. |

Reconnect tests also used passive diagnostics that did not start wireless
controller discovery. The iPad diagnostic did not create its own GATT inspection
connection. This rules out those diagnostic connection requests as a necessary
cause of the observed reconnects. Native controller counts alone can be
misleading after repeated profile experiments, so HID subscription events and
raw HID registration were also checked where available.

The private selectors' runtime signatures were checked before calling them.
Source research used the published
[CoreBluetooth cancellation implementation](https://github.com/EthanArbuckle/iPhone18-3_26.1_23B85_Restore/blob/90aa0cfe59d9682b4265e1354c8b19ec3c7823ab/System/Library/Frameworks/CoreBluetooth.framework/CoreBluetooth/CBCentralManager.mm),
[daemon system-interface authorization](https://github.com/EthanArbuckle/iPhone18-3_26.1_23B85_Restore/blob/90aa0cfe59d9682b4265e1354c8b19ec3c7823ab/usr/sbin/bluetoothd/CBDaemonXPCConnection.mm),
and [older runtime headers](https://github.com/nst/iOS-Runtime-Headers/blob/master/Frameworks/CoreBluetooth.framework/CBCentralManager.h).
These are reverse-engineering evidence, not supported Apple API contracts.
The HID flags are defined by the Bluetooth SIG
[HID Service specification](https://devzone.nordicsemi.com/cfs-file/__key/support-attachments/beef5d1b77644c448dabff31668f3a47-d2e31a4fe5fd4955b77461e3188e06af/HIDS_5F00_SPEC_5F00_V10.pdf).

No unpairing, global radio reset, incoming-connection denylist modification, or
Apple-only entitlement was used. No repeated-disconnect loop or input blocking
was substituted for a stable disconnected state. The working global Disconnect
implementation remains the application behavior.

### Recognition recovery during research

After repeated experimental profile changes, the iPad and Mac could retain an
Apple/zero-ID HID identity even after the known working binary was reinstalled.
The iPad's native diagnostic reported zero while the phone still saw an input
subscription. An iPad Bluetooth restart alone did not immediately recover it.
After restoring the normal profile and connection controls, the diagnostic
again reported one Xbox One extended controller, and the user independently
confirmed both the restored Connect button and native count one. The sequence
does not isolate which refresh step repaired the cached identity. Raw Mac HID
input was verified during recovery; that alone does not establish native Mac
Game Controller recognition.

### Newer daemon analysis

A read-only analysis of the Mac's installed macOS 27 `bluetoothd` found the
`CBMsgIdPeerSetConnectionOptions` handler. It constructs `ConnectOptions` using
`kCBConnectOptionDisableWakeOnLeLinkDrop` and stores it for that app/peer. Its
aggregation path examines both `disableWakeOnLeLinkDrop` and
`enableAutoReconnect`; this handler only sets the former. Testing the recognized
key on the iPhone confirmed a daemon state change but did not prevent reconnect.
Mac disassembly is evidence about the Mac implementation; the iPhone's observed
state change is the independent evidence that this option is recognized there.

## Per-host HID service validation

A separate prototype tested another architecture without forced link
cancellation. It publishes one independent HID service per selected host. The
Report Map read identifies the owning host's instance as an Xbox gamepad and
identifies the other instance as a vendor-defined HID collection. Disconnecting
a controller removes its actual published service; reconnecting republishes it.
No private API is invoked by this experiment. HID supports multiple service
instances; see the Bluetooth SIG's
[HOGP test suite](https://files.bluetooth.com/wp-content/uploads/2024/10/HOGP.TS_.p11.pdf).
Host-specific report-map behavior remains an experimental interoperability
technique, rather than a guarantee about all hosts or OS releases.

Build 35 completed two withdrawal/republication cycles per host with timed
physical-device logs. Every phase lasted approximately eight seconds and sent
eight A-button pulses to each available controller instance:

| Published gamepad instances | iPad native controllers | iPad A presses | Mac raw HID A presses | Mac raw HID removal |
| --- | --- | --- | --- | --- |
| Both (initial) | 1 | 7 | 8 | No |
| Mac only, first cycle | 0 | 0 | 8 | No |
| Both restored | 1 | 7 | 8 | No |
| Mac only, second cycle | 0 | 0 | 8 | No |
| Both restored | 1 | 7 | 8 | No |
| iPad only, first cycle | 1 | 8 | 0 | Yes |
| Both restored | 1 | 8 | 7 | Reattached |
| iPad only, second cycle | 1 | 8 | 0 | Yes |
| Both restored | 1 | 8 | 7 | Reattached |

A missing initial pulse after publication is consistent with asynchronous
discovery/subscription; these tests do not measure connection latency.
Mac validation here is raw HID registration and input. The Mac native Game
Controller diagnostic retained a zero-ID identity during these experiments, so
this table does not claim validation through the Mac Game Controller API.

This establishes independent controller-service removal and restoration on
these devices, including native controller removal on the iPad. It does **not**
establish physical Bluetooth disconnection: the selected host can remain linked
to the iPhone, including the other service's vendor-defined HID collection and
Apple system services. It does not terminate the complete Bluetooth connection.
The user accepted controller removal as the product behavior, and this
architecture is now implemented in the normal application without private APIs.
Private API experiments remain isolated in ignored development artifacts.


### Application integration validation

The normal application lifecycle (build 36 source) was exercised with a
Debug-only USB launch flag supplying the two local peer identifiers. The flag
calls the same `connectHost` / `disconnectHost` methods as the device buttons;
it never runs during ordinary use and contains no fixed device identifiers.
Two cycles per host produced the same outcomes as the isolated prototype:

| Disconnected device | iPad native controllers | iPad A presses | Mac raw HID input |
| --- | --- | --- | --- |
| iPad, both cycles | 0 | 0 after settling | Continues |
| Mac, both cycles | 1 | Continues | Device removed; no presses after settling |
| Neither, after each reconnect | 1 | Resumes | Device reattached; input resumes |

Each phase sent eight pulses after three seconds for discovery. Timed logs
have one-second phone/Mac timestamps, so a two-second settling interval was
excluded when counting input; surviving hosts recorded seven or eight pulses.
Mac removal callbacks occurred in both Mac-disconnect phases. iPad registration
and live input survived both. No Bluetooth restart or private API was needed.
This validates production lifecycle methods on hardware; it is not an automated
test of tapping the settings UI. Signed Debug and unsigned Release builds,
core tests (including host-specific descriptors, characteristic isolation and
pending-report removal), formatting and whitespace checks passed.
