import AppKit
import OSLog

/// Coordinates permission requests and prompts for Top Notch.
/// Shows inline NSAlert dialogs so users understand what is required and why.
@MainActor
final class PermissionCoordinator {
    static let shared = PermissionCoordinator()
    private init() {}

    // MARK: - Accessibility

    /// Presents an actionable alert asking the user to grant Accessibility access.
    func presentAccessibilityPrompt() {
        AppLogger.permissions.info("Presenting Accessibility permission prompt")
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Top Notch needs Accessibility access to intercept media keys (volume, brightness) and provide global keyboard shortcuts.\n\nClick \"Open System Settings\" to grant access, then relaunch Top Notch."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Skip for Now")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
            NSWorkspace.shared.open(url)
        }
    }

    /// Presents an alert when the accessibility event tap could not be created even with permission.
    func presentAccessibilityUnavailableAlert() {
        AppLogger.permissions.error("Accessibility event tap creation failed despite permission")
        let alert = NSAlert()
        alert.messageText = "Media Key Interception Unavailable"
        alert.informativeText = "Top Notch could not attach to the system event tap. Media key shortcuts will not work this session. Try relaunching the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Clipboard / YouTube Detection

    /// Presents a first-run explanation for clipboard monitoring.
    func presentClipboardMonitoringExplanation(onAccept: @escaping () -> Void) {
        AppLogger.permissions.info("Presenting clipboard monitoring consent prompt")
        let alert = NSAlert()
        alert.messageText = "YouTube Clipboard Detection"
        alert.informativeText = "Top Notch can automatically detect YouTube links from your clipboard and offer to play them directly in your notch.\n\nTop Notch only reads clipboard contents — it never uploads or shares them. You can turn this off at any time in Settings → Privacy."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Enable Detection")
        alert.addButton(withTitle: "No Thanks")

        let response = alert.runModal()
        UserDefaults.standard.set(true, forKey: "clipboardConsentAsked")
        if response == .alertFirstButtonReturn {
            UserDefaults.standard.set(true, forKey: "youtubeClipboardDetection")
            onAccept()
        } else {
            UserDefaults.standard.set(false, forKey: "youtubeClipboardDetection")
        }
    }

    // MARK: - Location (Weather)

    /// Prompts the user to enable location for weather in System Settings.
    func presentLocationPermissionPrompt() {
        AppLogger.permissions.info("Presenting Location permission prompt for weather")
        let alert = NSAlert()
        alert.messageText = "Location Access for Weather"
        alert.informativeText = "Top Notch uses your location to show local weather in your notch. Open System Settings to allow location access, then return to Top Notch."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Skip")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
            NSWorkspace.shared.open(url)
        }
    }
}
