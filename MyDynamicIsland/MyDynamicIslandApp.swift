import OSLog
import ServiceManagement
import SwiftUI
import Foundation

@main
struct TopNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var island: DynamicIsland?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock -- overlay apps should run as accessory
        NSApp.setActivationPolicy(.accessory)

        setupMenuBarItem()
        syncLaunchAtLogin()
        island = DynamicIsland()
        runAutomatedLaunchTestIfRequested()

        // Re-sync launch-at-login and menu bar item whenever any setting changes
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncLaunchAtLogin()
            self?.syncMenuBarItem()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Never terminate just because a window closed -- we are a background overlay
        false
    }

    // MARK: - Menu Bar

    private func setupMenuBarItem() {
        guard UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            if let icon = NSImage(named: "TopNotchIcon") {
                icon.isTemplate = false
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Top Notch")
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.settings", comment: "Menu bar settings item"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.quit", comment: "Menu bar quit item"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    private func syncMenuBarItem() {
        let shouldShow = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        if shouldShow && statusItem == nil {
            setupMenuBarItem()
        } else if !shouldShow, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - Launch at Login

    private func syncLaunchAtLogin() {
        let enabled = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? true
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Login item registration can fail silently on unsigned builds
                AppLogger.lifecycle.warning("Login item registration failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Automated Testing

    private func runAutomatedLaunchTestIfRequested() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment

        if let videoID = environment["TOPNOTCH_TEST_VIDEO_ID"], !videoID.isEmpty {
            let launchDelay = TimeInterval(environment["TOPNOTCH_TEST_LAUNCH_DELAY"] ?? "1.5") ?? 1.5
            AppLogger.lifecycle.info("[TopNotchTest] Scheduling inline YouTube test for video: \(videoID, privacy: .public)")
            DispatchQueue.main.asyncAfter(deadline: .now() + launchDelay) {
                NotificationCenter.default.post(name: .openInlineYouTubeVideo, object: videoID)
            }
        }

        if let exitValue = environment["TOPNOTCH_EXIT_AFTER_TEST_SECONDS"],
           let exitDelay = TimeInterval(exitValue),
           exitDelay > 0 {
            AppLogger.lifecycle.info("[TopNotchTest] App will terminate after \(exitDelay, privacy: .public) seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
                NSApp.terminate(nil)
            }
        }
        #endif
    }
}
