import SwiftUI
import UIKit

struct GamepadView: View {
    @EnvironmentObject private var peripheral: HIDPeripheral
    @EnvironmentObject private var central: HIDCentral
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(GamepadSettings.hapticsKey) private var haptics = true
    @State private var showConnection = false
    @State private var resetToken = 0
    @State private var oldIdleTimer = false

    private var connected: Bool { !peripheral.gamepadSubscribers.isEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            GamepadSurface(resetToken: resetToken, haptics: haptics) { peripheral.sendGamepad($0) }
                .ignoresSafeArea()
            HStack(spacing: 12) {
                Button { showConnection = true } label: {
                    HStack(spacing: 7) {
                        Circle().fill(connected ? Color.mint : .orange).frame(width: 6, height: 6)
                        Text(connected ? "Connected" : "Connect").font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Capsule().fill(.white.opacity(0.06)))
                }
                .accessibilityIdentifier("gamepad.connection")
                Button(action: releaseAll) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .medium))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Release all controls")
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.top, 8)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $showConnection) {
            ConnectionView().environmentObject(peripheral).environmentObject(central)
                .preferredColorScheme(.dark)
        }
        .onChange(of: showConnection) { if $0 { releaseAll() } }
        .onChange(of: scenePhase) { if $0 != .active { releaseAll() } }
        .onChange(of: peripheral.gamepadSubscribers) { _ in releaseAll() }
        .onAppear {
            oldIdleTimer = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            releaseAll()
            UIApplication.shared.isIdleTimerDisabled = oldIdleTimer
        }
    }

    private func releaseAll() {
        resetToken += 1
        peripheral.sendGamepad(.zero)
    }
}
