import Combine
import IOKit.ps
import ServiceManagement
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

struct NotchView: View {
    @ObservedObject var state: NotchState

    @State private var hoverTimer: Timer?
    @State private var collapseTimer: Timer?
    @State private var audioLevels: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]
    @State private var audioTimerCancellable: AnyCancellable?
    @State private var youtubeURLInput = ""
    @State private var youtubeInputError: String?
    @State private var deckDragOffset: CGFloat = 0
    @State private var idlePulse = false
    @State private var expandBlur: CGFloat = 2
    @State private var chargingGlowPulse = false
    @State private var gearHovered = false
    @State private var chevronHovered = false
    @StateObject private var weatherStore = NotchWeatherStore()

    @AppStorage("hudDisplayMode") private var hudDisplayMode = "progressBar"
    @AppStorage("showLockIndicator") private var showLockIndicator = true
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("showHapticFeedback") private var hapticFeedbackEnabled = true
    @AppStorage("notchWeatherCity") private var weatherCity = "San Francisco"

    private let deckHeight: CGFloat = 186
    private let deckCardSpacing: CGFloat = 10

    private var shouldShowDeck: Bool {
        state.isExpanded
            && state.hud == .none
            && !state.isShowingInlineYouTubePlayer
            && !state.isShowingInlineBrowser
            && !state.showChargingAnimation
            && !state.showUnplugAnimation
            && !state.showUnlockAnimation
            && !state.isScreenLocked
    }

    private var audioTimerPublisher: AnyPublisher<Date, Never> {
        Timer.publish(every: 0.15, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
    }

    private var isMinimalMode: Bool { hudDisplayMode == "minimal" }

    private var notchSize: CGSize {
        if state.isShowingInlineYouTubePlayer {
            return CGSize(
                width: max(state.notchWidth + 24, state.youtubePlayerWidth + 32),
                height: state.notchHeight + state.youtubePlayerHeight + 20
            )
        }

        if state.isShowingInlineBrowser {
            return CGSize(
                width: max(state.notchWidth + 24, state.youtubePlayerWidth + 32),
                height: state.notchHeight + state.youtubePlayerHeight + 20
            )
        }

        if shouldShowDeck {
            return CGSize(
                width: max(state.notchWidth + 680, 960),
                height: state.notchHeight + 220
            )
        }

        let shouldExpand = !isMinimalMode || state.hud == .none
        var baseExtra: CGFloat = 16
        if state.isExpanded && shouldExpand { baseExtra = 140 }
        else if state.hud != .none && isMinimalMode { baseExtra = 100 }

        var stateExtraWidth: CGFloat = 0
        if state.isScreenLocked { stateExtraWidth = 140 }
        else if state.battery.isCharging || state.showChargingAnimation { stateExtraWidth = 80 }
        else if case .music = state.activity, state.isExpanded { stateExtraWidth = 60 }

        var expandedHeight: CGFloat = 0
        if state.isExpanded && shouldExpand {
            // Larger height for media controls with scrubber
            if case .music = state.activity {
                expandedHeight = 85
            } else {
                expandedHeight = 75
            }
        }

        return CGSize(width: state.notchWidth + baseExtra + stateExtraWidth, height: state.notchHeight + expandedHeight)
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(topRadius: 8, bottomRadius: state.isExpanded ? 24 : 12).fill(.black)
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.white.opacity(0.04), .clear], startPoint: .top, endPoint: .center)
                        .frame(height: state.notchHeight)
                        .allowsHitTesting(false)
                }
                .overlay(
                    NotchShape(topRadius: 8, bottomRadius: state.isExpanded ? 24 : 12)
                        .stroke(Color.white.opacity(state.isHovered && !state.isExpanded ? 0.15 : 0), lineWidth: 1)
                )

            VStack(spacing: 0) {
                collapsedContent.frame(height: state.notchHeight)

                if state.isExpanded {
                    expandedContent
                        .blur(radius: expandBlur)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .top)).combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                        ))
                        .onAppear { withAnimation(.easeOut(duration: 0.3)) { expandBlur = 0 } }
                        .onDisappear { expandBlur = 2 }
                }
            }
        }
        .frame(width: notchSize.width, height: notchSize.height)
        .scaleEffect(state.isHovered && !state.isExpanded ? 1.08 : 1.0, anchor: .top)
        .shadow(color: .black.opacity(0.3), radius: state.isExpanded ? 20 : (state.isHovered ? 8 : 0), y: state.isExpanded ? 10 : 0)
        .background(
            Group {
                if state.isExpanded && shouldShowDeck {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.2, blue: 0.8).opacity(0.12),
                                    Color(red: 0.2, green: 0.3, blue: 0.9).opacity(0.06),
                                    Color.clear
                                ],
                                center: .bottom,
                                startRadius: 20,
                                endRadius: 180
                            )
                        )
                        .blur(radius: 40)
                        .offset(y: 20)
                        .transition(.opacity)
                }
            }
        )
        .animation(.spring(duration: 0.55, bounce: 0.3, blendDuration: 0.2), value: state.isExpanded)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: state.isHovered)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: state.hud)
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            if !state.isShowingInlineYouTubePlayer && !state.isShowingInlineBrowser && !state.isExpanded { handleTap() }
        }
        .onHover { handleHover($0) }
        .onChange(of: state.activity) { _, newActivity in
            if case .music = newActivity { startAudioTimer() } else { stopAudioTimer() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("refreshWeather"))) { _ in
            refreshWeatherIfNeeded(force: true)
        }
        .onAppear { if case .music = state.activity { startAudioTimer() } }
        .onDisappear { stopAudioTimer() }
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
    }

    @ViewBuilder
    private var collapsedContent: some View {
        HStack(spacing: 0) {
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

            Color.clear.frame(width: state.notchWidth - 16)

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
        } else if case .music = state.activity {
            // Use the new mini artwork view that shows album art
            MiniArtworkView()
                .transition(.scale.combined(with: .opacity))
        } else if case .timer = state.activity {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .transition(.scale.combined(with: .opacity))
        } else {
            // No activity — show app name
            Text("TopNotch")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(idlePulse ? 0.6 : 0.45))
                .lineLimit(1)
                .fixedSize()
                .transition(.opacity)
                .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { idlePulse = true } }
                .onDisappear { idlePulse = false }
        }
    }

    @ViewBuilder
    private var rightIndicator: some View {
        if state.isScreenLocked && showLockIndicator {
            LockPulsingDot()
        } else if state.showUnlockAnimation && showLockIndicator {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        } else if state.showChargingAnimation && showBatteryIndicator {
            ChargingIndicator(level: state.battery.level)
        } else if state.showUnplugAnimation && showBatteryIndicator {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
                .transition(.scale.combined(with: .opacity))
        } else if state.battery.isCharging && showBatteryIndicator {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.25))
                    .frame(width: 22, height: 22)
                    .scaleEffect(chargingGlowPulse ? 1.4 : 1.0)
                    .opacity(chargingGlowPulse ? 0.0 : 0.6)
                    .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) { chargingGlowPulse = true } }
                    .onDisappear { chargingGlowPulse = false }
                ChargingIndicator(level: state.battery.level)
            }
        } else if case .music = state.activity {
            // Use the new compact media indicator with animated waveform
            CompactMediaIndicator()
                .transition(.scale.combined(with: .opacity))
        } else if case .timer(let remaining, let total) = state.activity {
            HStack(spacing: 6) {
                Text(formatTime(remaining))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.orange.opacity(0.3)).frame(width: 28, height: 4)
                    Capsule().fill(Color.orange).frame(width: 28 * CGFloat(remaining / max(total, 1)), height: 4)
                }
            }
        } else {
            // No activity, not charging — show "Active" indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(.green.opacity(0.6))
                    .frame(width: 4, height: 4)
                Text("Active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 8) {
            switch state.hud {
            case .volume(let level, let muted): volumeHUD(level: level, muted: muted)
            case .brightness(let level): brightnessHUD(level: level)
            case .none:
                if state.isShowingInlineYouTubePlayer, let videoID = state.inlineYouTubeVideoID { inlineYouTubePlayer(videoID: videoID) }
                else if state.isShowingInlineBrowser { inlineBrowser }
                else if state.showChargingAnimation && showBatteryIndicator { chargingExpanded }
                else if state.showUnplugAnimation && showBatteryIndicator { unplugExpanded }
                else if state.showUnlockAnimation && showLockIndicator { unlockExpanded }
                else if state.isScreenLocked && showLockIndicator { lockedExpanded }
                else {
                    switch state.activity {
                    case .music(let app): musicExpanded(app: app)
                    case .timer(let remaining, _): timerExpanded(remaining: remaining)
                    case .none: defaultExpanded
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
        guard !state.isShowingInlineYouTubePlayer && !state.isShowingInlineBrowser else { return }
        hoverTimer?.invalidate()
        collapseTimer?.invalidate()
        if hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
            state.isExpanded = true
            scheduleCollapse(delay: 4)
        }
    }

    private func handleHover(_ hovering: Bool) {
        if state.isShowingInlineYouTubePlayer || state.isShowingInlineBrowser {
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) { state.isHovered = hovering }
            return
        }

        hoverTimer?.invalidate()
        collapseTimer?.invalidate()
        if hovering && hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
        withAnimation(.spring(duration: 0.25, bounce: 0.4)) { state.isHovered = hovering }

        if hovering {
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
                guard UserDefaults.standard.object(forKey: "expandOnHover") as? Bool ?? true else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) { self.state.isExpanded = true }
                if self.hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
            }
        } else {
            if !state.isShowingInlineBrowser {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    state.isExpanded = false
                    state.hud = .none
                }
            }
        }
    }

    private func scheduleCollapse(delay: TimeInterval) {
        guard !state.isShowingInlineYouTubePlayer && !state.isShowingInlineBrowser else { return }
        collapseTimer?.invalidate()
        let collapseDelay = UserDefaults.standard.object(forKey: "autoCollapseDelay") as? Double ?? 4.0
        guard collapseDelay > 0 else { return }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: collapseDelay, repeats: false) { _ in
            if !self.state.isHovered {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    self.state.isExpanded = false
                    self.state.hud = .none
                }
            }
        }
    }

    private func showHUD() {
        guard !state.isShowingInlineYouTubePlayer && !state.isShowingInlineBrowser else { return }
        collapseTimer?.invalidate()
        if !isMinimalMode {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { state.isExpanded = true }
        }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                if !self.state.isHovered && !self.isMinimalMode { self.state.isExpanded = false }
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
        // Use the new MediaControlView with album art, scrubber, and controls
        MediaControlView()
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
            ))
    }

    private func inlineYouTubePlayer(videoID: String) -> some View {
        NotchInlineYouTubePlayerView(notchState: state, videoID: videoID)
            .id(videoID)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
            ))
    }

    private var inlineBrowser: some View {
        NotchInlineBrowserView(notchState: state)
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

    private var dynamicDeck: some View {
        VStack(spacing: 10) {
            deckHeader

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: deckCardSpacing) {
                    nowPlayingDeckCard
                        .frame(width: 175)
                        .scaleEffect(hoveringCard == 0 ? 1.02 : (deckCardsAppeared ? 1.0 : 0.9))
                        .offset(y: hoveringCard == 0 ? -2 : (deckCardsAppeared ? 0 : 10))
                        .shadow(color: .black.opacity(hoveringCard == 0 ? 0.4 : 0.15), radius: hoveringCard == 0 ? 12 : 4, y: hoveringCard == 0 ? 6 : 2)
                        .opacity(deckCardsAppeared ? 1.0 : 0.0)
                        .animation(.spring(duration: 0.4, bounce: 0.25).delay(0.1), value: deckCardsAppeared)
                        .onHover { hovering in hoveringCard = hovering ? 0 : nil }
                        .animation(.spring(duration: 0.35, bounce: 0.2), value: hoveringCard)

                    weatherDeckCard
                        .frame(width: 175)
                        .scaleEffect(hoveringCard == 1 ? 1.02 : (deckCardsAppeared ? 1.0 : 0.9))
                        .offset(y: hoveringCard == 1 ? -2 : (deckCardsAppeared ? 0 : 12))
                        .shadow(color: .black.opacity(hoveringCard == 1 ? 0.4 : 0.15), radius: hoveringCard == 1 ? 12 : 4, y: hoveringCard == 1 ? 6 : 2)
                        .opacity(deckCardsAppeared ? 1.0 : 0.0)
                        .animation(.spring(duration: 0.4, bounce: 0.25).delay(0.16), value: deckCardsAppeared)
                        .onHover { hovering in hoveringCard = hovering ? 1 : nil }
                        .animation(.spring(duration: 0.35, bounce: 0.2), value: hoveringCard)

                    calendarDeckCard
                        .frame(width: 175)
                        .scaleEffect(hoveringCard == 3 ? 1.02 : (deckCardsAppeared ? 1.0 : 0.9))
                        .offset(y: hoveringCard == 3 ? -2 : (deckCardsAppeared ? 0 : 14))
                        .shadow(color: .black.opacity(hoveringCard == 3 ? 0.4 : 0.15), radius: hoveringCard == 3 ? 12 : 4, y: hoveringCard == 3 ? 6 : 2)
                        .opacity(deckCardsAppeared ? 1.0 : 0.0)
                        .animation(.spring(duration: 0.4, bounce: 0.25).delay(0.22), value: deckCardsAppeared)
                        .onHover { hovering in hoveringCard = hovering ? 3 : nil }
                        .animation(.spring(duration: 0.35, bounce: 0.2), value: hoveringCard)

                    pomodoroDeckCard
                        .frame(width: 175)
                        .scaleEffect(hoveringCard == 4 ? 1.02 : (deckCardsAppeared ? 1.0 : 0.9))
                        .offset(y: hoveringCard == 4 ? -2 : (deckCardsAppeared ? 0 : 16))
                        .shadow(color: .black.opacity(hoveringCard == 4 ? 0.4 : 0.15), radius: hoveringCard == 4 ? 12 : 4, y: hoveringCard == 4 ? 6 : 2)
                        .opacity(deckCardsAppeared ? 1.0 : 0.0)
                        .animation(.spring(duration: 0.4, bounce: 0.25).delay(0.28), value: deckCardsAppeared)
                        .onHover { hovering in hoveringCard = hovering ? 4 : nil }
                        .animation(.spring(duration: 0.35, bounce: 0.2), value: hoveringCard)

                    youtubeDeckCard
                        .frame(width: 175)
                        .scaleEffect(hoveringCard == 2 ? 1.02 : (deckCardsAppeared ? 1.0 : 0.9))
                        .offset(y: hoveringCard == 2 ? -2 : (deckCardsAppeared ? 0 : 18))
                        .shadow(color: .black.opacity(hoveringCard == 2 ? 0.4 : 0.15), radius: hoveringCard == 2 ? 12 : 4, y: hoveringCard == 2 ? 6 : 2)
                        .opacity(deckCardsAppeared ? 1.0 : 0.0)
                        .animation(.spring(duration: 0.4, bounce: 0.25).delay(0.34), value: deckCardsAppeared)
                        .onHover { hovering in hoveringCard = hovering ? 2 : nil }
                        .animation(.spring(duration: 0.35, bounce: 0.2), value: hoveringCard)
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
            .overlay(alignment: .leading) {
                LinearGradient(colors: [Color.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 20)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(colors: [.clear, Color.black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 20)
                    .allowsHitTesting(false)
            }
            .frame(height: 170)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(deckContentAppeared ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.1), value: deckContentAppeared)
        .onAppear {
            prefillYouTubeInputIfPossible()
            refreshWeatherIfNeeded()
            deckContentAppeared = false
            deckCardsAppeared = false
            withAnimation { deckContentAppeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { deckCardsAppeared = true }
            }
        }
        .onDisappear {
            deckCardsAppeared = false
            deckContentAppeared = false
        }
        .onChange(of: state.activeDeckCard) { _, newCard in
            if newCard == .youtube {
                prefillYouTubeInputIfPossible()
            }
            if newCard == .weather {
                refreshWeatherIfNeeded(force: weatherStore.cityName != weatherCity)
            }
        }
    }

    private var deckHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Left: Home label
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Home")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 5) {
                    let icons = ["house.fill", "music.note", "cloud.sun.fill", "calendar", "timer", "play.rectangle.fill"]
                    ForEach(Array(icons.enumerated()), id: \.element) { index, icon in
                        let isActive = index == 0
                        VStack(spacing: 2) {
                            Image(systemName: icon)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white.opacity(
                                    hoveringIcon == icon ? 0.8 : (isActive ? 0.6 : 0.2)
                                ))
                                .frame(width: 16, height: 16)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(
                                            hoveringIcon == icon ? 0.12 : (isActive ? 0.08 : 0.03)
                                        ))
                                )
                                .animation(.easeInOut(duration: 0.2), value: hoveringIcon)

                            Circle()
                                .fill(Color.white.opacity(isActive ? 0.5 : 0.0))
                                .frame(width: 3, height: 3)
                        }
                        .onHover { hovering in hoveringIcon = hovering ? icon : nil }
                    }
                }

                if state.showYouTubePrompt, state.detectedYouTubeURL != nil {
                    Button(action: playDetectedVideo) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 7, weight: .bold))
                            Text("Copied URL")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(Color.red.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                // Center: empty
                Spacer(minLength: 0)

                // Right: live-updating time, settings gear, collapse chevron
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(Self.formatHeaderTime(context.date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Button(action: { SettingsWindowController.shared.showSettings() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(gearHovered ? 0.8 : 0.5))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(gearHovered ? 0.12 : 0.06), in: Circle())
                            .animation(.easeInOut(duration: 0.2), value: gearHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { gearHovered = $0 }

                    Button(action: collapseExpandedDeck) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(chevronHovered ? 0.9 : 0.65))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(chevronHovered ? 0.14 : 0.07), in: Circle())
                            .animation(.easeInOut(duration: 0.2), value: chevronHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { chevronHovered = $0 }
                }
            }

            // Subtle separator line
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    private static func formatHeaderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Compact Now Playing Card (left)

    private var nowPlayingDeckCard: some View {
        notchDeckCard(cardIndex: 0) {
            CompactNowPlayingCard()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: MediaRemoteController.shared.nowPlayingInfo.title)
        }
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

    @State private var weatherIconBob: Bool = false
    @State private var weatherTempAppeared: Bool = false
    @State private var weatherGlowPulse: Bool = false

    private var weatherDeckCard: some View {
        notchDeckCard(cardIndex: 1) {
            ZStack {
                // Animated weather particles behind content
                WeatherParticleView(weatherCode: weatherStore.weatherCode)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    // Temperature + animated weather icon
                    HStack(alignment: .center, spacing: 6) {
                        Text(weatherStore.temperatureText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(weatherStore.temperatureText.dropLast().description) ?? 0))
                            .scaleEffect(weatherTempAppeared ? 1.0 : 0.7)
                            .opacity(weatherTempAppeared ? 1.0 : 0.0)
                            .animation(.spring(duration: 0.5, bounce: 0.3), value: weatherTempAppeared)

                        // Animated weather icon with bob + glow
                        ZStack {
                            // Glow behind icon
                            Image(systemName: weatherStore.symbolName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(weatherIconColor.opacity(0.4))
                                .blur(radius: 8)
                                .scaleEffect(weatherGlowPulse ? 1.3 : 1.0)
                                .opacity(weatherGlowPulse ? 0.6 : 0.3)

                            Image(systemName: weatherStore.symbolName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(weatherIconColor)
                                .symbolRenderingMode(.hierarchical)
                                .shadow(color: weatherIconColor.opacity(0.5), radius: 4, y: 2)
                        }
                        .offset(y: weatherIconBob ? -2 : 2)
                        .rotationEffect(.degrees(weatherIconBob ? -3 : 3))
                    }

                    // Condition text with slide-in
                    Text(weatherStore.conditionText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .id(weatherStore.conditionText)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))

                    // Hi/Lo with color coding
                    if let hi = weatherStore.highTemp, let lo = weatherStore.lowTemp {
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.orange.opacity(0.7))
                                Text(hi)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange.opacity(0.6))
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.cyan.opacity(0.6))
                                Text(lo)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.cyan.opacity(0.5))
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    // Location with animated pin
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(weatherStore.cityName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: weatherStore.temperatureText)
            .animation(.easeInOut(duration: 0.5), value: weatherStore.conditionText)
            .onAppear {
                weatherTempAppeared = true
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    weatherIconBob = true
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    weatherGlowPulse = true
                }
            }
            .onDisappear {
                weatherTempAppeared = false
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(weatherCardGradient(for: weatherStore.weatherCode))
                .animation(.easeInOut(duration: 0.6), value: weatherStore.weatherCode)
        )
    }

    // MARK: - Compact YouTube Card (right)

    @State private var ytPlayPressed = false
    @State private var ytPastePressed = false

    private var youtubeDeckCard: some View {
        notchDeckCard(cardIndex: 2) {
            VStack(alignment: .leading, spacing: 8) {
                // YouTube header — icon + label
                HStack(spacing: 5) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.red)
                            .frame(width: 16, height: 11)
                        Image(systemName: "play.fill")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("YouTube")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                // Combined search / URL text field
                TextField("Search or paste URL\u{2026}", text: $youtubeURLInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(white: 0.14))
                    )
                    .onSubmit { handleYouTubeInputSubmit() }

                // Two action buttons side by side
                HStack(spacing: 6) {
                    Button(action: handleBrowseOrPlay) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text("Browse")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule(style: .continuous).fill(Color.blue.opacity(0.8)))
                        .scaleEffect(ytPlayPressed ? 0.94 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                        withAnimation(.spring(duration: 0.2, bounce: 0.3)) { ytPlayPressed = pressing }
                    }, perform: {})

                    if clipboardYouTubeURL != nil {
                        Button(action: pasteClipboardYouTubeURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 8, weight: .semibold))
                                Text("Paste")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
                            .scaleEffect(ytPastePressed ? 0.94 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                            withAnimation(.spring(duration: 0.2, bounce: 0.3)) { ytPastePressed = pressing }
                        }, perform: {})
                    }
                }

                if let youtubeInputError {
                    Text(youtubeInputError)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.red.opacity(0.9))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Calendar Deck Card

    private var calendarDeckCard: some View {
        notchDeckCard(cardIndex: 3) {
            CalendarDeckCard()
        }
    }

    // MARK: - Pomodoro Deck Card

    private var pomodoroDeckCard: some View {
        notchDeckCard(cardIndex: 4) {
            PomodoroDeckCard()
        }
    }

    private func notchDeckCard<Content: View>(cardIndex: Int = -1, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.13), Color(white: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(hoveringCard == cardIndex ? 0.18 : 0.07),
                                Color.white.opacity(hoveringCard == cardIndex ? 0.15 : 0.04),
                                Color.white.opacity(hoveringCard == cardIndex ? 0.08 : 0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: hoveringCard == cardIndex ? 1.2 : 0.8
                    )
                    .animation(.easeInOut(duration: 0.35), value: hoveringCard)
            )
            .overlay(alignment: .top) {
                // Enhanced glass shine at top edge
                ZStack {
                    LinearGradient(
                        colors: [Color.white.opacity(hoveringCard == cardIndex ? 0.12 : 0.07), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 16)

                    // Thin bright line at very top for glass edge
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.0), Color.white.opacity(hoveringCard == cardIndex ? 0.15 : 0.08), Color.white.opacity(0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 0.5)
                        Spacer()
                    }
                    .frame(height: 16)
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.35), value: hoveringCard)
            }
            .overlay(alignment: .bottom) {
                // Subtle inner shadow at bottom for depth
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .clipShape(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .allowsHitTesting(false)
            }
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
            state.hud = .none
        }
    }

    private func playDetectedVideo() {
        guard let url = state.detectedYouTubeURL,
              let videoID = YouTubeURLParser.extractVideoID(from: url) else {
            return
        }

        youtubeURLInput = url
        youtubeInputError = nil
        openInlineVideo(videoID)
    }

    private func pasteClipboardYouTubeURL() {
        guard let clipboardYouTubeURL else { return }
        youtubeURLInput = clipboardYouTubeURL
        youtubeInputError = nil
    }

    private func prefillYouTubeInputIfPossible() {
        if youtubeURLInput.isEmpty, let clipboardYouTubeURL {
            youtubeURLInput = clipboardYouTubeURL
        }
    }

    private func playYouTubeInput() {
        let trimmed = youtubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            youtubeInputError = "Paste a YouTube URL first."
            return
        }

        guard let videoID = YouTubeURLParser.extractVideoID(from: trimmed) else {
            youtubeInputError = "That does not look like a valid YouTube URL."
            return
        }

        youtubeInputError = nil
        openInlineVideo(videoID)
    }

    private func openInlineVideo(_ videoID: String) {
        guard YouTubeURLParser.isValidVideoID(videoID) else { return }

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
        if trimmed.isEmpty {
            openBrowseYouTube()
            return
        }
        if let videoID = YouTubeURLParser.extractVideoID(from: trimmed) {
            youtubeInputError = nil
            openInlineVideo(videoID)
        } else {
            openBrowseYouTube()
        }
    }

    private func handleBrowseOrPlay() {
        let trimmed = youtubeURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let videoID = YouTubeURLParser.extractVideoID(from: trimmed) {
            youtubeInputError = nil
            openInlineVideo(videoID)
        } else {
            openBrowseYouTube()
        }
    }

    private func openBrowseYouTube() {
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            state.activeDeckCard = .youtube
            state.isShowingInlineBrowser = true
            state.showYouTubePrompt = false
            state.isExpanded = true
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

    // mediaDeckSubtitle removed — media card is now compact nowPlayingDeckCard

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
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.height - bottomRadius))
        path.addQuadCurve(to: CGPoint(x: bottomRadius, y: rect.height), control: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width - bottomRadius, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height - bottomRadius), control: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.closeSubpath()
        return path
    }
}

