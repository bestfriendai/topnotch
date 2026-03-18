import Combine
import EventKit
import SwiftUI

struct NotchContentView: View {
    @ObservedObject var state: NotchState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                NotchView(state: state)
                    .contextMenu {
                        Button(action: { showOpenYouTubeDialog() }) {
                            Label("Open YouTube Video…  ⌘⇧Y", systemImage: "play.rectangle.fill")
                        }
                        .keyboardShortcut("y", modifiers: [.command, .shift])

                        if let url = state.detectedYouTubeURL {
                            Button(action: { openYouTubeURL(url) }) {
                                Label("Play Detected Video", systemImage: "play.circle.fill")
                            }
                        }

                        if AppBuildVariant.current.supportsAdvancedMediaControls {
                            Divider()

                            Text("Media Controls (global shortcuts)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(action: {
                                MediaRemoteController.shared.togglePlayPause()
                            }) {
                                Label("Play / Pause  ⌥Space", systemImage: "playpause.fill")
                            }
                            Button(action: {
                                MediaRemoteController.shared.previousTrack()
                            }) {
                                Label("Previous Track  ⌥←", systemImage: "backward.fill")
                            }
                            Button(action: {
                                MediaRemoteController.shared.nextTrack()
                            }) {
                                Label("Next Track  ⌥→", systemImage: "forward.fill")
                            }
                        }

                        Divider()

                        Button("Settings…") { SettingsWindowController.shared.showSettings() }
                        Divider()
                        Button("Quit") { NSApp.terminate(nil) }
                    }
                Spacer()
            }
            Spacer()
        }
        .preferredColorScheme(.dark)
    }
    
    private func showOpenYouTubeDialog() {
        NSApp.activate(ignoringOtherApps: true)
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            state.activeDeckCard = .youtube
            state.showYouTubePrompt = false
            state.isExpanded = true
        }
    }
    
    private func openYouTubeURL(_ url: String) {
        if let videoID = YouTubeURLParser.extractVideoID(from: url) {
            openInlineYouTubeVideo(videoID)
        }
    }

    private func openInlineYouTubeVideo(_ videoID: String) {
        guard YouTubeURLParser.isValidVideoID(videoID) else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
            state.activeDeckCard = .youtube
            state.inlineYouTubeVideoID = videoID
            state.isShowingInlineYouTubePlayer = true
            state.showYouTubePrompt = false
            state.isExpanded = true
        }
    }
}

// MARK: - NotchView

struct NotchView: View {
    @ObservedObject var state: NotchState

