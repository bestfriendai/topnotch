import AppKit
import OSLog
import SwiftUI

/// Monitors the system clipboard for YouTube URLs and updates
/// NotchState.youtube when a valid URL is detected.
final class ClipboardCoordinator {
    private let state: NotchState
    private var clipboardTask: Task<Void, Never>?
    private var lastClipboardChangeCount: Int = 0
    private var dismissWorkItem: DispatchWorkItem?

    init(state: NotchState) {
        self.state = state
    }

    deinit {
        clipboardTask?.cancel()
    }

    // MARK: - Public API

    func start() {
        lastClipboardChangeCount = NSPasteboard.general.changeCount

        // Ask for consent on first run (App Store build defaults off)
        #if APP_STORE_BUILD
        let defaultEnabled = false
        #else
        let defaultEnabled = true
        #endif

        let consentAsked = UserDefaults.standard.bool(forKey: "clipboardConsentAsked")
        if !consentAsked && defaultEnabled {
            UserDefaults.standard.set(true, forKey: "clipboardConsentAsked")
            UserDefaults.standard.set(true, forKey: "youtubeClipboardDetection")
        }

        clipboardTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.checkClipboardForYouTubeURL() }
            }
        }
        AppLogger.clipboard.info("Clipboard monitoring started (2s interval)")
    }

    // MARK: - Private

    private func checkClipboardForYouTubeURL() {
        guard UserDefaults.standard.object(forKey: "youtubeClipboardDetection") as? Bool ?? true else { return }
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastClipboardChangeCount else { return }
        lastClipboardChangeCount = currentCount

        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }

        if YouTubeURLParser.extractVideoID(from: clipboardString) != nil {
            AppLogger.clipboard.info("YouTube URL detected in clipboard")
            state.youtube.detectedURL = clipboardString

            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                state.youtube.showPrompt = true
            }

            dismissWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if !self.state.isHovered && !self.state.youtube.isShowingPlayer {
                    withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                        self.state.youtube.showPrompt = false
                    }
                }
            }
            dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: workItem)
        }
    }
}