struct NotchInlineYouTubePlayerView: View {
    @ObservedObject var notchState: NotchState
    let videoID: String

    @StateObject private var playerState = YouTubePlayerState()
    @StateObject private var playerController = YouTubePlayerController()
    @State private var resizeStartWidth: CGFloat?
    @State private var isHoveringResizeHandle = false
    @State private var isHoveringChrome = false

    private let minWidth: CGFloat = 360
    private let maxWidth: CGFloat = 960
    private let aspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red.opacity(0.95))
                        .frame(width: 8, height: 8)
                    Text("YouTube")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Pinned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 8)

                Button(action: closePlayer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(isHoveringChrome ? 0.12 : 0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close video")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            VideoPlayerContentView(
                videoID: videoID,
                playerState: playerState,
                playerController: playerController,
                onClose: closePlayer
            )
            .frame(width: notchState.youtubePlayerWidth, height: notchState.youtubePlayerHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(isHoveringResizeHandle ? 0.88 : 0.72))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay(alignment: .topLeading) {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 12))
                                path.addLine(to: CGPoint(x: 12, y: 0))
                            }
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
                .frame(width: 56, height: 56, alignment: .bottomTrailing)
                .contentShape(Rectangle())
                .gesture(resizeGesture)
                .onHover { hovering in
                    isHoveringResizeHandle = hovering
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.96), Color(red: 0.08, green: 0.08, blue: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 20, y: 10)
        .onHover { hovering in
            isHoveringChrome = hovering
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            notchState.isExpanded = true
            playerState.loadVideo(id: videoID)
        }
        .onChange(of: videoID) { _, newValue in
            playerState.loadVideo(id: newValue)
        }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if resizeStartWidth == nil {
                    resizeStartWidth = notchState.youtubePlayerWidth
                }

                let baseWidth = resizeStartWidth ?? notchState.youtubePlayerWidth
                let widthDelta = max(value.translation.width, value.translation.height * aspectRatio)
                let newWidth = min(max(baseWidth + widthDelta, minWidth), maxWidth)

                notchState.youtubePlayerWidth = newWidth
                notchState.youtubePlayerHeight = newWidth / aspectRatio
            }
            .onEnded { _ in
                resizeStartWidth = nil
            }
    }

    private func closePlayer() {
        playerController.pause()
        playerState.reset()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            notchState.isShowingInlineYouTubePlayer = false
            notchState.inlineYouTubeVideoID = nil
            notchState.activeDeckCard = .youtube
            if !notchState.isHovered {
                notchState.isExpanded = false
            }
        }
    }
}

