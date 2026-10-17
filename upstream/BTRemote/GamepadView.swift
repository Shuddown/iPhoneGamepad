import SwiftUI
#if os(iOS)
    import UIKit
#endif

/// Direct BLE HID controls. Every control edits the same absolute report so
/// holding a button while moving either stick preserves the other inputs.
struct GamepadView: View {
    @EnvironmentObject private var peripheral: HIDPeripheral
    @Environment(\.scenePhase) private var scenePhase
    @State private var report = GamepadReport.zero
    @State private var directions: Set<Int> = []
    #if os(iOS)
        @State private var previousIdleTimerDisabled = false
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionStatus
                HStack {
                    button("L1", number: 5)
                    trigger("L2", left: true)
                    trigger("R2", left: false)
                    button("R1", number: 6)
                }
                .frame(height: 48)
                HStack(alignment: .top, spacing: 20) {
                    VStack {
                        GamepadStick(label: "Left stick") { x, y in
                            report.leftX = x; report.leftY = y; send()
                        }
                        dpad
                    }
                    VStack {
                        faceButtons
                        GamepadStick(label: "Right stick") { x, y in
                            report.rightX = x; report.rightY = y; send()
                        }
                    }
                }
                HStack {
                    button("Select", number: 9)
                    button("L3", number: 11)
                    button("R3", number: 12)
                    button("Start", number: 10)
                }
                .frame(height: 44)
                Button("Release all controls", action: reset)
                    .buttonStyle(.bordered)
                Text("Use Setup → Devices in this app to connect to your Mac. Keep this screen open while playing. After a profile update, reconnect through Setup if input stops updating.")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            #if os(iOS)
                previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
                UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
        .onDisappear {
            reset()
            #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
            #endif
        }
        .onChange(of: scenePhase) { if $0 != .active { reset() } }
        .onChange(of: peripheral.gamepadSubscribers) { _ in reset() }
    }

    private var connectionStatus: some View {
        VStack(spacing: 4) {
            Label(peripheral.gamepadSubscribers.isEmpty ? "Waiting for gamepad connection" : "Host subscribed to gamepad",
                  systemImage: peripheral.gamepadSubscribers.isEmpty ? "antenna.radiowaves.left.and.right" : "gamecontroller.fill")
                .foregroundColor(peripheral.gamepadSubscribers.isEmpty ? .secondary : .green)
            if let error = peripheral.lastError {
                Text(error).foregroundColor(.red).font(.caption)
            }
            if !peripheral.isHIDServiceAdded {
                Button("Start Bluetooth controller") { peripheral.start() }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var faceButtons: some View {
        VStack(spacing: 6) {
            button("Y", number: 4)
            HStack(spacing: 30) {
                button("X", number: 3)
                button("B", number: 2)
            }
            button("A", number: 1)
        }
        .frame(height: 160)
    }

    private var dpad: some View {
        VStack(spacing: 6) {
            direction("↑", index: 0)
            HStack(spacing: 30) {
                direction("←", index: 3)
                direction("→", index: 1)
            }
            direction("↓", index: 2)
        }
        .frame(height: 160)
        .accessibilityLabel("Directional pad")
    }

    private func button(_ title: String, number: Int) -> some View {
        GamepadHold(title: title) { pressed in
            report.setButton(number, pressed: pressed)
            send()
        }
    }

    private func trigger(_ title: String, left: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption)
            // Dragging allows intermediate analog values; lifting releases to zero.
            GamepadTrigger { value in
                if left { report.leftTrigger = value } else { report.rightTrigger = value }
                send()
            }
            .accessibilityLabel(title)
        }
    }

    private func direction(_ title: String, index: Int) -> some View {
        GamepadHold(title: title) { pressed in
            if pressed { directions.insert(index) } else { directions.remove(index) }
            let x = (directions.contains(1) ? 1 : 0) - (directions.contains(3) ? 1 : 0)
            let y = (directions.contains(2) ? 1 : 0) - (directions.contains(0) ? 1 : 0)
            switch (x, y) {
            case (0, -1): report.hat = 0
            case (1, -1): report.hat = 1
            case (1, 0): report.hat = 2
            case (1, 1): report.hat = 3
            case (0, 1): report.hat = 4
            case (-1, 1): report.hat = 5
            case (-1, 0): report.hat = 6
            case (-1, -1): report.hat = 7
            default: report.hat = 8
            }
            send()
        }
    }

    private func send() { peripheral.sendGamepad(report) }

    private func reset() {
        directions.removeAll()
        report = .zero
        send()
    }
}

private struct GamepadHold: View {
    let title: String
    let changed: (Bool) -> Void
    @GestureState private var pressed = false

    var body: some View {
        Text(title).font(.headline)
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 12).fill(pressed ? Color.accentColor.opacity(0.5) : groupFill))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in state = true })
            // GestureState resets on cancellation as well as touch-up.
            .onChange(of: pressed, perform: changed)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { changed(true); changed(false) }
    }
}

private struct GamepadStick: View {
    let label: String
    let changed: (Int8, Int8) -> Void
    @GestureState private var offset = CGSize.zero

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(groupFill)
                Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                Circle().fill(Color.accentColor.opacity(0.7))
                    .frame(width: 48, height: 48)
                    .offset(offset)
            }
            .frame(width: 144, height: 144)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($offset) { value, state, _ in
                    let x = value.location.x - 72
                    let y = value.location.y - 72
                    let scale = max(1, sqrt(x * x + y * y) / 48)
                    state = CGSize(width: x / scale, height: y / scale)
                })
            .onChange(of: offset) { value in
                changed(axis(value.width), axis(value.height))
            }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .accessibilityLabel(label)
    }

    private func axis(_ value: CGFloat) -> Int8 {
        abs(value) < 4 ? 0 : Int8(max(-127, min(127, (value / 48 * 127).rounded())))
    }
}

private struct GamepadTrigger: View {
    let changed: (UInt8) -> Void
    @GestureState private var amount: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(groupFill)
                Capsule().fill(Color.accentColor.opacity(0.6))
                    .frame(width: geometry.size.width * amount)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($amount) { value, state, _ in
                    state = max(0, min(1, value.location.x / max(1, geometry.size.width)))
                })
            .onChange(of: amount) { changed(UInt8(($0 * 255).rounded())) }
        }
    }
}
