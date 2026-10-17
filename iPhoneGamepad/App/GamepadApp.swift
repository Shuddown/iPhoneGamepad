import SwiftUI

@main
struct GamepadApp: App {
    @StateObject private var gamepad = GamepadPeripheral()
    @StateObject private var hostDiscovery = GamepadHostDiscovery()

    init() { GamepadSettings.registerDefaults() }

    var body: some Scene {
        WindowGroup {
            GamepadView()
                .environmentObject(gamepad)
                .environmentObject(hostDiscovery)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Register connection events before publishing the HID service.
                    hostDiscovery.start()
                    gamepad.start()
                }
                #if DEBUG
                    .task { await gamepad.runGamepadProbeIfRequested() }
                #endif
        }
    }
}