private extension NotchDeckCard {
    var title: String {
        switch self {
        case .home: return "Home"
        case .weather: return "Weather"
        case .youtube: return "YouTube"
        case .media: return "Media"
        case .pomodoro: return "Focus"
        case .clipboard: return "Clipboard"
        case .calendar: return "Calendar"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "sparkles"
        case .weather: return "cloud.sun.fill"
        case .youtube: return "play.rectangle.fill"
        case .media: return "music.note"
        case .pomodoro: return "timer"
        case .clipboard: return "doc.on.clipboard"
        case .calendar: return "calendar"
        }
    }
}

@MainActor
final class NotchWeatherStore: ObservableObject {
    @Published var cityName = "San Francisco"
    @Published var temperatureText = "--°"
    @Published var conditionText = "Enter a city to load weather"
    @Published var symbolName = "cloud.sun.fill"
    @Published var isLoading = false
    @Published var highTemp: String?
    @Published var lowTemp: String?
    @Published var weatherCode: Int = -1
    @AppStorage("weatherUnit") private var weatherUnit = "celsius"

    private var lastLoadedCity = ""

    var hasWeather: Bool {
        temperatureText != "--°"
    }

    func load(city: String, force: Bool = false) async {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else {
            temperatureText = "--°"
            conditionText = "Enter a city to load weather"
            symbolName = "cloud.sun.fill"
            return
        }

        if !force && trimmedCity.caseInsensitiveCompare(lastLoadedCity) == .orderedSame {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let encodedCity = trimmedCity.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedCity
            let geocodeURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCity)&count=1&language=en&format=json")!
            let (geocodeData, _) = try await URLSession.shared.data(from: geocodeURL)
            let geocodeResponse = try JSONDecoder().decode(OpenMeteoGeocodeResponse.self, from: geocodeData)

            guard let result = geocodeResponse.results?.first else {
                conditionText = "City not found"
                temperatureText = "--°"
                symbolName = "mappin.slash"
                return
            }

            cityName = [result.name, result.admin1, result.country]
                .compactMap { $0 }
                .joined(separator: ", ")

            let unitParam = weatherUnit == "fahrenheit" ? "&temperature_unit=fahrenheit" : ""
            let weatherURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(result.latitude)&longitude=\(result.longitude)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min\(unitParam)&timezone=auto&forecast_days=1")!
            let (weatherData, _) = try await URLSession.shared.data(from: weatherURL)
            let weatherResponse = try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: weatherData)

