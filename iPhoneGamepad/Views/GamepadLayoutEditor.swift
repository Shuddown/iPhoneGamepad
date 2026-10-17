import SwiftUI
import UIKit

struct GamepadLayoutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: GamepadLayoutConfiguration
    var onSave: (GamepadLayoutConfiguration) -> Void
    @State private var tool = GamepadEditTool.move
    @State private var selected = GamepadControl.a

    var body: some View {
        ZStack(alignment: .top) {
            GamepadTouchSurface(
                resetToken: 0, haptics: false, configuration: draft,
                editTool: tool, selectedControl: selected,
                onEdit: {
                    draft = $0
                    selected = $1
                }, onReport: { _ in }
            )
            .ignoresSafeArea()
            VStack(spacing: 5) {
                HStack(spacing: 16) {
                    Button("Cancel") { dismiss() }
                    Picker("Edit action", selection: $tool) {
                        ForEach(GamepadEditTool.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(width: 156)
                    Menu {
                        Picker("Control", selection: $selected) {
                            ForEach(GamepadControl.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        Button("Smaller") { resize(by: -0.1) }
                        Button("Larger") { resize(by: 0.1) }
                        Button("Reset this control") { draft.controls.removeValue(forKey: selected.rawValue) }
                    } label: {
                        Text(selected.label).fontWeight(.semibold)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .frame(minWidth: 80)
                    Button("Reset all") { draft = .init() }
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }.fontWeight(.bold)
                }
                .font(.system(size: 13)).frame(height: 40)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: Capsule())
                Text(
                    tool == .move
                        ? "Drag a control to move it. Inputs are paused."
                        : "Drag right or up to enlarge; left or down to shrink."
                )
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                .allowsHitTesting(false)
            }
            .padding(.top, 4)
        }
        .tint(.mint)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func resize(by delta: CGFloat) {
        // A menu provides a second way to resize without aiming at the selected control.
        if var placement = draft.controls[selected.rawValue] {
            placement.scale = min(2, max(0.6, placement.scale + delta))
            draft.controls[selected.rawValue] = placement
        } else {
            // Resolve the default center in the same safe area as the control surface.
            guard
                let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                    .flatMap(\.windows).first(where: \.isKeyWindow)
            else { return }
            let bounds = window.bounds.inset(by: window.safeAreaInsets).insetBy(dx: 12, dy: 10)
            guard let frame = GamepadLayout(bounds: bounds).frames[selected] else { return }
            draft.place(selected, center: CGPoint(x: frame.midX, y: frame.midY), scale: 1 + delta, in: bounds)
        }
    }
}

enum GamepadEditTool: String, CaseIterable {
    case move = "Move"
    case resize = "Resize"
}
