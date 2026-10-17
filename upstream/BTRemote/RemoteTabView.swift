import SwiftUI

enum RemoteMode: String {
    case keyboard, remote
}

struct RemoteTabView: View {
    let goToSetup: () -> Void

    @AppStorage(AppSettings.remoteModeKey) private var mode = RemoteMode.keyboard
    @AppStorage(AppSettings.liveTypingKey) private var liveTyping = true

    var body: some View {
        #if os(macOS)
            NavigationStack { titledContent }
        #else
            NavigationView { titledContent }
                .navigationViewStyle(.stack)
        #endif
    }

    private var titledContent: some View {
        content
            .navigationTitle(L10n.Tab.remote)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { menu }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .keyboard: KeyboardView(goToSetup: goToSetup)
        case .remote: RemoteView(goToSetup: goToSetup)
        }
    }

    @ToolbarContentBuilder
    private var menu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker(L10n.Remote.mode, selection: $mode) {
                    Label(L10n.Tab.keyboard, systemImage: "keyboard").tag(RemoteMode.keyboard)
                    Label(L10n.Tab.remote, systemImage: "gamecontroller").tag(RemoteMode.remote)
                }
                if mode == .keyboard {
                    Toggle(L10n.Keyboard.liveTyping, isOn: $liveTyping)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }
}

struct NotConnectedView: View {
    let icon: String
    let goToSetup: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(L10n.Remote.notConnectedTitle)
                .font(.title2.weight(.semibold))
            Text(L10n.Remote.notConnectedMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(L10n.Remote.openSetup, action: goToSetup)
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
    #Preview {
        RemoteTabView(goToSetup: {})
    }
#endif