            temperatureText = "\(Int(weatherResponse.current.temperature_2m.rounded()))°"
            conditionText = Self.conditionDescription(for: weatherResponse.current.weather_code)
            symbolName = Self.symbolName(for: weatherResponse.current.weather_code)
            weatherCode = weatherResponse.current.weather_code
            if let daily = weatherResponse.daily,
               let maxTemps = daily.temperature_2m_max, let maxT = maxTemps.first,
               let minTemps = daily.temperature_2m_min, let minT = minTemps.first {
                highTemp = "\(Int(maxT.rounded()))°"
                lowTemp = "\(Int(minT.rounded()))°"
            }
            lastLoadedCity = trimmedCity
        } catch {
            conditionText = "Weather unavailable"
            temperatureText = "--°"
            symbolName = "wifi.exclamationmark"
        }
    }

    private static func conditionDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 65, 66, 67: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Conditions updating"
        }
    }

    private static func symbolName(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

private struct OpenMeteoGeocodeResponse: Decodable {
    let results: [OpenMeteoGeocodeResult]?
}

private struct OpenMeteoGeocodeResult: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let admin1: String?
    let country: String?
}

private struct OpenMeteoWeatherResponse: Decodable {
    let current: OpenMeteoCurrentWeather
    let daily: OpenMeteoDailyWeather?
}

private struct OpenMeteoCurrentWeather: Decodable {
    let temperature_2m: Double
    let weather_code: Int
}

private struct OpenMeteoDailyWeather: Decodable {
    let temperature_2m_max: [Double]?
    let temperature_2m_min: [Double]?
}

struct LockIconView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle().fill(Color.orange.opacity(0.25)).frame(width: 24, height: 24)
                .scaleEffect(isPulsing ? 1.6 : 1.0).opacity(isPulsing ? 0.0 : 0.7)
            Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold))
                .foregroundStyle(.orange).shadow(color: .orange.opacity(0.9), radius: isPulsing ? 8 : 4)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { isPulsing = true } }
    }
}

struct LockPulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle().stroke(Color.orange.opacity(0.6), lineWidth: 2).frame(width: 18, height: 18)
                .scaleEffect(isPulsing ? 1.6 : 1.0).opacity(isPulsing ? 0.0 : 0.9)
            Circle().fill(Color.orange).frame(width: 8, height: 8).shadow(color: .orange, radius: 4)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) { isPulsing = true } }
    }
}

struct ChargingIndicator: View {
    let level: Int
    @State private var isAnimating = false

    private var batteryColor: Color {
        if level <= 20 { return .red }
        if level <= 50 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).stroke(batteryColor, lineWidth: 1).frame(width: 20, height: 10)
                RoundedRectangle(cornerRadius: 1).fill(batteryColor).frame(width: max(2, 16 * CGFloat(level) / 100), height: 6).padding(.leading, 2)
            }
            Image(systemName: "bolt.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(batteryColor)
                .opacity(isAnimating ? 1 : 0.5).scaleEffect(isAnimating ? 1.1 : 0.9)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { isAnimating = true } }
    }
}

struct BatteryBarView: View {
    let level: Int
    let isCharging: Bool
    @State private var animatedLevel: CGFloat = 0
    @State private var pulseAnimation = false

    private var color: Color {
        if level <= 20 { return .red }
        if level <= 50 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(CGFloat(i) < animatedLevel / 10 ? color : Color.white.opacity(0.15))
                    .frame(width: 4, height: 18)
                    .scaleEffect(y: isCharging && pulseAnimation && CGFloat(i) < animatedLevel / 10 ? 1.1 : 1.0)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { animatedLevel = CGFloat(level) }
            if isCharging { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulseAnimation = true } }
        }
    }
}

