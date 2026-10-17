#if os(macOS)
    import AppKit
    import ApplicationServices

    enum AccessibilityPermission {
        static var isTrusted: Bool {
            AXIsProcessTrusted()
        }

        static func request() {
            let promptOption = "AXTrustedCheckOptionPrompt"
            _ = AXIsProcessTrustedWithOptions([promptOption: true] as CFDictionary)

            guard let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ) else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }
#endif