    private var currentDateDayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }
    
    private var currentDateMonthDay: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date())
    }

    private func calendarEventRow(title: String, time: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotchDesign.textPrimary)
                Text(time)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchDesign.textSecondary)
            }
        }
    }

    @State private var hoverTimer: Timer?
    @State private var collapseTimer: Timer?
    @State private var audioLevels: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]
    @State private var audioTimerCancellable: AnyCancellable?
    @State private var youtubeURLInput = ""
    @State private var youtubeInputError: String?
    @StateObject private var youtubeHistory = YouTubeHistoryStore()
    @State private var deckDragOffset: CGFloat = 0

    @State private var isClickExpanded = false
    @State private var chargingGlowPulse = false
    @State private var gearHovered = false
    @State private var chevronHovered = false
    @StateObject private var weatherStore = NotchWeatherStore()
    @ObservedObject private var calendarStore = CalendarStore.shared

    @AppStorage("hudDisplayMode") private var hudDisplayMode = "progressBar"
    @AppStorage("showLockIndicator") private var showLockIndicator = true
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("showHapticFeedback") private var hapticFeedbackEnabled = true
    @AppStorage("notchWeatherCity") private var weatherCity = "San Francisco"
    @AppStorage("youtubeEnabled") private var youtubeEnabled = true
    @AppStorage("weatherEnabled") private var weatherEnabled = true
    @AppStorage("calendarEnabled") private var calendarEnabled = true
    @AppStorage("pomodoroEnabled") private var pomodoroEnabled = true
    @AppStorage("clipboardEnabled") private var clipboardEnabled = true

    private let deckHeight: CGFloat = 186
    private let deckCardSpacing: CGFloat = 14

    private var youtubePreviewVideoID: String? {
        youtubeDraftRequest?.videoID
    }

    private var youtubeDraftRequest: YouTubeURLParser.PlaybackRequest? {
        YouTubeURLParser.playbackRequest(from: youtubeURLInput)
    }

    private var shouldShowDeck: Bool {
        state.isExpanded
            && state.hud == .none
            && !state.isShowingInlineYouTubePlayer
            && !state.showChargingAnimation
            && !state.showUnplugAnimation
            && !state.showUnlockAnimation
            && !state.isScreenLocked
    }

    private var audioTimerPublisher: AnyPublisher<Date, Never> {
        Timer.publish(every: 0.15, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
    }

    private var isMinimalMode: Bool { hudDisplayMode == "minimal" }

    private var activeDeckAccent: Color {
        switch state.activeDeckCard {
        case .weather: return Color(hex: "38BDF8")
        case .calendar: return Color(hex: "FB7185")
        case .pomodoro: return Color(hex: "F59E0B")
        case .clipboard: return Color(hex: "60A5FA")
        case .youtube: return Color(hex: "FF453A")
        case .home: return Color(hex: "30D158")
        case .fileShelf: return Color.orange
        case .media: return Color(hex: "1DB954")
        }
    }

    // Design-spec collapsed dimensions
    private let collapsedNotchWidth: CGFloat = 480
    private let collapsedNotchHeight: CGFloat = 36
    private let collapsedCornerRadius: CGFloat = 20
    private let expandedDashboardWidth: CGFloat = 960
    private let expandedDashboardHeight: CGFloat = 320

    private func focusedHeightForCard(_ card: NotchDeckCard) -> CGFloat {
        switch card {
        case .youtube: return 260
        case .media: return 320
        case .weather: return 300
        case .calendar: return 320
        case .pomodoro: return 320
        case .clipboard: return 280
        case .fileShelf: return 200
        case .home: return 0
        }
    }

    private var notchSize: CGSize {
        if state.isShowingInlineYouTubePlayer && !state.inlineYouTubeMinimized {
            return CGSize(
                width: max(collapsedNotchWidth, state.youtubePlayerWidth + 32),
                height: collapsedNotchHeight + state.youtubePlayerHeight + 80
            )
        }

        if shouldShowDeck && isClickExpanded {
            let isFocused = state.activeDeckCard != .home
            // Height: collapsed bar + deck header + fixed card height + bottom padding
            let cardHeight = focusedHeightForCard(state.activeDeckCard)
            let focusedHeight = collapsedNotchHeight + 42 + cardHeight + 24
            return CGSize(
                width: isFocused ? 800 : expandedDashboardWidth,
                height: isFocused ? focusedHeight : expandedDashboardHeight
            )
        }

        // System HUDs and Alerts dimensions
        if case .volume = state.hud {
            return CGSize(width: collapsedNotchWidth, height: collapsedNotchHeight + 44)
        }
        if case .brightness = state.hud {
            return CGSize(width: collapsedNotchWidth, height: collapsedNotchHeight + 44)
        }
        if state.showYouTubePrompt {
            // YouTube detected: spec says height 44pt total
            return CGSize(width: collapsedNotchWidth, height: 44)
        }
        if state.showChargingAnimation || (state.battery.isCharging && state.isExpanded) {
            return CGSize(width: collapsedNotchWidth, height: collapsedNotchHeight + 56)
        }
        if state.isScreenLocked || state.showUnlockAnimation {
            return CGSize(width: 220, height: collapsedNotchHeight + 56)
        }

        let shouldExpand = !isMinimalMode || state.hud == .none
        var expandedHeight: CGFloat = 0
        if state.isExpanded && shouldExpand {
            // Larger height for media controls with scrubber
            if case .music = state.activity {
                expandedHeight = 85
            } else {
                expandedHeight = 75
            }
        }

        return CGSize(width: collapsedNotchWidth, height: collapsedNotchHeight + expandedHeight)
    }

    private var currentCornerRadius: CGFloat {
        state.isExpanded ? NotchDesign.islandRadius : collapsedCornerRadius
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background fill: #0B0B0E always (spec)
            RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                .fill(NotchDesign.bgMain)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            .white.opacity(0.05),
                            activeDeckAccent.opacity(state.isExpanded ? 0.18 : 0.06),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .frame(height: collapsedNotchHeight)
                    .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
                // Spec: stroke #2A2A2E 1pt inside
                .overlay(
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .strokeBorder(
                            NotchDesign.borderSubtle,
                            lineWidth: 1
                        )
                )

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    collapsedContent.frame(height: collapsedNotchHeight)

                    if state.isExpanded {
                        expandedContent
                            .clipped()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .top)).combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                            ))
                    }
                }

                // Keep the YouTube WKWebView alive while minimized so audio
                // continues and the collapsed-bar play/pause button still works.
                if state.inlineYouTubeMinimized && !state.isExpanded,
                   state.isShowingInlineYouTubePlayer,
                   let videoID = state.inlineYouTubeVideoID {
                    YouTubePlayerWebView(
                        videoID: videoID,
                        startTime: Int(state.inlineYouTubePlayerState.currentTime),
                        playerState: state.inlineYouTubePlayerState,
                        playerController: state.inlineYouTubePlayerController
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(
            width: state.inlineYouTubeMinimized && !state.isExpanded ? 520 : notchSize.width,
            height: notchSize.height
        )
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.activeDeckCard)
        .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
        .scaleEffect(state.isHovered && !state.isExpanded && !state.inlineYouTubeMinimized ? 1.05 : 1.0, anchor: .top)
        .shadow(color: activeDeckAccent.opacity(state.isExpanded ? 0.18 : 0.05), radius: state.isExpanded ? 28 : 12, y: state.isExpanded ? 10 : 4)
        .shadow(color: .black.opacity(state.isExpanded ? 0.36 : 0.37), radius: state.isExpanded ? 24 : 16, y: state.isExpanded ? 12 : 4)
        .background(
            Group {
                if state.isExpanded && shouldShowDeck && isClickExpanded {
                    ZStack {
                        // Core background
                        RoundedRectangle(cornerRadius: NotchDesign.islandRadius, style: .continuous)
                            .fill(NotchDesign.bgMain)
                        
                        // Subtle inner glow
                        RadialGradient(
                            colors: [activeDeckAccent.opacity(0.15), .clear],
                            center: .top,
                            startRadius: 0,
                            endRadius: 400
                        )
                        .blendMode(.screen)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: NotchDesign.islandRadius, style: .continuous))
                    .transition(.opacity)
                }
            }
        )
        .animation(.spring(duration: 0.45, bounce: 0.3), value: state.isExpanded)
        .animation(.spring(duration: 0.45, bounce: 0.3), value: isClickExpanded)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: state.isHovered)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: state.hud)
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            if state.inlineYouTubeMinimized && !state.isExpanded {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    state.inlineYouTubeMinimized = false
                    state.isExpanded = true
                }
            } else if isClickExpanded && !shouldShowDeck {
                // Tapping collapsed area when click-expanded - close
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    state.isExpanded = false
                    isClickExpanded = false
                    state.hud = .none
                }
            } else if state.showYouTubePrompt && !state.isExpanded {
                // YouTube prompt is showing — tapping the notch body plays the detected video
                playDetectedVideo()
            } else if !state.isShowingInlineYouTubePlayer && !state.isExpanded { handleTap() }
        }
        .onHover { handleHover($0) }
        .onChange(of: state.activity) { _, newActivity in
            if case .music = newActivity { startAudioTimer() } else { stopAudioTimer() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("refreshWeather"))) { _ in
            refreshWeatherIfNeeded(force: true)
        }
        .onAppear { if case .music = state.activity { startAudioTimer() } }
        .onDisappear {
            stopAudioTimer()
            hoverTimer?.invalidate()
            hoverTimer = nil
            collapseTimer?.invalidate()
            collapseTimer = nil
        }
        .onChange(of: state.hud) { _, newValue in if newValue != .none { showHUD() } }
        .onChange(of: state.showUnlockAnimation) { _, newValue in
            if newValue {
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) { state.isExpanded = true }
                unlockScale = 0.5
                unlockOpacity = 0
                scheduleCollapse(delay: 2.0)
            }
        }
        .onChange(of: state.isScreenLocked) { _, isLocked in
            if isLocked {
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    state.isExpanded = true
                    scheduleCollapse(delay: 1.5)
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: state.isScreenLocked)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: state.showUnlockAnimation)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: state.showYouTubePrompt)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: state.activity)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.battery.isCharging)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.showChargingAnimation)
    }

    // Design spec: 180pt camera spacer in center
    private let cameraSpacerWidth: CGFloat = 180

    @ViewBuilder
    private var collapsedContent: some View {
        HStack(spacing: 0) {
            // Left wing
            HStack(spacing: 6) {
                if isMinimalMode, case .volume(let level, let muted) = state.hud {
                    Image(systemName: muted ? "speaker.slash.fill" : volumeIcon(for: level))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(muted ? .gray : .white)
                } else if isMinimalMode, case .brightness = state.hud {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.yellow)
                } else {
                    leftIndicator
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 16)
            .clipped()

            // Camera notch spacer - 180pt per design spec
            Color.clear.frame(width: cameraSpacerWidth)

            // Right wing
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                if isMinimalMode, case .volume(let level, let muted) = state.hud {
                    Text(muted ? "Mute" : "\(Int(level * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(muted ? .gray : .white)
                        .monospacedDigit()
                } else if isMinimalMode, case .brightness(let level) = state.hud {
                    Text("\(Int(level * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .monospacedDigit()
                } else {
                    rightIndicator
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 16)
            .clipped()
        }
    }

    private func volumeIcon(for level: CGFloat) -> String {
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    @ViewBuilder
    private var leftIndicator: some View {
        if state.isScreenLocked && showLockIndicator {
            LockIconView()
        } else if state.showUnlockAnimation && showLockIndicator {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
                .shadow(color: .green.opacity(0.8), radius: 6)
                .transition(.scale.combined(with: .opacity))
        } else if (state.battery.isCharging || state.showChargingAnimation) && showBatteryIndicator && !state.isExpanded {
            // Spec: Battery icon + "Charging" text (#32D583) on left
            HStack(spacing: 5) {
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotchDesign.green)
                Text("Charging")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchDesign.green)
                    .lineLimit(1)
                    .fixedSize()
            }
            .transition(.scale.combined(with: .opacity))
        } else if case .music = state.activity {
            // Album art thumbnail + song title
            HStack(spacing: 6) {
                MiniArtworkView()
                Text(MediaRemoteController.shared.nowPlayingInfo.title.isEmpty ? "Music" : MediaRemoteController.shared.nowPlayingInfo.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 100, alignment: .leading)
            }
            .transition(.scale.combined(with: .opacity))
        } else if case .timer = state.activity {
            // Spec: Orange dot (6pt) + "FOCUS" text (#FF9F0A, 10pt, weight 600, letterSpacing 1)
            HStack(spacing: 5) {
                Circle()
                    .fill(NotchDesign.orange)
                    .frame(width: 6, height: 6)
                Text("FOCUS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchDesign.orange)
                    .tracking(1)
            }
            .transition(.scale.combined(with: .opacity))
        } else if state.showYouTubePrompt {
            // YouTube Detected collapsed indicator: play circle + text
            HStack(spacing: 6) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchDesign.red)
                Text("YouTube Link Detected")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(1)
            }
            .transition(.scale.combined(with: .opacity))
        } else if state.inlineYouTubeMinimized {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 18, height: 12)
                    Image(systemName: "play.fill")
                        .font(.system(size: 5, weight: .bold))
                        .foregroundStyle(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.red.opacity(0.85))
                            .frame(width: max(geo.size.width * state.inlineYouTubeProgress, 0))
                    }
                }
                .frame(height: 3)
                .frame(maxWidth: 120)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if !shouldShowDeck {
            // Idle state: brand text - spec: #6B6B70, 12pt, weight 600 (semibold)
            Text("Top Notch")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchDesign.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .transition(.opacity)
        }
    }

    @State private var waveformBars: [CGFloat] = [0.3, 0.6, 0.4]

    @ViewBuilder
    private var rightIndicator: some View {
        if state.isScreenLocked && showLockIndicator {
            LockPulsingDot()
        } else if state.showUnlockAnimation && showLockIndicator {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        } else if (state.showChargingAnimation || state.battery.isCharging) && showBatteryIndicator && !state.isExpanded {
            // Spec: percentage + zap icon on right for charging state
            HStack(spacing: 3) {
                Text("\(state.battery.level)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchDesign.green)
                    .monospacedDigit()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NotchDesign.green)
            }
            .transition(.scale.combined(with: .opacity))
        } else if state.showUnplugAnimation && showBatteryIndicator {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
                .transition(.scale.combined(with: .opacity))
        } else if case .music = state.activity {
            // 3 animated green waveform bars
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(NotchDesign.green)
                        .frame(width: 3, height: waveformBars[i] * 14)
                }
            }
            .onReceive(Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    waveformBars = (0..<3).map { _ in CGFloat.random(in: 0.3...1.0) }
                }
            }
            .transition(.scale.combined(with: .opacity))
        } else if case .timer(let remaining, let total) = state.activity {
            // Countdown time + small progress arc
            HStack(spacing: 6) {
                Text(formatTime(remaining))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .monospacedDigit()
                ZStack {
                    Circle()
                        .stroke(NotchDesign.orange.opacity(0.2), lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining / max(total, 1)))
                        .stroke(NotchDesign.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(-90))
                }
            }
        } else if state.showYouTubePrompt {
            // YouTube Detected: red play button on right
            Button(action: { playDetectedVideo() }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(NotchDesign.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .transition(.scale.combined(with: .opacity))
        } else if state.inlineYouTubeMinimized {
            Button(action: { state.inlineYouTubePlayerController.togglePlayPause() }) {
                Image(systemName: state.inlineYouTubeIsPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .transition(.scale.combined(with: .opacity))
        } else if !shouldShowDeck {
            // Idle state: Battery indicator - spec: 32x14, cornerRadius 4, #32D583
            if showBatteryIndicator {
                CollapsedBatteryIndicator(level: state.battery.level)
                    .transition(.opacity)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(NotchDesign.green.opacity(0.6))
                        .frame(width: 4, height: 4)
                    Text("Active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        Group {
            switch state.hud {
            case .volume(let level, let muted):
                volumeHUD(level: level, muted: muted)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            case .brightness(let level):
                brightnessHUD(level: level)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            case .none:
                if state.isShowingInlineYouTubePlayer, let videoID = state.inlineYouTubeVideoID {
                    inlineYouTubePlayer(videoID: videoID)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                else if isClickExpanded {
                    // Full dashboard on click — highest priority after inline player
                    dynamicDeck
                }
                // YouTube prompt is now shown inline in collapsed content (spec: 44pt height)
                else if state.showChargingAnimation && showBatteryIndicator {
                    BatteryChargingAlert(level: state.battery.level, notchWidth: state.notchWidth)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                else if state.showUnplugAnimation && showBatteryIndicator {
                    unplugExpanded
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                else if state.showUnlockAnimation && showLockIndicator {
                    LockScreenIndicatorView()
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                else if state.isScreenLocked && showLockIndicator {
                    LockScreenIndicatorView()
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                else {
                    // Compact controls on hover
                    Group {
                        switch state.activity {
                        case .music(let app): musicExpanded(app: app)
                        case .timer(let remaining, _): timerExpanded(remaining: remaining)
                        case .none: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func volumeHUD(level: CGFloat, muted: Bool) -> some View {
        if hudDisplayMode == "notched" { NotchedVolumeHUD(level: level, muted: muted) }
        else { ProgressBarVolumeHUD(level: level, muted: muted) }
    }

    @ViewBuilder
    private func brightnessHUD(level: CGFloat) -> some View {
        if hudDisplayMode == "notched" { NotchedBrightnessHUD(level: level) }
        else { ProgressBarBrightnessHUD(level: level) }
    }

    @State private var lockPulse = false

    private var lockedExpanded: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.2)).frame(width: 44, height: 44)
                    .scaleEffect(lockPulse ? 1.2 : 1.0).opacity(lockPulse ? 0.5 : 0.8)
                Image(systemName: "lock.fill").font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.orange).shadow(color: .orange.opacity(0.5), radius: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Locked").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("Touch ID or enter password").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Circle().fill(Color.orange).frame(width: 8, height: 8).shadow(color: .orange, radius: 4).scaleEffect(lockPulse ? 1.3 : 1.0)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { lockPulse = true } }
        .onDisappear { lockPulse = false }
    }

    @State private var unlockScale: CGFloat = 0.5
    @State private var unlockOpacity: CGFloat = 0

    private var unlockExpanded: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(RadialGradient(colors: [.green.opacity(0.3), .green.opacity(0.1), .clear], center: .center, startRadius: 0, endRadius: 30))
                    .frame(width: 50, height: 50).scaleEffect(unlockScale).opacity(unlockOpacity)
                Image(systemName: "lock.open.fill").font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.green).shadow(color: .green.opacity(0.5), radius: 8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Unlocked").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                Text("Welcome back!").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.green).scaleEffect(unlockScale)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.5)) { unlockScale = 1.2; unlockOpacity = 1 }
            withAnimation(.spring(duration: 0.3, bounce: 0.2).delay(0.3)) { unlockScale = 1.0 }
        }
    }

    @State private var chargingBoltScale: CGFloat = 0.5
    @State private var chargingGlow = false

    private var chargingExpanded: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(RadialGradient(colors: [.green.opacity(0.4), .green.opacity(0.1), .clear], center: .center, startRadius: 0, endRadius: 35))
                    .frame(width: 60, height: 60).scaleEffect(chargingGlow ? 1.3 : 1.0).opacity(chargingGlow ? 0.5 : 0.8)
                Image(systemName: "bolt.fill").font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.green).shadow(color: .green.opacity(0.7), radius: 10).scaleEffect(chargingBoltScale)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Charging").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text("\(state.battery.level)%").font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.green).monospacedDigit()
                    BatteryBarView(level: state.battery.level, isCharging: true)
                }
            }
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { chargingBoltScale = 1.2 }
            withAnimation(.spring(duration: 0.3).delay(0.2)) { chargingBoltScale = 1.0 }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { chargingGlow = true }
        }
        .onDisappear { chargingBoltScale = 0.5; chargingGlow = false }
    }

    @State private var unplugScale: CGFloat = 1.2

    private var unplugExpanded: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.gray.opacity(0.2)).frame(width: 50, height: 50)
                Image(systemName: "powerplug.fill").font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.gray).scaleEffect(unplugScale)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Unplugged").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text("\(state.battery.level)%").font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(state.battery.level <= 20 ? .red : .white.opacity(0.7)).monospacedDigit()
                    if let time = state.battery.timeRemaining, time > 0 {
                        Text("• \(formatBatteryTime(time)) remaining").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            Spacer()
            BatteryBarView(level: state.battery.level, isCharging: false)
        }
        .onAppear { withAnimation(.spring(duration: 0.4, bounce: 0.3)) { unplugScale = 1.0 } }
        .onDisappear { unplugScale = 1.2 }
    }

    private func formatBatteryTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    private func handleTap() {
        guard !state.isShowingInlineYouTubePlayer else { return }
        hoverTimer?.invalidate()
        collapseTimer?.invalidate()
        if hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
            state.activeDeckCard = .home  // Always open to home dashboard
            state.isExpanded = true
            isClickExpanded = true
        }
        // Don't auto-collapse on click - user will manually close via chevron
    }

    private func handleHover(_ hovering: Bool) {
        if state.isShowingInlineYouTubePlayer {
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) { state.isHovered = hovering }
            return
        }

        hoverTimer?.invalidate()
        if hovering && hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
        withAnimation(.spring(duration: 0.25, bounce: 0.4)) { state.isHovered = hovering }

        if hovering {
            // Only hover-expand if not already click-expanded
            if !isClickExpanded {
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
                    guard UserDefaults.standard.object(forKey: "expandOnHover") as? Bool ?? true else { return }
                    withAnimation(.spring(duration: 0.5, bounce: 0.35)) { self.state.isExpanded = true }
                    if self.hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
                }
            }
        } else {
            // Only collapse on hover-exit if NOT click-expanded
            if !isClickExpanded {
                collapseTimer?.invalidate()
                collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        self.state.isExpanded = false
                        self.state.hud = .none
                    }
                }
            }
        }
    }

    private func scheduleCollapse(delay: TimeInterval) {
        guard !state.isShowingInlineYouTubePlayer else { return }
        collapseTimer?.invalidate()
        // Use explicit delay when > 0; otherwise fall back to user preference
        let storedDelay = (UserDefaults.standard.object(forKey: "autoCollapseDelay") as? Int).map(Double.init) ?? (UserDefaults.standard.object(forKey: "autoCollapseDelay") as? Double) ?? 4.0
        let effectiveDelay = delay > 0 ? delay : storedDelay
        guard effectiveDelay > 0 else { return }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: effectiveDelay, repeats: false) { [self] _ in
            if !self.state.isHovered {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    self.state.isExpanded = false
                    self.isClickExpanded = false
                    self.state.hud = .none
                }
            }
        }
    }

    private func showHUD() {
        guard !state.isShowingInlineYouTubePlayer else { return }
        collapseTimer?.invalidate()
        if !isMinimalMode {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { state.isExpanded = true }
        }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                if !self.state.isHovered && !self.isMinimalMode { self.state.isExpanded = false; self.isClickExpanded = false }
                self.state.hud = .none
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func musicIcon(for app: String) -> String {
        switch app {
        case "Spotify": return "beats.headphones"
        case "Music": return "music.note"
        case "Safari", "Chrome", "Firefox", "Arc": return "play.circle.fill"
        default: return "music.note"
        }
    }

    private func musicExpanded(app: String) -> some View {
        Group {
            if MediaRemoteController.shared.nowPlayingInfo.title.isEmpty {
                // Stub / no-data state
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.purple.opacity(0.7))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Play music to see controls")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(app)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
            } else {
                MediaControlView()
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        ))
    }

    private func inlineYouTubePlayer(videoID: String) -> some View {
        NotchInlineYouTubePlayerView(
            notchState: state,
            videoID: videoID,
            playerState: state.inlineYouTubePlayerState,
            playerController: state.inlineYouTubePlayerController,
            startTime: state.inlineYouTubeStartTime
        )
        .id(videoID)
        .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
            ))
    }

    private func timerExpanded(remaining: TimeInterval) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: "timer").font(.system(size: 20, weight: .medium)).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Timer").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(formatTime(remaining)).font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange).monospacedDigit()
            }
            Spacer()
        }
    }

    private var defaultExpanded: some View { dynamicDeck }

    @State private var deckCardsAppeared = false
    @State private var deckContentAppeared = false
    @State private var hoveringCard: Int? = nil
    @State private var hoveringIcon: String? = nil

    private var notchHubView: some View {
        VStack(spacing: 10) {
            // 3 large cards in horizontal layout
            HStack(spacing: 10) {
                // 1. YouTube Hero Card (width 340)
                youtubeHeroCard
                    .frame(width: 340)
                    .staggeredEntrance(index: 0, appeared: deckCardsAppeared)

                // 2. Now Playing Card (width 260)
                nowPlayingHubCard
                    .frame(width: 260)
                    .staggeredEntrance(index: 1, appeared: deckCardsAppeared)

                // 3. Weather + Calendar Combo Card (fill remaining)
                weatherCalendarComboCard
                    .staggeredEntrance(index: 2, appeared: deckCardsAppeared)
            }
            .frame(maxHeight: .infinity)

            // Page indicator dots
            HStack(spacing: 6) {
                ForEach(Array(deckCardOrder.enumerated()), id: \.offset) { idx, card in
                    let isActive = state.activeDeckCard == card
                    Circle()
                        .fill(isActive ? NotchDesign.textPrimary : NotchDesign.borderStrong)
                        .frame(width: isActive ? 6 : 5, height: isActive ? 6 : 5)
                        .animation(.spring(duration: 0.3), value: isActive)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - YouTube Hero Card
    private var youtubeHeroCard: some View {
        NotchCardShell(accent: .red, isFocused: false) {
            VStack(alignment: .leading, spacing: 10) {
                // Header — tapping navigates to focused YouTube view
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                    Text("YouTube")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { navigateToDeckCard(.youtube) }

                // Video thumbnail area — tapping navigates to focused YouTube view
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                        .frame(height: 100)
                    if let previewID = youtubePreviewVideoID {
                        AsyncImage(url: YouTubeURLParser.thumbnailURL(for: previewID, quality: .high)) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                        }
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.15))
                    }
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { navigateToDeckCard(.youtube) }

                // URL text field
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                    TextField("Paste YouTube URL or video ID...", text: $youtubeURLInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchDesign.textPrimary)
                        .onSubmit { handleYouTubeInputSubmit() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(NotchDesign.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(NotchDesign.borderSubtle, lineWidth: 0.5)
                )

                // Buttons row
                HStack(spacing: 8) {
                    Button(action: handleBrowseOrPlay) {
                        Text(youtubeDraftRequest != nil ? "Play" : "Browse")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let url = URL(string: "https://www.youtube.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Safari")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchDesign.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(NotchDesign.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(NotchDesign.borderSubtle, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if let err = youtubeInputError {
                    Text(err)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.red.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Now Playing Hub Card
    private var nowPlayingHubCard: some View {
        NotchCardShell(accent: NotchDesign.spotify, isFocused: false) {
            VStack(spacing: 10) {
                let info = MediaRemoteController.shared.nowPlayingInfo

                // Album artwork
                if let artworkImage = info.artwork {
                    Image(nsImage: artworkImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(NotchDesign.elevated)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(NotchDesign.textTertiary)
                        )
                }

                // Song title + artist
                VStack(spacing: 3) {
                    Text(info.title.isEmpty ? "Not Playing" : info.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(info.artist.isEmpty ? "No artist" : info.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchDesign.textSecondary)
                            .lineLimit(1)
                        if !info.artist.isEmpty {
                            Image(systemName: "beats.headphones")
                                .font(.system(size: 9))
                                .foregroundStyle(NotchDesign.spotify)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Play/Prev/Next controls
                HStack(spacing: 20) {
                    Button(action: { MediaRemoteController.shared.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(NotchDesign.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { MediaRemoteController.shared.togglePlayPause() }) {
                        Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(NotchDesign.elevated, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { MediaRemoteController.shared.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(NotchDesign.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onTapGesture { navigateToDeckCard(.media) }
    }

    // MARK: - Weather + Calendar Combo Card
    private var weatherCalendarComboCard: some View {
        NotchCardShell(accent: NotchDesign.blue, isFocused: false) {
            VStack(spacing: 0) {
                // Top half: Weather
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weatherStore.temperatureText)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.4), value: weatherStore.temperatureText)
                        Text(weatherStore.conditionText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchDesign.textSecondary)
                            .lineLimit(1)
                        if let hi = weatherStore.highTemp, let lo = weatherStore.lowTemp {
                            HStack(spacing: 6) {
                                Text("H:\(hi)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(NotchDesign.orange)
                                Text("L:\(lo)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                    Spacer()
                    AnimatedWeatherIcon(
                        symbolName: weatherStore.symbolName,
                        weatherCode: weatherStore.weatherCode,
                        size: 30
                    )
                }
                .onTapGesture { navigateToDeckCard(.weather) }

                // Divider
                Rectangle()
                    .fill(NotchDesign.borderSubtle)
                    .frame(height: 1)
                    .padding(.vertical, 8)

                // Bottom half: Calendar
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(currentDateMonthDay.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NotchDesign.textSecondary)
                        Text(currentDateDayName.prefix(3).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NotchDesign.textTertiary)
                    }

                    if calendarStore.events.isEmpty {
                        Text("No upcoming events")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchDesign.textTertiary)
                    } else {
                        ForEach(calendarStore.events.prefix(2), id: \.eventIdentifier) { event in
                            calendarEventRow(
                                title: event.title ?? "Event",
                                time: event.startDate.formatted(date: .omitted, time: .shortened),
                                color: Color(cgColor: event.calendar.cgColor)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture { navigateToDeckCard(.calendar) }

                Spacer(minLength: 0)
            }
        }
    }

    /// Ordered list of deck cards for swipe navigation, filtered by enabled settings
    private var deckCardOrder: [NotchDeckCard] {
        var cards: [NotchDeckCard] = [.home]
        if youtubeEnabled { cards.append(.youtube) }
        cards.append(.media) // Media is always available
        if weatherEnabled { cards.append(.weather) }
        if calendarEnabled { cards.append(.calendar) }
        if pomodoroEnabled { cards.append(.pomodoro) }
        if clipboardEnabled { cards.append(.clipboard) }
        return cards
    }

    private func deckCardIndex(for card: NotchDeckCard) -> Int {
        deckCardOrder.firstIndex(of: card) ?? 0
    }

    private var dynamicDeck: some View {
        VStack(spacing: 0) {
            deckHeader

            if state.activeDeckCard == .home {
                notchHubView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .center))
                    ))
            } else {
                focusedCardContent
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .offset(x: deckDragOffset)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let currentIndex = deckCardIndex(for: state.activeDeckCard)
                    deckDragOffset = DeckPagingLogic.resistedOffset(
                        translationWidth: value.translation.width,
                        currentIndex: currentIndex,
                        cardCount: deckCardOrder.count
                    )
                }
                .onEnded { value in
                    let currentIndex = deckCardIndex(for: state.activeDeckCard)
                    let targetIdx = DeckPagingLogic.targetIndex(
                        currentIndex: currentIndex,
                        cardCount: deckCardOrder.count,
                        translationWidth: value.translation.width,
                        predictedEndTranslationWidth: value.predictedEndTranslation.width,
                        pageWidth: 400
                    )
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        deckDragOffset = 0
                        state.activeDeckCard = deckCardOrder[targetIdx]
                    }
                }
        )
        .animation(.spring(duration: 0.4, bounce: 0.25), value: state.activeDeckCard)
        .animation(.interactiveSpring(), value: deckDragOffset)
        .onAppear {
            prefillYouTubeInputIfPossible()
            refreshWeatherIfNeeded()
            deckContentAppeared = true
            deckCardsAppeared = true
        }
        .onChange(of: state.activeDeckCard) { _, newCard in
            if newCard == .youtube { prefillYouTubeInputIfPossible() }
            if newCard == .weather { refreshWeatherIfNeeded(force: weatherStore.cityName != weatherCity) }
        }
    }

    // MARK: - Focused: single card full-width

    @ViewBuilder
    private var focusedCardContent: some View {
        Group {
            switch state.activeDeckCard {
            case .media:
                MediaFocusedView()
            case .weather:
                WeatherFocusedView(weatherStore: weatherStore)
            case .calendar:
                focusedCardShell(accentTop: Color(red: 0.22, green: 0.08, blue: 0.15)) { CalendarFocusedView() }
            case .pomodoro:
                focusedCardShell(accentTop: Color(red: 0.22, green: 0.16, blue: 0.04)) { PomodoroFocusedView() }
            case .clipboard:
                focusedCardShell(accentTop: Color(red: 0.08, green: 0.15, blue: 0.25)) { ClipboardFocusedView() }
            case .fileShelf:
                focusedCardShell(accentTop: .orange) { FileShelfDeckCard() }
            case .youtube:
                youtubeFocusedContent
            case .home:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: focusedHeightForCard(state.activeDeckCard))
        .clipped()
    }

    private func focusedCardShell<Content: View>(accentTop: Color = Color(red: 0.15, green: 0.15, blue: 0.18), @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - YouTube Recently Played helpers

    @ViewBuilder
    private var recentlyPlayedRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECENTLY PLAYED")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))
                .tracking(1)
            VStack(spacing: 3) {
                ForEach(youtubeHistory.items.prefix(3)) { item in
                    Button(action: { openInlineVideo(item.videoID) }) {
                        HStack(spacing: 7) {
                            AsyncImage(url: YouTubeURLParser.thumbnailURL(for: item.videoID, quality: .default)) { phase in
                                if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                                else { Rectangle().fill(Color.red.opacity(0.12)) }
                            }
                            .frame(width: 34, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(item.videoID)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var recentlyPlayedPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENTLY PLAYED")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))
                .tracking(1)
            VStack(spacing: 4) {
                ForEach(youtubeHistory.items) { item in
                    Button(action: { openInlineVideo(item.videoID) }) {
                        HStack(spacing: 8) {
                            AsyncImage(url: YouTubeURLParser.thumbnailURL(for: item.videoID, quality: .default)) { phase in
                                if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                                else { Rectangle().fill(Color.red.opacity(0.12)) }
                            }
                            .frame(width: 48, height: 27)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            Text(item.videoID)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 170)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .trailing)))
    }

    private var youtubeFocusedContent: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left: input + actions
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NotchDesign.red)
                    Text("YouTube")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                    Spacer()
                }

                // Input field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                    TextField("Paste YouTube URL or video ID...", text: $youtubeURLInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotchDesign.textPrimary)
                        .onSubmit { handleYouTubeInputSubmit() }
                    if !youtubeURLInput.isEmpty {
                        Button(action: { youtubeURLInput = ""; youtubeInputError = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(NotchDesign.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NotchDesign.elevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NotchDesign.borderSubtle, lineWidth: 1)
                )

                if let err = youtubeInputError {
                    Text(err)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchDesign.red.opacity(0.8))
                }

                // Thumbnail preview
                if let previewID = youtubePreviewVideoID {
                    AsyncImage(url: YouTubeURLParser.thumbnailURL(for: previewID, quality: .high)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default:
                            ZStack {
                                Rectangle().fill(NotchDesign.red.opacity(0.08))
                                ProgressView().tint(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))
                }

                // Action buttons
                HStack(spacing: 10) {
                    Button(action: handleBrowseOrPlay) {
                        HStack(spacing: 6) {
                            Image(systemName: youtubeDraftRequest != nil ? "play.fill" : "globe")
                                .font(.system(size: 12, weight: .semibold))
                            Text(youtubeDraftRequest != nil ? "Play Video" : "Browse")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(height: 36)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(NotchDesign.red)
                        )
                    }
                    .buttonStyle(.plain)

                    if let _ = clipboardYouTubeURL, youtubeURLInput.isEmpty {
                        Button(action: { pasteClipboardYouTubeURL(); handleBrowseOrPlay() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Paste & Play")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(NotchDesign.red)
                            .frame(height: 36)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(NotchDesign.red.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(NotchDesign.red.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    if !youtubeURLInput.isEmpty {
                        Button(action: openYouTubeInputInSafari) {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Safari")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(NotchDesign.blue)
                            .frame(height: 36)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(NotchDesign.blue.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)

            // Right: recently played panel
            if !youtubeHistory.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECENTLY PLAYED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NotchDesign.textTertiary)
                        .tracking(0.8)

                    VStack(spacing: 6) {
                        ForEach(youtubeHistory.items.prefix(3)) { item in
                            Button(action: { openInlineVideo(item.videoID) }) {
                                HStack(spacing: 8) {
                                    AsyncImage(url: YouTubeURLParser.thumbnailURL(for: item.videoID, quality: .default)) { phase in
                                        if case .success(let img) = phase {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(NotchDesign.red.opacity(0.12))
                                        }
                                    }
                                    .frame(width: 52, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                    Text(item.videoID)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(NotchDesign.textMuted)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer(minLength: 0)

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(NotchDesign.textSecondary)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(NotchDesign.elevated)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: 200)
            }
        }
        .padding(20)
    }
    private func navigateToDeckCard(_ card: NotchDeckCard) {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            state.activeDeckCard = card
        }
    }

    private var deckHeader: some View {
        HStack(spacing: 0) {
            // Left: Home icon + label + separator + nav icons
            HStack(spacing: 2) {
                navHeaderButton(systemName: "house.fill", card: .home)

                // Thin separator
                Rectangle()
                    .fill(NotchDesign.borderSubtle)
                    .frame(width: 1, height: 18)
                    .padding(.horizontal, 4)

                if youtubeEnabled { navHeaderButton(systemName: "play.rectangle.fill", card: .youtube) }
                navHeaderButton(systemName: "music.note", card: .media)
                if weatherEnabled { navHeaderButton(systemName: "cloud.sun.fill", card: .weather) }
                if calendarEnabled { navHeaderButton(systemName: "calendar", card: .calendar) }
                if pomodoroEnabled { pomodoroNavButton }
                if clipboardEnabled { navHeaderButton(systemName: "doc.on.clipboard", card: .clipboard) }
            }
            .padding(4)
            .background(NotchDesign.elevated.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))

            Spacer()

            // Right: Time + gear + collapse
            HStack(spacing: 10) {
                Text(Self.formatHeaderTime(Date()))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchDesign.textSecondary)
                    .monospacedDigit()

                Button(action: { SettingsWindowController.shared.showSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(NotchDesign.elevated.opacity(0.6), in: Circle())
                        .overlay(Circle().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
                        state.isExpanded = false
                        isClickExpanded = false
                        state.hud = .none
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(NotchDesign.elevated.opacity(0.6), in: Circle())
                        .overlay(Circle().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 42)
    }

    private func navHeaderButton(systemName: String, card: NotchDeckCard) -> some View {
        let isActive = state.activeDeckCard == card
        return Button(action: { navigateToDeckCard(card) }) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 34, height: 28)
                .background(isActive ? Color.white.opacity(0.12) : Color.clear, in: Capsule())
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.38))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: isActive)
    }

    @ObservedObject private var pomodoroTimerForNav = PomodoroTimer.shared

    private var pomodoroNavButton: some View {
        let isActive = state.activeDeckCard == .pomodoro
        let isTimerRunning = pomodoroTimerForNav.isRunning
        return Button(action: { navigateToDeckCard(.pomodoro) }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 34, height: 28)
                    .background(isActive ? Color.white.opacity(0.12) : Color.clear, in: Capsule())
                    .foregroundStyle(isTimerRunning ? NotchDesign.orange : (isActive ? Color.white : Color.white.opacity(0.38)))

                if isTimerRunning {
                    Circle()
                        .fill(NotchDesign.orange)
                        .frame(width: 6, height: 6)
                        .shadow(color: NotchDesign.orange.opacity(0.8), radius: 3)
                        .offset(x: -2, y: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isTimerRunning)
    }

    private static func formatHeaderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Compact Weather Card (center)

    private var weatherIconColor: Color {
        switch weatherStore.weatherCode {
        case 0: return .yellow
        case 1, 2, 3: return .white
        case 45, 48: return Color(white: 0.7)
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return .cyan
        case 71, 73, 75, 77, 85, 86: return Color(white: 0.9)
        case 95, 96, 99: return .purple
        default: return .white
        }
    }

    private func weatherCardGradient(for code: Int) -> LinearGradient {
        switch code {
        case 0: // Clear - warm golden
            return LinearGradient(colors: [Color.yellow.opacity(0.12), Color.orange.opacity(0.06)], startPoint: .topTrailing, endPoint: .bottomLeading)
        case 1, 2, 3: // Partly cloudy
            return LinearGradient(colors: [Color.blue.opacity(0.08), Color.gray.opacity(0.05)], startPoint: .topTrailing, endPoint: .bottomLeading)
        case 45, 48: // Fog
            return LinearGradient(colors: [Color.gray.opacity(0.12), Color.gray.opacity(0.06)], startPoint: .top, endPoint: .bottom)
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: // Rain
            return LinearGradient(colors: [Color.blue.opacity(0.12), Color.cyan.opacity(0.06)], startPoint: .topTrailing, endPoint: .bottomLeading)
        case 71, 73, 75, 77, 85, 86: // Snow
            return LinearGradient(colors: [Color.white.opacity(0.10), Color.blue.opacity(0.06)], startPoint: .topTrailing, endPoint: .bottomLeading)
        case 95, 96, 99: // Thunderstorm
            return LinearGradient(colors: [Color.purple.opacity(0.12), Color.indigo.opacity(0.08)], startPoint: .topTrailing, endPoint: .bottomLeading)
        default:
            return LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)
        }
    }

    private func notchDeckCard<Content: View>(cardIndex: Int = -1, accentTop: Color = Color(red: 0.067, green: 0.067, blue: 0.067), @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(
                TopNotchSurfaceCard(
                    accent: accentTop,
                    isHighlighted: hoveringCard == cardIndex,
                    isFocused: false,
                    cornerRadius: 20
                )
            )
    }

    // quickDeckAction removed — home card with quick actions replaced by 3-column layout

    private var clipboardYouTubeURL: String? {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              YouTubeURLParser.extractVideoID(from: clipboardString) != nil else {
            return nil
        }

        return clipboardString
    }

    private func collapseExpandedDeck() {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            state.showYouTubePrompt = false
            state.isExpanded = false
            isClickExpanded = false
            state.hud = .none
        }
    }

    private func playDetectedVideo() {
        guard let url = state.detectedYouTubeURL,
              let request = YouTubeURLParser.playbackRequest(from: url) else {
            return
        }

        youtubeURLInput = request.canonicalURL?.absoluteString ?? url
        youtubeInputError = nil
        openInlineVideo(request.videoID, startTime: request.startTime)
    }

    private func pasteClipboardYouTubeURL() {
        guard let clipboardYouTubeURL,
              let request = YouTubeURLParser.playbackRequest(from: clipboardYouTubeURL) else { return }
        youtubeURLInput = request.canonicalURL?.absoluteString ?? clipboardYouTubeURL
        youtubeInputError = nil
    }

    private func prefillYouTubeInputIfPossible() {
        guard youtubeURLInput.isEmpty else { return }
        // Prefer the detected URL (survives clipboard changes) over current clipboard
        if let detected = state.detectedYouTubeURL,
           YouTubeURLParser.extractVideoID(from: detected) != nil {
            youtubeURLInput = detected
        } else if let clipboardYouTubeURL {
            youtubeURLInput = clipboardYouTubeURL
        }
    }

    private func playYouTubeInput() {
        let trimmed = youtubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            youtubeInputError = "Paste a YouTube URL first."
            return
        }

        guard let request = YouTubeURLParser.playbackRequest(from: trimmed) else {
            youtubeInputError = "That does not look like a valid YouTube URL."
            return
        }

        youtubeURLInput = request.canonicalURL?.absoluteString ?? trimmed
        youtubeInputError = nil
        openInlineVideo(request.videoID, startTime: request.startTime)
    }

    private func openInlineVideo(_ videoID: String, startTime: Int = 0) {
        guard YouTubeURLParser.isValidVideoID(videoID) else { return }

        youtubeHistory.add(videoID: videoID)
        state.inlineYouTubeStartTime = startTime
        state.inlineYouTubeMinimized = false

        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            state.activeDeckCard = .youtube
            state.inlineYouTubeVideoID = videoID
            state.isShowingInlineYouTubePlayer = true
            state.showYouTubePrompt = false
            state.isExpanded = true
        }
    }

    private func handleYouTubeInputSubmit() {
        let trimmed = youtubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let request = YouTubeURLParser.playbackRequest(from: trimmed) {
            youtubeURLInput = request.canonicalURL?.absoluteString ?? trimmed
            youtubeInputError = nil
            openInlineVideo(request.videoID, startTime: request.startTime)
        } else {
            youtubeInputError = "Paste a YouTube video URL to play."
        }
    }

    private func handleBrowseOrPlay() {
        let trimmed = youtubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let request = YouTubeURLParser.playbackRequest(from: trimmed) {
            youtubeURLInput = request.canonicalURL?.absoluteString ?? trimmed
            youtubeInputError = nil
            openInlineVideo(request.videoID, startTime: request.startTime)
        } else if !trimmed.isEmpty {
            youtubeInputError = "Paste a YouTube video URL to play."
        } else {
            // Input is empty — try to use detected URL or clipboard before navigating
            if let detected = state.detectedYouTubeURL,
               let request = YouTubeURLParser.playbackRequest(from: detected) {
                youtubeURLInput = request.canonicalURL?.absoluteString ?? detected
                youtubeInputError = nil
                openInlineVideo(request.videoID, startTime: request.startTime)
            } else if let clip = clipboardYouTubeURL,
                      let request = YouTubeURLParser.playbackRequest(from: clip) {
                youtubeURLInput = request.canonicalURL?.absoluteString ?? clip
                youtubeInputError = nil
                openInlineVideo(request.videoID, startTime: request.startTime)
            } else {
                // No URL available — navigate to focused YouTube view for URL input
                navigateToDeckCard(.youtube)
            }
        }
    }

    private func openYouTubeInputInSafari() {
        let trimmed = youtubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if let request = YouTubeURLParser.playbackRequest(from: trimmed),
           let url = request.canonicalURL {
            NSWorkspace.shared.open(url)
            return
        }

        if let url = URL(string: trimmed), !trimmed.isEmpty {
            NSWorkspace.shared.open(url)
            return
        }

        if let url = URL(string: "https://www.youtube.com") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshWeatherIfNeeded(force: Bool = false) {
        if weatherStore.isLoading && !force {
            return
        }

        Task {
            await weatherStore.load(city: weatherCity, force: force)
        }
    }

    // Paging helpers removed — deck is now a fixed 3-column layout



    private func animateAudioLevels() {
        withAnimation(.easeInOut(duration: 0.1)) {
            audioLevels = audioLevels.map { _ in CGFloat.random(in: 0.15...1.0) }
        }
    }

    private func startAudioTimer() {
        guard audioTimerCancellable == nil else { return }
        audioTimerCancellable = audioTimerPublisher.sink { [self] _ in animateAudioLevels() }
    }

    private func stopAudioTimer() {
        audioTimerCancellable?.cancel()
        audioTimerCancellable = nil
    }
}

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        // Use the larger radius so the shape is a proper pill / rounded rectangle
        // topRadius controls top corners, bottomRadius controls bottom corners
        let tR = min(topRadius, rect.width / 2, rect.height / 2)
        let bR = min(bottomRadius, rect.width / 2, rect.height / 2)

        var path = Path()
        // Top-left corner
        path.move(to: CGPoint(x: tR, y: 0))
        // Top edge
        path.addLine(to: CGPoint(x: rect.width - tR, y: 0))
        // Top-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: tR),
            control: CGPoint(x: rect.width, y: 0)
        )
        // Right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - bR))
        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width - bR, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: bR, y: rect.height))
        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - bR),
            control: CGPoint(x: 0, y: rect.height)
        )
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: tR))
        // Top-left corner
        path.addQuadCurve(
            to: CGPoint(x: tR, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.closeSubpath()
        return path
    }
}


// MARK: - Card entrance animation modifier

private struct DeckCardEntranceModifier: ViewModifier {
    let appeared: Bool
    let hovering: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 0.92)
            .offset(y: appeared ? 0 : 10)
            .opacity(appeared ? 1.0 : 0.0)
            .brightness(hovering ? 0.04 : 0.0)
            .animation(.spring(duration: 0.4, bounce: 0.25).delay(delay), value: appeared)
            .animation(.easeInOut(duration: 0.2), value: hovering)
    }
}

private struct CardOverlayHintModifier: ViewModifier {
    let label: String
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .cursor(.pointingHand)
    }
}

extension View {
    fileprivate func staggeredEntrance(index: Int, appeared: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.9)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(duration: 0.6, bounce: 0.35).delay(Double(index) * 0.08), value: appeared)
    }
    
    fileprivate func deckCardEntrance(appeared: Bool, hovering: Bool, delay: Double) -> some View {
        modifier(DeckCardEntranceModifier(appeared: appeared, hovering: hovering, delay: delay))
    }
    fileprivate func cardOverlayHint(_ label: String) -> some View {
        modifier(CardOverlayHintModifier(label: label))
    }
    fileprivate func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