struct CalendarWidgetView: View {
    private let calendar = Calendar.current
    private var currentDay: Int { calendar.component(.day, from: Date()) }
    private var currentWeekday: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: Date()).uppercased()
    }
    private var currentMonth: String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }
    private var currentYear: String {
        let f = DateFormatter(); f.dateFormat = "yyyy"
        return f.string(from: Date())
    }
    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.2, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Text("\(currentDay)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentWeekday).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                    Text("\(currentMonth) \(currentYear)").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .fixedSize()
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let dayOfWeek = calendar.component(.weekday, from: Date())
                    let adjustedIndex = (index + 2) % 7
                    let isToday = (dayOfWeek - 1) == adjustedIndex || (dayOfWeek == 1 && index == 6)
                    Circle()
                        .fill(isToday ?
                            AnyShapeStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.2, blue: 0.4)], startPoint: .top, endPoint: .bottom)) :
                            AnyShapeStyle(Color.white.opacity(index < dayOfWeek - 1 || (dayOfWeek == 1 && index < 6) ? 0.4 : 0.15)))
                        .frame(width: isToday ? 8 : 5, height: isToday ? 8 : 5)
                }
            }
            Spacer()
            Text(timeString).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white).monospacedDigit().fixedSize()
        }
        .padding(.horizontal, 8)
    }
}

struct ProgressBarVolumeHUD: View {
    let level: CGFloat
    let muted: Bool
    @AppStorage("volumeShowPercent") private var showPercent = true

    private var volumeIcon: String {
        if muted { return "speaker.slash.fill" }
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: volumeIcon).font(.system(size: 18, weight: .medium)).foregroundStyle(muted ? .gray : .white).frame(width: 24)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2)).frame(height: 6)
                    Capsule().fill(muted ? Color.gray : Color.white).frame(width: max(6, geo.size.width * level), height: 6)
                }
            }
            .frame(height: 6)
            if showPercent {
                Text("\(Int(level * 100))%").font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(muted ? .gray : .white).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct ProgressBarBrightnessHUD: View {
    let level: CGFloat
    @AppStorage("brightnessShowPercent") private var showPercent = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill").font(.system(size: 18, weight: .medium)).foregroundStyle(.yellow).frame(width: 24)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.yellow.opacity(0.2)).frame(height: 6)
                    Capsule().fill(Color.yellow).frame(width: max(6, geo.size.width * level), height: 6)
                }
            }
            .frame(height: 6)
            if showPercent {
                Text("\(Int(level * 100))%").font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct NotchedVolumeHUD: View {
    let level: CGFloat
    let muted: Bool

    private var volumeIcon: String {
        if muted { return "speaker.slash.fill" }
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: volumeIcon).font(.system(size: 18, weight: .medium)).foregroundStyle(muted ? .gray : .white).frame(width: 24)
            HStack(spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CGFloat(i) < level * 16 ? (muted ? Color.gray : Color.white) : Color.white.opacity(0.15))
                        .frame(width: 6, height: 16)
                }
            }
            Text("\(Int(level * 100))%").font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(muted ? .gray : .white).monospacedDigit().frame(width: 44, alignment: .trailing)
        }
    }
}

struct NotchedBrightnessHUD: View {
    let level: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill").font(.system(size: 18, weight: .medium)).foregroundStyle(.yellow).frame(width: 24)
            HStack(spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CGFloat(i) < level * 16 ? Color.yellow : Color.yellow.opacity(0.15))
                        .frame(width: 6, height: 16)
                }
            }
            Text("\(Int(level * 100))%").font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow).monospacedDigit().frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: - Animated Weather Particles

struct WeatherParticleView: View {
    let weatherCode: Int

    @State private var particles: [WeatherParticle] = []
    @State private var animationTimer: Timer?

    private var particleConfig: (emoji: String, count: Int, speed: ClosedRange<Double>)? {
        switch weatherCode {
        case 51, 53, 55, 56, 57: return ("💧", 6, 1.5...2.5) // drizzle
        case 61, 63, 65, 66, 67, 80, 81, 82: return ("🌧", 8, 1.0...2.0) // rain
        case 71, 73, 75, 77, 85, 86: return ("❄️", 7, 2.0...3.5) // snow
        case 95, 96, 99: return ("⚡", 4, 0.8...1.5) // thunderstorm
        case 0: return ("✨", 3, 3.0...5.0) // clear - subtle sparkles
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.symbol)
                        .font(.system(size: particle.size))
                        .opacity(particle.opacity)
                        .position(x: particle.x * geo.size.width, y: particle.y * geo.size.height)
                        .blur(radius: particle.blur)
                }
            }
        }
        .clipped()
        .onAppear { startParticles() }
        .onDisappear { stopParticles() }
        .onChange(of: weatherCode) { _, _ in
            particles.removeAll()
            startParticles()
        }
    }

    private func startParticles() {
        guard let config = particleConfig else { return }
        // Seed initial particles
        for _ in 0..<config.count {
            particles.append(WeatherParticle(
                symbol: config.emoji,
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 6...10),
                opacity: Double.random(in: 0.15...0.4),
                speed: Double.random(in: config.speed),
                blur: CGFloat.random(in: 0...1)
            ))
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                for i in particles.indices {
                    particles[i].y += CGFloat(0.05 / particles[i].speed)
                    // Gentle horizontal drift
                    particles[i].x += CGFloat.random(in: -0.003...0.003)
                    // Reset when off-screen
                    if particles[i].y > 1.1 {
                        particles[i].y = -0.1
                        particles[i].x = CGFloat.random(in: 0...1)
                        particles[i].opacity = Double.random(in: 0.15...0.4)
                    }
                }
            }
        }
    }

    private func stopParticles() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

struct WeatherParticle: Identifiable {
    let id = UUID()
    var symbol: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var blur: CGFloat
}

final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var hostingController: NSHostingController<SettingsView>?

    func showSettings() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        self.hostingController = hostingController  // strong reference prevents dealloc
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Top Notch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 500))
        window.minSize = NSSize(width: 600, height: 450)
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case appearance = "Appearance"
        case volume = "Volume"
        case brightness = "Brightness"
        case battery = "Battery"
        case weather = "Weather"
        case music = "Music"
        case youtube = "YouTube"
        case browser = "Browser"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .appearance: return "paintpalette.fill"
            case .volume: return "speaker.wave.3.fill"
            case .brightness: return "sun.max.fill"
            case .battery: return "battery.100"
            case .weather: return "cloud.sun.fill"
            case .music: return "music.note"
            case .youtube: return "play.rectangle.fill"
            case .browser: return "globe"
            case .about: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .general: return .gray
            case .appearance: return .indigo
            case .volume: return .blue
            case .brightness: return .orange
            case .battery: return .green
            case .weather: return .cyan
            case .music: return .pink
            case .youtube: return .red
            case .browser: return .blue
            case .about: return .purple
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "sparkles").font(.system(size: 20)).foregroundStyle(.purple)
                    Text("Top Notch").font(.system(size: 16, weight: .bold))
                }
                .padding(.vertical, 16)
                Divider()
                List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(tab.color.opacity(selectedTab == tab ? 0.25 : 0.15)).frame(width: 32, height: 32)
                            Image(systemName: tab.icon).font(.system(size: 14, weight: .medium)).foregroundStyle(tab.color)
                        }
                        Text(tab.rawValue).font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                    }
                    .padding(.vertical, 6)
                    .scaleEffect(selectedTab == tab ? 1.02 : 1.0)
                    .animation(.spring(duration: 0.25, bounce: 0.3), value: selectedTab)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .general: GeneralSettingsView()
                case .appearance: AppearanceSettingsView()
                case .volume: VolumeSettingsView()
                case .brightness: BrightnessSettingsView()
                case .battery: BatterySettingsView()
                case .weather: WeatherSettingsView()
                case .music: MusicSettingsView()
                case .youtube: YouTubeSettingsView()
                case .browser: BrowserSettingsView()
                case .about: AboutSettingsView()
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
            .animation(.spring(duration: 0.3, bounce: 0.2), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 450)
    }
}

struct SettingsHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @State private var iconScale: CGFloat = 0.8

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                // Subtle glow behind the icon
                RoundedRectangle(cornerRadius: 18).fill(color.opacity(0.12)).frame(width: 68, height: 68).blur(radius: 8)
                RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: icon).font(.system(size: 24, weight: .medium)).foregroundStyle(color)
            }
            .scaleEffect(iconScale)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
                    iconScale = 1.0
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 22, weight: .bold))
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            VStack(spacing: 0) { content }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool
    @State private var isHovering = false
    @State private var iconBounce = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(color)
            }
            .scaleEffect(iconBounce ? 1.1 : 1.0)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(isHovering ? 0.03 : 0))
        .cornerRadius(8)
        .onHover { isHovering = $0 }
        .onChange(of: isOn) { _ in
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) { iconBounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(duration: 0.2)) { iconBounce = false }
            }
        }
    }
}

