import CoreBluetooth
import SwiftUI

struct GamepadConnectionView: View {
    @EnvironmentObject private var gamepad: GamepadPeripheral
    @EnvironmentObject private var hostDiscovery: GamepadHostDiscovery
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GamepadSettings.advertisedNameKey) private var name = "iPhone Gamepad"
    @AppStorage(GamepadSettings.hapticsKey) private var haptics = true
    @State private var lastAppliedName = ""

    private var connected: Bool { !gamepad.gamepadSubscribers.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        connected ? "Connected" : gamepad.isRunning ? "Ready to connect" : "Disconnected",
                        systemImage: connected ? "gamecontroller.fill" : "antenna.radiowaves.left.and.right"
                    )
                    .foregroundStyle(connected ? Color.mint : .secondary)
                    if gamepad.isRunning {
                        Button("Disconnect all", role: .destructive) {
                            gamepad.stop()
                            hostDiscovery.disconnectAll()
                        }
                    } else {
                        Button("Connect") {
                            gamepad.start()
                            startScanning()
                        }
                    }
                    if gamepad.state == .unauthorized {
                        Text("Allow Bluetooth access in iPhone Settings to connect your gamepad.")
                    } else if gamepad.state == .poweredOff {
                        Text("Turn on Bluetooth on this iPhone.")
                    }
                } footer: {
                    Text(
                        "Disconnect removes the controller from the selected device. A shared Bluetooth connection may remain for other iPhone features."
                    )
                }

                if gamepad.isRunning {
                    Section("Devices") {
                        ForEach(devices) { device in
                            HStack(spacing: 12) {
                                Image(systemName: "desktopcomputer").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name)
                                    if gamepad.gamepadSubscribers.contains(device.id) {
                                        Text("Connected").font(.caption).foregroundStyle(.mint)
                                    } else if gamepad.requestedHosts.contains(device.id) {
                                        Text("Connecting…").font(.caption).foregroundStyle(.secondary)
                                    } else if device.rssi != 0 {
                                        Text("Signal \(device.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if gamepad.requestedHosts.contains(device.id) {
                                    Button("Disconnect", role: .destructive) {
                                        gamepad.disconnectHost(device.id)
                                        hostDiscovery.disconnect(device.id)
                                    }
                                    .buttonStyle(.borderless)
                                } else {
                                    Button("Connect") {
                                        gamepad.connectHost(device.id)
                                        hostDiscovery.connect(device.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        if devices.isEmpty {
                            HStack {
                                if hostDiscovery.isScanning { ProgressView() }
                                Text(hostDiscovery.isScanning ? "Looking for devices…" : "No nearby devices found")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            hostDiscovery.isScanning ? hostDiscovery.stopScan() : startScanning()
                        } label: {
                            Label(
                                hostDiscovery.isScanning ? "Stop scanning" : "Scan for devices",
                                systemImage: hostDiscovery.isScanning ? "stop.circle" : "arrow.clockwise")
                        }
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
            if gamepad.isRunning { startScanning() }
        }
        .onChange(of: gamepad.knownHostIDs) { hostDiscovery.rememberHosts($0) }
        .onChange(of: gamepad.observedHostIDs) { hostDiscovery.rememberHosts($0) }
        .onDisappear {
            hostDiscovery.stopScan()
            applyName()
        }
        .presentationDragIndicator(.visible)
    }

    private func startScanning() {
        hostDiscovery.startScan()
        hostDiscovery.rememberHosts(gamepad.knownHostIDs.union(gamepad.observedHostIDs))
    }

    private var devices: [DiscoveredGamepadHost] {
        hostDiscovery.discovered.sorted {
            if $0.isNamed != $1.isNamed { return $0.isNamed }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func applyName() {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(26))
        name = trimmed.isEmpty ? "iPhone Gamepad" : trimmed
        guard name != lastAppliedName else { return }
        lastAppliedName = name
        gamepad.advertiseLocalName = name
        gamepad.refreshAdvertising()
    }
}
