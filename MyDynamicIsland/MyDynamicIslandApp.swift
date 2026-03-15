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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply "Hide from Dock" setting
        let hideFromDock = UserDefaults.standard.bool(forKey: "hideFromDock")
        if hideFromDock {
            NSApp.setActivationPolicy(.accessory)
        }

        island = DynamicIsland()
        runAutomatedLaunchTestIfRequested()
    }

    private func runAutomatedLaunchTestIfRequested() {
        let environment = ProcessInfo.processInfo.environment

        if let videoID = environment["TOPNOTCH_TEST_VIDEO_ID"], !videoID.isEmpty {
            let launchDelay = TimeInterval(environment["TOPNOTCH_TEST_LAUNCH_DELAY"] ?? "1.5") ?? 1.5
            print("[TopNotchTest] Scheduling inline YouTube test for video: \(videoID)")
            DispatchQueue.main.asyncAfter(deadline: .now() + launchDelay) {
                NotificationCenter.default.post(name: .openInlineYouTubeVideo, object: videoID)
            }
        }

        if let exitValue = environment["TOPNOTCH_EXIT_AFTER_TEST_SECONDS"],
           let exitDelay = TimeInterval(exitValue),
           exitDelay > 0 {
            print("[TopNotchTest] App will terminate after \(exitDelay) seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
                NSApp.terminate(nil)
            }
        }
    }
}
