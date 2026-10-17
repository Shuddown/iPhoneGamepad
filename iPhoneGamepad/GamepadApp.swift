import SwiftUI

@main
struct GamepadApp: App {
    @StateObject private var peripheral = HIDPeripheral()
    @StateObject private var central = HIDCentral()

    init() { GamepadSettings.registerDefaults() }

    var body: some Scene {
        WindowGroup {
            GamepadView()
                .environmentObject(peripheral)
                .environmentObject(central)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Register connection events before publishing the HID service.
                    central.start()
                    peripheral.start()
                }
                #if DEBUG
                    .task { await peripheral.runGamepadProbeIfRequested() }
                #endif
        }
    }
}
