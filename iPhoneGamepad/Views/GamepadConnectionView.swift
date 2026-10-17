import CoreBluetooth
import SwiftUI

struct GamepadConnectionView: View {
    @EnvironmentObject private var gamepad: GamepadPeripheral
    @EnvironmentObject private var hostDiscovery: GamepadHostDiscovery
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GamepadSettings.advertisedNameKey) private var name = "iPhone Gamepad"
    @AppStorage(GamepadSettings.hapticsKey) private var haptics = true
    @State private var lastAppliedName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        gamepad.gamepadSubscribers.isEmpty ? "Ready to connect" : "Gamepad connected",
                        systemImage: gamepad.gamepadSubscribers.isEmpty
                            ? "antenna.radiowaves.left.and.right" : "gamecontroller.fill"
                    )
                    .foregroundStyle(gamepad.gamepadSubscribers.isEmpty ? Color.secondary : .mint)
                    if gamepad.state == .unauthorized {
                        Text("Allow Bluetooth access in iPhone Settings to connect your gamepad.")
                    } else if gamepad.state == .poweredOff {
                        Text("Turn on Bluetooth on this iPhone.")
                    }
                } footer: {
                    Text(
                        "Connect to your Mac here, then return to the gamepad. The iPhone may not appear in the Mac’s Bluetooth list."
                    )
                }

                Section("Nearby devices") {
                    ForEach(devices) { device in
                        Button {
                            select(device)
                        } label: {
                            HStack(spacing: 12) {
                                Image(
                                    systemName: hostDiscovery.connected.contains(device.id)
                                        ? "link.circle.fill" : "desktopcomputer"
                                )
                                .foregroundStyle(hostDiscovery.connected.contains(device.id) ? Color.mint : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name).foregroundStyle(.primary)
                                    if hostDiscovery.connected.contains(device.id) {
                                        Text("Connected · tap to disconnect").font(.caption).foregroundStyle(.secondary)
                                    } else if device.rssi != 0 {
                                        Text("Signal \(device.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if hostDiscovery.connecting.contains(device.id) {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(hostDiscovery.connecting.contains(device.id))
                    }
                    if devices.isEmpty {
                        HStack {
                            if hostDiscovery.isScanning { ProgressView() }
                            Text(hostDiscovery.isScanning ? "Looking for your Mac…" : "No nearby devices found")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        hostDiscovery.isScanning ? hostDiscovery.stopScan() : hostDiscovery.startScan()
                    } label: {
                        Label(
                            hostDiscovery.isScanning ? "Stop scanning" : "Scan for devices",
                            systemImage: hostDiscovery.isScanning ? "stop.circle" : "arrow.clockwise")
                    }
                }

                Section {
                    Toggle("Touch feedback", isOn: $haptics)
                    TextField("Gamepad name", text: $name).onSubmit(applyName)
                        .autocorrectionDisabled()
                    Button("Release all controls") { gamepad.sendGamepad(.zero) }
                } header: {
                    Text("Controller")
                } footer: {
                    Text(
                        "L2 and R2 press fully at touch-down. Slide down to reduce pressure. L3 and R3 click the sticks. Controls release when you lift your fingers or leave the app."
                    )
                }

                if let error = gamepad.lastError ?? hostDiscovery.lastError {
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
            if !gamepad.isAdvertising { gamepad.start() }
            hostDiscovery.startScan()
        }
        .onDisappear {
            hostDiscovery.stopScan()
            applyName()
        }
        .presentationDragIndicator(.visible)
    }

    private var devices: [DiscoveredGamepadHost] {
        hostDiscovery.discovered.sorted {
            if hostDiscovery.connected.contains($0.id) != hostDiscovery.connected.contains($1.id) {
                return hostDiscovery.connected.contains($0.id)
            }
            if $0.isNamed != $1.isNamed { return $0.isNamed }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func select(_ device: DiscoveredGamepadHost) {
        if hostDiscovery.connected.contains(device.id) {
            gamepad.sendGamepad(.zero)
            hostDiscovery.disconnect(device.id)
        } else {
            hostDiscovery.connect(device.id)
        }
    }

    private func applyName() {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(26))
        name = trimmed.isEmpty ? "iPhone Gamepad" : trimmed
        guard name != lastAppliedName else { return }
        lastAppliedName = name
        gamepad.advertiseLocalName = name
        gamepad.stop()
        gamepad.start()
    }
}