struct SettingsPickerRow<T: Hashable>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { option in Text(option.1).tag(option.0) }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("expandOnHover") private var expandOnHover = true
    @AppStorage("showHapticFeedback") private var showHapticFeedback = true
    @AppStorage("autoCollapseDelay") private var autoCollapseDelay = 4.0
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("hideFromDock") private var hideFromDock = false
    @AppStorage("unlockSoundEnabled") private var unlockSoundEnabled = true
    @AppStorage("showLockIndicator") private var showLockIndicator = true
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "General", subtitle: "Basic app settings", icon: "gearshape.fill", color: .gray)

                SettingsSection(title: "System") {
                    SettingsToggleRow(title: "Launch at Login", subtitle: "Start Top Notch when you log in", icon: "power", color: .green, isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in LaunchAtLogin.setEnabled(newValue) }
                    Divider().padding(.horizontal)
                    SettingsToggleRow(title: "Hide from Dock", subtitle: hideFromDock ? "App is only accessible via the notch" : "Only show in menu bar area", icon: "dock.arrow.down.rectangle", color: .blue, isOn: $hideFromDock)
                        .onChange(of: hideFromDock) { _, newValue in NSApp.setActivationPolicy(newValue ? .accessory : .regular) }
                    if hideFromDock {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("The app will only be accessible via the notch and right-click context menu. Use the context menu to open Settings or Quit.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }
                }

                SettingsSection(title: "Lock Screen") {
                    if AppBuildVariant.current.supportsLockScreenIndicators {
                        SettingsToggleRow(title: "Lock Indicator", subtitle: "Show lock icon when screen is locked", icon: "lock.fill", color: .orange, isOn: $showLockIndicator)
                        Divider().padding(.horizontal)
                        SettingsToggleRow(title: "Unlock Sound", subtitle: "Play sound when screen unlocks", icon: "speaker.wave.2.fill", color: .green, isOn: $unlockSoundEnabled)
                    } else {
                        SettingsCompatibilityNote(
                            title: "Not available in App Store build",
                            message: "Lock screen indicators depend on private system integrations and are only enabled in the Direct build."
                        )
                    }
                }

                SettingsSection(title: "Behavior") {
                    SettingsToggleRow(title: "Expand on Hover", subtitle: "Open menu when hovering over notch", icon: "cursorarrow.motionlines", color: .orange, isOn: $expandOnHover)
                    Divider().padding(.horizontal)
                    SettingsToggleRow(title: "Haptic Feedback", subtitle: "Vibration on interactions", icon: "hand.tap.fill", color: .purple, isOn: $showHapticFeedback)
                    Divider().padding(.horizontal)
                    SettingsPickerRow(title: "Auto Collapse", subtitle: "Time before menu closes", icon: "timer", color: .cyan, selection: $autoCollapseDelay, options: [(2.0, "2s"), (4.0, "4s"), (6.0, "6s"), (0.0, "Never")])
                }

                SettingsSection(title: "Reset") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset All Settings")
                                .font(.system(size: 14, weight: .medium))
                            Text("Restore all settings to their defaults")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: { showResetConfirmation = true }) {
                            Text("Reset")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Reset", role: .destructive) {
                                resetAllSettings()
                            }
                        } message: {
                            Text("This will restore all Top Notch settings to their default values. This cannot be undone.")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                SettingsSection(title: "Keyboard Shortcuts") {
                    VStack(alignment: .leading, spacing: 0) {
                        ShortcutRow(keys: "⌘⇧Y", action: "Open YouTube in notch")
                        Divider().padding(.horizontal)
                        ShortcutRow(keys: "⌥Space", action: "Play / Pause media")
                        Divider().padding(.horizontal)
                        ShortcutRow(keys: "⌥←", action: "Previous track")
                        Divider().padding(.horizontal)
                        ShortcutRow(keys: "⌥→", action: "Next track")
                        Divider().padding(.horizontal)
                        ShortcutRow(keys: "Space", action: "Play/Pause (video player)")
                        Divider().padding(.horizontal)
                        ShortcutRow(keys: "F", action: "Fullscreen (video player)")
                        Divider().padding(.horizontal)
                        ShortcutRow(keys: "Esc", action: "Close video player")
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private func resetAllSettings() {
        let keys = [
            "expandOnHover", "showHapticFeedback", "autoCollapseDelay",
            "launchAtLogin", "hideFromDock", "unlockSoundEnabled",
            "showLockIndicator", "hudDisplayMode", "showVolumeHUD",
            "volumeShowPercent", "showBrightnessHUD", "brightnessShowPercent",
            "showBatteryIndicator", "chargingSoundEnabled", "showMusicActivity",
            "showMusicVisualizer", "youtubeAutoplay", "youtubeDefaultSize",
            "youtubeRememberPosition", "youtubeDefaultQuality", "youtubePlaybackSpeed",
            "youtubeClipboardDetection", "sponsorBlockEnabled", "returnDislikeEnabled",
            "notchWeatherCity", "weatherUnit", "showWeatherCard",
            "weatherRefreshInterval", "browserHomepage", "browserSearchEngine",
            "browserMobileMode", "browserClearOnClose", "browserJavaScript",
            "browserBlockPopups"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // Re-sync local @AppStorage bindings
        expandOnHover = true
        showHapticFeedback = true
        autoCollapseDelay = 4.0
        launchAtLogin = false
        hideFromDock = false
        unlockSoundEnabled = true
        showLockIndicator = true
        NSApp.setActivationPolicy(.regular)
    }
}

struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(action)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            HStack(spacing: 4) {
                ForEach(Array(keys.split(separator: " ").enumerated()), id: \.offset) { _, key in
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            }
                        )
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("hudDisplayMode") private var hudDisplayMode = "progressBar"
    @State private var previewLevel: CGFloat = 0.65

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(title: "Appearance", subtitle: "Customize how HUDs look", icon: "paintpalette.fill", color: .indigo)

                SettingsSection(title: "HUD Display Mode") {
                    VStack(spacing: 0) {
                        ForEach(["minimal", "progressBar", "notched"], id: \.self) { mode in
                            HUDModeRow(mode: mode, isSelected: hudDisplayMode == mode) {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) { hudDisplayMode = mode }
                            }
                            if mode != "notched" { Divider().padding(.horizontal) }
                        }
                    }
                }

                SettingsSection(title: "HUD Preview") {
                    VStack(spacing: 16) {
                        HStack { Text("Volume").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary); Spacer() }
                        Group {
                            if hudDisplayMode == "minimal" {
                                HStack {
                                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(previewLevel * 100))%").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white).monospacedDigit()
                                }
                            } else if hudDisplayMode == "notched" { NotchedVolumeHUD(level: previewLevel, muted: false) }
                            else { ProgressBarVolumeHUD(level: previewLevel, muted: false) }
                        }
                        .animation(.spring(duration: 0.3, bounce: 0.15), value: hudDisplayMode)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)

                        Slider(value: $previewLevel, in: 0...1, step: 0.01)
                            .tint(.indigo)
                    }
                    .padding()
                }

                SettingsSection(title: "Notch Expansion Preview") {
                    VStack(spacing: 12) {
                        HStack { Text("How the notch expands when activated").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary); Spacer() }
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(white: 0.08))
                                .frame(height: 80)

                            NotchShape(topRadius: 6, bottomRadius: 14)
                                .fill(.black)
                                .frame(width: 160, height: 52)
                                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                                .overlay(alignment: .bottom) {
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.08)).frame(width: 44, height: 24)
                                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.08)).frame(width: 44, height: 24)
                                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.08)).frame(width: 44, height: 24)
                                    }
                                    .padding(.bottom, 6)
                                }
                        }
                    }
                    .padding()
                }
                Spacer()
            }
            .padding(24)
        }
    }
}

struct HUDModeRow: View {
    let mode: String
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var flashHighlight = false

    private var title: String {
        switch mode {
        case "minimal": return "Minimal"
        case "progressBar": return "Progress Bar"
        case "notched": return "Notched"
        default: return mode
        }
    }

    private var description: String {
        switch mode {
        case "minimal": return "Compact inline display, no expansion"
        case "progressBar": return "Classic style with progress bar"
        case "notched": return "Premium segmented design"
        default: return ""
        }
    }

    private var icon: String {
        switch mode {
        case "minimal": return "minus.rectangle"
        case "progressBar": return "slider.horizontal.3"
        case "notched": return "rectangle.split.3x1"
        default: return "square"
        }
    }

    var body: some View {
        Button(action: {
            flashHighlight = true
            onSelect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) { flashHighlight = false }
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1)).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                    Text(description).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(flashHighlight ? Color.blue.opacity(0.08) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: flashHighlight)
        }
        .buttonStyle(.plain)
    }
}

