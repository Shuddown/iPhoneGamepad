import SwiftUI
import UIKit

struct GamepadView: View {
    @EnvironmentObject private var gamepad: GamepadPeripheral
    @EnvironmentObject private var hostDiscovery: GamepadHostDiscovery
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(GamepadSettings.hapticsKey) private var haptics = true
    @AppStorage(GamepadSettings.forgivingKey) private var forgiving = false
    @State private var showConnection = false
    @State private var showEditor = false
    @State private var configuration = GamepadLayoutConfiguration.load()
    @State private var resetToken = 0
    @State private var oldIdleTimer = false

    private var connected: Bool { !gamepad.gamepadSubscribers.isEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            GamepadTouchSurface(
                resetToken: resetToken, haptics: haptics, forgiving: forgiving, configuration: configuration
            ) { gamepad.sendGamepad($0) }
            .ignoresSafeArea()
            HStack(spacing: 12) {
                Button {
                    showConnection = true
                } label: {
                    HStack(spacing: 7) {
                        Circle().fill(connected ? Color.mint : .orange).frame(width: 6, height: 6)
                        Text(connected ? "Connected" : "Connect").font(
                            .system(size: 12, weight: .semibold))
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
                Button {
                    releaseAll()
                    showEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 40, height: 40)
                }
                .accessibilityLabel("Edit gamepad layout")
                .accessibilityIdentifier("gamepad.editLayout")
                Button {
                    releaseAll()
                    forgiving.toggle()
                } label: {
                    Text(forgiving ? "Forgiving" : "Standard")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(Capsule().fill(forgiving ? Color.mint.opacity(0.18) : .white.opacity(0.06)))
                }
                .accessibilityLabel("Forgiving touch mode")
                .accessibilityValue(forgiving ? "On" : "Off")
                .accessibilityIdentifier("gamepad.forgiving")
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.top, 8)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $showConnection) {
            GamepadConnectionView().environmentObject(gamepad).environmentObject(hostDiscovery)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showEditor, onDismiss: releaseAll) {
            GamepadLayoutEditor(draft: configuration) { updated in
                configuration = updated
                updated.save()
            }
        }
        .onChange(of: forgiving) { _ in releaseAll() }
        .onChange(of: showConnection) { if $0 { releaseAll() } }
        .onChange(of: scenePhase) { if $0 != .active { releaseAll() } }
        .onChange(of: gamepad.gamepadSubscribers) { _ in releaseAll() }
        .onAppear {
            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--layout-editor") { showEditor = true }
            #endif
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
        gamepad.sendGamepad(.zero)
    }
}
