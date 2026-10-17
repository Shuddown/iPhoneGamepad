import CoreBluetooth
import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var peripheral: HIDPeripheral
    @EnvironmentObject private var central: HIDCentral
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GamepadSettings.advertisedNameKey) private var name = "iPhone Gamepad"
    @AppStorage(GamepadSettings.hapticsKey) private var haptics = true
    @State private var lastAppliedName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(peripheral.gamepadSubscribers.isEmpty ? "Ready to connect" : "Gamepad connected",
                          systemImage: peripheral.gamepadSubscribers.isEmpty ? "antenna.radiowaves.left.and.right" : "gamecontroller.fill")
                        .foregroundStyle(peripheral.gamepadSubscribers.isEmpty ? Color.secondary : .mint)
                    if peripheral.state == .unauthorized {
                        Text("Allow Bluetooth access in iPhone Settings to connect your gamepad.")
                    } else if peripheral.state == .poweredOff {
                        Text("Turn on Bluetooth on this iPhone.")
                    }
                } footer: {
                    Text("Connect to your Mac here, then return to the gamepad. The iPhone may not appear in the Mac’s Bluetooth list.")
                }

                Section("Nearby devices") {
                    ForEach(devices) { device in
                        Button { select(device) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: central.connected.contains(device.id) ? "link.circle.fill" : "desktopcomputer")
                                    .foregroundStyle(central.connected.contains(device.id) ? Color.mint : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name).foregroundStyle(.primary)
                                    if central.connected.contains(device.id) {
                                        Text("Connected · tap to disconnect").font(.caption).foregroundStyle(.secondary)
                                    } else if device.rssi != 0 {
                                        Text("Signal \(device.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if central.connecting.contains(device.id) { ProgressView() }
                                else { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(central.connecting.contains(device.id))
                    }
                    if devices.isEmpty {
                        HStack {
                            if central.isScanning { ProgressView() }
                            Text(central.isScanning ? "Looking for your Mac…" : "No nearby devices found")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        central.isScanning ? central.stopScan() : central.startScan()
                    } label: {
                        Label(central.isScanning ? "Stop scanning" : "Scan for devices",
                              systemImage: central.isScanning ? "stop.circle" : "arrow.clockwise")
                    }
                }

                Section {
                    Toggle("Touch feedback", isOn: $haptics)
                    TextField("Gamepad name", text: $name).onSubmit(applyName)
                        .autocorrectionDisabled()
                    Button("Release all controls") { peripheral.sendGamepad(.zero) }
                } header: {
                    Text("Controller")
                } footer: {
                    Text("L2 and R2 press fully at touch-down. Slide down to reduce pressure. L3 and R3 click the sticks. Controls release when you lift your fingers or leave the app.")
                }

                if let error = peripheral.lastError ?? central.lastError {
                    Section("Connection") { Text(error).font(.callout).foregroundStyle(.orange) }
                }
                Section {
                    LabeledContent("App", value: "iPhone Gamepad")
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Connection", value: "Bluetooth gamepad")
                }
            }
            .navigationTitle("Connect & settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear {
            lastAppliedName = name
            if !peripheral.isAdvertising { peripheral.start() }
            central.startScan()
        }
        .onDisappear { central.stopScan(); applyName() }
        .presentationDragIndicator(.visible)
    }

    private var devices: [DiscoveredPeripheral] {
        central.discovered.sorted {
            if central.connected.contains($0.id) != central.connected.contains($1.id) { return central.connected.contains($0.id) }
            if $0.isNamed != $1.isNamed { return $0.isNamed }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func select(_ device: DiscoveredPeripheral) {
        if central.connected.contains(device.id) {
            peripheral.sendGamepad(.zero)
            central.disconnect(device.id)
        } else { central.connect(device.id) }
    }

    private func applyName() {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(26))
        name = trimmed.isEmpty ? "iPhone Gamepad" : trimmed
        guard name != lastAppliedName else { return }
        lastAppliedName = name
        peripheral.advertiseLocalName = name
        peripheral.stop()
        peripheral.start()
    }
}