struct VolumeSettingsView: View {
    @AppStorage("showVolumeHUD") private var showVolumeHUD = true
    @AppStorage("volumeShowPercent") private var volumeShowPercent = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Volume HUD", subtitle: "Customize volume indicator", icon: "speaker.wave.3.fill", color: .blue)
                SettingsSection(title: "General") {
                    SettingsToggleRow(title: "Enable Volume HUD", subtitle: "Replace system volume overlay", icon: "speaker.wave.2.fill", color: .blue, isOn: $showVolumeHUD)
                }
                if showVolumeHUD {
                    SettingsSection(title: "Display") {
                        SettingsToggleRow(title: "Show Percentage", subtitle: "Display volume percentage", icon: "percent", color: .cyan, isOn: $volumeShowPercent)
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }
}

struct BrightnessSettingsView: View {
    @AppStorage("showBrightnessHUD") private var showBrightnessHUD = true
    @AppStorage("brightnessShowPercent") private var brightnessShowPercent = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Brightness HUD", subtitle: "Customize brightness indicator", icon: "sun.max.fill", color: .orange)
                SettingsSection(title: "General") {
                    if AppBuildVariant.current.supportsInterceptedBrightnessHUD {
                        SettingsToggleRow(title: "Enable Brightness HUD", subtitle: "Replace system brightness overlay", icon: "sun.max.fill", color: .orange, isOn: $showBrightnessHUD)
                    } else {
                        SettingsCompatibilityNote(
                            title: "Direct build only",
                            message: "Brightness interception uses private display APIs, so the App Store build leaves the system brightness HUD unchanged."
                        )
                    }
                }
                if showBrightnessHUD && AppBuildVariant.current.supportsInterceptedBrightnessHUD {
                    SettingsSection(title: "Display") {
                        SettingsToggleRow(title: "Show Percentage", subtitle: "Display brightness percentage", icon: "percent", color: .yellow, isOn: $brightnessShowPercent)
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }
}

struct BatterySettingsView: View {
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("chargingSoundEnabled") private var chargingSoundEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Battery", subtitle: "Charging notifications", icon: "battery.100", color: .green)
                SettingsSection(title: "Indicators") {
                    SettingsToggleRow(title: "Charging Indicator", subtitle: "Show when plugged in or unplugged", icon: "bolt.fill", color: .green, isOn: $showBatteryIndicator)
                    Divider().padding(.horizontal)
                    SettingsToggleRow(title: "Charging Sound", subtitle: "Play sound on plug/unplug", icon: "speaker.wave.2.fill", color: .blue, isOn: $chargingSoundEnabled)
                }
                Spacer()
            }
            .padding(24)
        }
    }
}

struct MusicSettingsView: View {
    @AppStorage("showMusicActivity") private var showMusicActivity = true
    @AppStorage("showMusicVisualizer") private var showMusicVisualizer = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Music", subtitle: "Now Playing indicator", icon: "music.note", color: .pink)
                SettingsSection(title: "Display") {
                    if AppBuildVariant.current.supportsAdvancedMediaControls {
                        SettingsToggleRow(title: "Show Music Activity", subtitle: "Display when music is playing", icon: "music.note", color: .pink, isOn: $showMusicActivity)
                        Divider().padding(.horizontal)
                        SettingsToggleRow(title: "Audio Visualizer", subtitle: "Animated bars when playing", icon: "waveform", color: .green, isOn: $showMusicVisualizer)
                    } else {
                        SettingsCompatibilityNote(
                            title: "Direct build only",
                            message: "System-wide now playing control relies on MediaRemote and is excluded from the App Store build."
                        )
                    }
                }
                SettingsSection(title: "Supported Apps") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AppBuildVariant.current.supportsAdvancedMediaControls ? ["Apple Music", "Spotify", "TIDAL", "Deezer", "Amazon Music", "Safari", "Chrome", "Firefox", "Arc"] : ["Direct build required for supported-app integration"], id: \.self) { app in
                            HStack {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text(app).font(.system(size: 13))
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                Spacer()
            }
            .padding(24)
        }
    }
}

struct AboutSettingsView: View {
    @State private var isCheckingUpdates = false
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero branding section
                VStack(spacing: 16) {
                    ZStack {
                        // Gradient background
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.3),
                                        Color.blue.opacity(0.2),
                                        Color.pink.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 140)
                        
                        HStack(spacing: 20) {
                            // Logo representation
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple, Color.pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .purple.opacity(0.5), radius: 15, y: 5)
                                
                                // Notch shape inside logo
                                VStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.black)
                                        .frame(width: 40, height: 16)
                                    Rectangle()
                                        .fill(.black)
                                        .frame(width: 40, height: 20)
                                        .clipShape(
                                            .rect(
                                                topLeadingRadius: 0,
                                                bottomLeadingRadius: 12,
                                                bottomTrailingRadius: 12,
                                                topTrailingRadius: 0
                                            )
                                        )
                                }
                                .offset(y: -8)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(y: 15)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Top Notch")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                Text("Your notch, elevated.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("Version \(appVersion) (\(buildNumber))")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.top, 4)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                // Features section
                SettingsSection(title: "Features") {
                    VStack(alignment: .leading, spacing: 0) {
                        FeatureRow(icon: "speaker.wave.3.fill", color: .blue, title: "Volume & Brightness HUD", description: "Beautiful notch-integrated controls")
                        Divider().padding(.horizontal)
                        FeatureRow(icon: "music.note", color: .pink, title: "Now Playing", description: AppBuildVariant.current.supportsAdvancedMediaControls ? "Media controls with album art" : "Direct build only")
                        Divider().padding(.horizontal)
                        FeatureRow(icon: "play.rectangle.fill", color: .red, title: "YouTube Player", description: "Watch videos in floating window")
                        Divider().padding(.horizontal)
                        FeatureRow(icon: "battery.100.bolt", color: .green, title: "Battery Monitor", description: "Charging animations & alerts")
                        Divider().padding(.horizontal)
                        FeatureRow(icon: "lock.fill", color: .orange, title: "Lock Screen", description: AppBuildVariant.current.supportsLockScreenIndicators ? "Works above the lock screen" : "Direct build only")
                    }
                }
                
                // Updates section
                SettingsSection(title: "Updates") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Check for Updates")
                                .font(.system(size: 14, weight: .medium))
                            Text("You're running the latest version")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            isCheckingUpdates = true
                            // Simulate update check
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isCheckingUpdates = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                if isCheckingUpdates {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(isCheckingUpdates ? "Checking..." : "Check Now")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isCheckingUpdates)
                    }
                    .padding()
                }
                
                // Links section
                SettingsSection(title: "Links") {
                    VStack(spacing: 0) {
                        LinkRow(icon: "globe", color: .blue, title: "Website", url: "https://topnotch.app")
                        Divider().padding(.horizontal)
                        LinkRow(icon: "bubble.left.fill", color: .cyan, title: "Twitter / X", url: "https://twitter.com/topnotchapp")
                        Divider().padding(.horizontal)
                        LinkRow(icon: "chevron.left.forwardslash.chevron.right", color: .gray, title: "GitHub", url: "https://github.com/topnotch/app")
                    }
                }
                
                // Credits section
                SettingsSection(title: "Credits") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Developer")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Mark Kozhydlo")
                        }
                        Divider()
                        HStack {
                            Text("Design")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Inspired by Dynamic Island")
                        }
                        Divider()
                        HStack {
                            Text("License")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("MIT License")
                        }
                    }
                    .font(.system(size: 13))
                    .padding()
                }
                
                // Footer
                HStack {
                    Spacer()
                    Text("Made with ❤️ for the Mac community")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(24)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SettingsCompatibilityNote: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct LinkRow: View {
    let icon: String
    let color: Color
    let title: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct YouTubeSettingsView: View {
    @AppStorage("youtubeAutoplay") private var autoplay = true
    @AppStorage("youtubeDefaultSize") private var defaultSize = "medium"
    @AppStorage("youtubeRememberPosition") private var rememberPosition = true
    @AppStorage("youtubeDefaultQuality") private var defaultQuality = "auto"
    @AppStorage("youtubePlaybackSpeed") private var playbackSpeed = 1.0
    @AppStorage("youtubeClipboardDetection") private var clipboardDetection = true
    @AppStorage("sponsorBlockEnabled") private var sponsorBlockEnabled = true
    @AppStorage("returnDislikeEnabled") private var returnDislikeEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(
                    title: "YouTube",
                    subtitle: "Video player settings",
                    icon: "play.rectangle.fill",
                    color: .red
                )

                SettingsSection(title: "Playback") {
                    SettingsToggleRow(
                        title: "Autoplay Videos",
                        subtitle: "Start playing when opened",
                        icon: "play.fill",
                        color: .green,
                        isOn: $autoplay
                    )
                    Divider().padding(.horizontal)
                    SettingsPickerRow(
                        title: "Default Quality",
                        subtitle: "Preferred video resolution",
                        icon: "4k.tv",
                        color: .blue,
                        selection: $defaultQuality,
                        options: [
                            ("auto", "Auto"),
                            ("2160", "4K"),
                            ("1080", "1080p"),
                            ("720", "720p"),
                            ("480", "480p")
                        ]
                    )
                    Divider().padding(.horizontal)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "gauge.with.needle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Playback Speed")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Default speed for videos")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(playbackSpeed, specifier: "%.1f")x")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                                .frame(width: 44)
                        }
                        Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.25)
                            .tint(.orange)
                            .padding(.leading, 54)
                            .padding(.trailing, 14)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                
                SettingsSection(title: "Window") {
                    SettingsPickerRow(
                        title: "Default Size",
                        subtitle: "Initial player window size",
                        icon: "rectangle.expand.vertical",
                        color: .purple,
                        selection: $defaultSize,
                        options: [
                            ("small", "Small"),
                            ("medium", "Medium"),
                            ("large", "Large")
                        ]
                    )
                    Divider().padding(.horizontal)
                    SettingsToggleRow(
                        title: "Remember Position",
                        subtitle: "Restore window location on reopen",
                        icon: "square.and.arrow.down",
                        color: .cyan,
                        isOn: $rememberPosition
                    )
                }
                
                SettingsSection(title: "Detection") {
                    SettingsToggleRow(
                        title: "Auto-detect YouTube URLs",
                        subtitle: "Offer to open YouTube links copied to clipboard",
                        icon: "doc.on.clipboard",
                        color: .red,
                        isOn: $clipboardDetection
                    )
                }

                SettingsSection(title: "Enhanced Features (Direct Edition)") {
                    if AppBuildVariant.current == .direct {
                        SettingsToggleRow(title: "SponsorBlock", subtitle: "Auto-skip sponsor segments", icon: "forward.fill", color: .green, isOn: $sponsorBlockEnabled)
                        Divider().padding(.horizontal)
                        SettingsToggleRow(title: "Return YouTube Dislike", subtitle: "Show dislike counts on videos", icon: "hand.thumbsdown.fill", color: .blue, isOn: $returnDislikeEnabled)
                    } else {
                        SettingsCompatibilityNote(
                            title: "Direct build only",
                            message: "SponsorBlock and Return YouTube Dislike are available in the Direct edition."
                        )
                    }
                }

                SettingsSection(title: "Quick Open") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test Player")
                                .font(.system(size: 14, weight: .medium))
                            Text("Open a demo video to verify the player works")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            let knownGoodVideoID = "M7lc1UVf-VE"
                            NotificationCenter.default.post(name: .openInlineYouTubeVideo, object: knownGoodVideoID)
                        }) {
                            Label("Play Demo", systemImage: "play.fill")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
}



// MARK: - City Search Field with Autocomplete

struct CitySearchField: View {
    @Binding var city: String
    @State private var searchText = ""
    @State private var suggestions: [CityResult] = []
    @State private var isSearching = false
    @State private var showSuggestions = false
    @State private var searchTask: Task<Void, Never>?

    struct CityResult: Identifiable, Decodable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let admin1: String?
        let country: String?

        var displayName: String {
            [name, admin1, country].compactMap { $0 }.joined(separator: ", ")
        }
    }

    struct GeoResponse: Decodable {
        let results: [CityResult]?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Search city...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        guard newValue.count >= 2 else {
                            suggestions = []
                            showSuggestions = false
                            return
                        }
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            await searchCities(query: newValue)
                        }
                    }

                if isSearching {
                    ProgressView().scaleEffect(0.6)
                }
            }

            if showSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { result in
                        Button(action: {
                            city = result.name
                            searchText = result.displayName
                            showSuggestions = false
                            suggestions = []
                            NotificationCenter.default.post(name: NSNotification.Name("refreshWeather"), object: nil)
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.cyan)
                                    .font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(result.name)
                                        .font(.system(size: 13, weight: .medium))
                                    if let admin = result.admin1, let country = result.country {
                                        Text("\(admin), \(country)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if result.id != suggestions.last?.id {
                            Divider().padding(.horizontal, 8)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        }
        .onAppear { searchText = city }
    }

    private func searchCities(query: String) async {
        await MainActor.run { isSearching = true }
        defer { Task { @MainActor in isSearching = false } }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=5&language=en&format=json") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GeoResponse.self, from: data)
            await MainActor.run {
                suggestions = response.results ?? []
                showSuggestions = !suggestions.isEmpty
            }
        } catch {
            await MainActor.run { suggestions = [] }
        }
    }
}

struct WeatherSettingsView: View {
    @AppStorage("notchWeatherCity") private var weatherCity = "San Francisco"
    @AppStorage("weatherUnit") private var weatherUnit = "celsius"
    @AppStorage("showWeatherCard") private var showWeatherCard = true
    @AppStorage("weatherRefreshInterval") private var weatherRefreshInterval = 30.0  // minutes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Weather", subtitle: "Configure weather display", icon: "cloud.sun.fill", color: .cyan)

                SettingsSection(title: "Location") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: "mappin.and.ellipse").font(.system(size: 16, weight: .medium)).foregroundStyle(.cyan)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("City").font(.system(size: 14, weight: .medium))
                                Text("Enter your city name for weather data").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                        
                        CitySearchField(city: $weatherCity)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                SettingsSection(title: "Display") {
                    SettingsToggleRow(title: "Show Weather Card", subtitle: "Display weather in notch expansion", icon: "cloud.fill", color: .cyan, isOn: $showWeatherCard)
                    Divider().padding(.horizontal)
                    SettingsPickerRow(
                        title: "Temperature Unit",
                        subtitle: "Celsius or Fahrenheit",
                        icon: "thermometer.medium",
                        color: .orange,
                        selection: $weatherUnit,
                        options: [("celsius", "°C"), ("fahrenheit", "°F")]
                    )
                    Divider().padding(.horizontal)
                    SettingsPickerRow(
                        title: "Refresh Interval",
                        subtitle: "How often to update weather",
                        icon: "arrow.clockwise",
                        color: .blue,
                        selection: $weatherRefreshInterval,
                        options: [(15.0, "15 min"), (30.0, "30 min"), (60.0, "1 hour"), (120.0, "2 hours")]
                    )
                }

                SettingsSection(title: "Data Source") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Open-Meteo API").font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("Free, no API key").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Text("Weather data is provided by Open-Meteo, a free and open-source weather API. No API key required.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

struct BrowserSettingsView: View {
    @AppStorage("browserHomepage") private var homepage = "https://m.youtube.com"
    @AppStorage("browserSearchEngine") private var searchEngine = "google"
    @AppStorage("browserMobileMode") private var mobileMode = true
    @AppStorage("browserClearOnClose") private var clearOnClose = false
    @AppStorage("browserJavaScript") private var javaScriptEnabled = true
    @AppStorage("browserBlockPopups") private var blockPopups = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Browser", subtitle: "Mini browser settings", icon: "globe", color: .blue)

                SettingsSection(title: "Homepage") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: "house.fill").font(.system(size: 16, weight: .medium)).foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Homepage URL").font(.system(size: 14, weight: .medium))
                                Text("Page loaded when browser opens").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                        
                        TextField("https://m.youtube.com", text: $homepage)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                        
                        HStack(spacing: 8) {
                            Button("YouTube") { homepage = "https://m.youtube.com" }
                                .buttonStyle(.bordered).controlSize(.small)
                            Button("Google") { homepage = "https://www.google.com" }
                                .buttonStyle(.bordered).controlSize(.small)
                            Button("Twitter/X") { homepage = "https://mobile.twitter.com" }
                                .buttonStyle(.bordered).controlSize(.small)
                            Button("Reddit") { homepage = "https://www.reddit.com" }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                SettingsSection(title: "Search") {
                    SettingsPickerRow(
                        title: "Search Engine",
                        subtitle: "Used when typing text in URL bar",
                        icon: "magnifyingglass",
                        color: .orange,
                        selection: $searchEngine,
                        options: [
                            ("google", "Google"),
                            ("duckduckgo", "DuckDuckGo"),
                            ("bing", "Bing"),
                            ("youtube", "YouTube Search")
                        ]
                    )
                }

                SettingsSection(title: "Behavior") {
                    SettingsToggleRow(title: "Mobile Mode", subtitle: "Request mobile versions of websites", icon: "iphone", color: .green, isOn: $mobileMode)
                    Divider().padding(.horizontal)
                    SettingsToggleRow(title: "Block Pop-ups", subtitle: "Prevent pop-up windows", icon: "xmark.rectangle", color: .red, isOn: $blockPopups)
                    Divider().padding(.horizontal)
                    SettingsToggleRow(title: "JavaScript", subtitle: "Enable JavaScript execution", icon: "curlybraces", color: .purple, isOn: $javaScriptEnabled)
                    Divider().padding(.horizontal)
                    SettingsToggleRow(title: "Clear on Close", subtitle: "Clear browsing data when browser closes", icon: "trash", color: .gray, isOn: $clearOnClose)
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

enum LaunchAtLogin {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
    }
}
