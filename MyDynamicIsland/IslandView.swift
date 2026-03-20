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
                            Label(NSLocalizedString("youtube.openVideo", comment: ""), systemImage: "play.rectangle.fill")
                        }
                        .keyboardShortcut("y", modifiers: [.command, .shift])

                        if let url = state.youtube.detectedURL {
                            Button(action: { openYouTubeURL(url) }) {
                                Label(NSLocalizedString("youtube.playDetected", comment: ""), systemImage: "play.circle.fill")
                            }
                        }

                        if AppBuildVariant.current.supportsAdvancedMediaControls {
                            Divider()

                            Text(NSLocalizedString("media.controlsTooltip", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(action: {
                                MediaRemoteController.shared.togglePlayPause()
                            }) {
                                Label(NSLocalizedString("shortcut.playPause", comment: "") + "  \u{2325}Space", systemImage: "playpause.fill")
                            }
                            Button(action: {
                                MediaRemoteController.shared.previousTrack()
                            }) {
                                Label(NSLocalizedString("shortcut.previousTrack", comment: "") + "  \u{2325}\u{2190}", systemImage: "backward.fill")
                            }
                            Button(action: {
                                MediaRemoteController.shared.nextTrack()
                            }) {
                                Label(NSLocalizedString("shortcut.nextTrack", comment: "") + "  \u{2325}\u{2192}", systemImage: "forward.fill")
                            }
                        }

                        Divider()

                        Button(NSLocalizedString("menu.settings", comment: "")) { SettingsWindowController.shared.showSettings() }
                        Divider()
                        Button(NSLocalizedString("menu.quit", comment: "")) { NSApp.terminate(nil) }
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
            state.youtube.showPrompt = false
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
            state.youtube.videoID = videoID
            state.youtube.isShowingPlayer = true
            state.youtube.showPrompt = false
            state.isExpanded = true
        }
    }
}

// MARK: - NotchView

struct NotchView: View {
    @ObservedObject var state: NotchState

    @State private var hoverWorkItem: DispatchWorkItem?
    @State private var collapseWorkItem: DispatchWorkItem?
    @State private var audioLevels: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]
    @State private var audioTimerCancellable: AnyCancellable?

    @State private var isClickExpanded = false
    @State private var chargingGlowPulse = false
    @State private var gearHovered = false
    @State private var chevronHovered = false
    @State private var showExpandPulse = false

    @State private var unlockScale: CGFloat = 0.5
    @State private var unlockOpacity: CGFloat = 0

    @AppStorage("hudDisplayMode") private var hudDisplayMode = "progressBar"
    @AppStorage("showHapticFeedback") private var hapticFeedbackEnabled = true
    @AppStorage("lyricsEnabled") private var lyricsEnabled = true

    // Design-spec collapsed dimensions
    private let collapsedNotchWidth: CGFloat = 480
    private let collapsedNotchHeight: CGFloat = 36
    private let collapsedCornerRadius: CGFloat = 20
    private let expandedDashboardWidth: CGFloat = 960
    private let expandedDashboardHeight: CGFloat = 320

    private var isMinimalMode: Bool { hudDisplayMode == "minimal" }

    private var shouldShowDeck: Bool {
        state.isExpanded
            && state.hud == .none
            && !state.youtube.isShowingPlayer
            && !state.battery.showChargingAnimation
            && !state.battery.showUnplugAnimation
            && !state.system.showUnlockAnimation
            && !state.system.isScreenLocked
    }

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
        case .battery: return Color(hex: "34D399")
        case .shortcuts: return Color(hex: "BF5AF2")
        case .notifications: return Color(hex: "F472B6")
        case .quickCapture: return Color(hex: "2DD4BF")
        }
    }

    private func focusedHeightForCard(_ card: NotchDeckCard) -> CGFloat {
        switch card {
        case .youtube: return 260
        case .media: return lyricsEnabled ? 420 : 320
        case .weather: return 300
        case .calendar: return 320
        case .pomodoro: return 320
        case .clipboard: return 280
        case .fileShelf: return 200
        case .home: return 0
        case .battery: return 280
        case .shortcuts: return 300
        case .notifications: return 360
        case .quickCapture: return 300
        }
    }

    private var notchSize: CGSize {
        if state.youtube.isShowingPlayer && !state.youtube.minimized {
            return CGSize(
                width: max(collapsedNotchWidth, state.youtube.playerWidth + 32),
                height: collapsedNotchHeight + state.youtube.playerHeight + 80
            )
        }

        if shouldShowDeck && isClickExpanded {
            let isFocused = state.activeDeckCard != .home
            let cardHeight = focusedHeightForCard(state.activeDeckCard)
            let focusedHeight = collapsedNotchHeight + 42 + cardHeight + 24
            return CGSize(
                width: isFocused ? 800 : expandedDashboardWidth,
                height: isFocused ? focusedHeight : expandedDashboardHeight
            )
        }

        if case .volume = state.hud {
            return CGSize(width: collapsedNotchWidth, height: collapsedNotchHeight + 44)
        }
        if case .brightness = state.hud {
            return CGSize(width: collapsedNotchWidth, height: collapsedNotchHeight + 44)
        }
        if state.youtube.showPrompt {
            return CGSize(width: collapsedNotchWidth, height: 44)
        }
        if state.battery.showChargingAnimation || (state.battery.info.isCharging && state.isExpanded) {
            return CGSize(width: collapsedNotchWidth, height: collapsedNotchHeight + 56)
        }
        if state.system.isScreenLocked || state.system.showUnlockAnimation {
            return CGSize(width: 220, height: collapsedNotchHeight + 56)
        }

        let shouldExpand = !isMinimalMode || state.hud == .none
        var expandedHeight: CGFloat = 0
        if state.isExpanded && shouldExpand {
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

    private var audioTimerPublisher: AnyPublisher<Date, Never> {
        Timer.publish(every: 0.15, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background fill
            RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                .fill(Color.black)
                .overlay(alignment: .top) {
                    if state.isExpanded {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.05),
                                activeDeckAccent.opacity(0.18),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .frame(height: collapsedNotchHeight)
                        .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .strokeBorder(
                            state.isExpanded ? NotchDesign.borderSubtle : Color.clear,
                            lineWidth: 1
                        )
                )

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    CollapsedNotchContent(
                        state: state,
                        isMinimalMode: isMinimalMode,
                        shouldShowDeck: shouldShowDeck
                    )
                    .frame(height: collapsedNotchHeight)

                    if state.isExpanded {
                        ExpandedNotchContent(
                            state: state,
                            isClickExpanded: $isClickExpanded
                        )
                        .clipped()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .top)).combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                        ))
                    }
                }

                // Keep the YouTube WKWebView alive while minimized
                if state.youtube.minimized && !state.isExpanded,
                   state.youtube.isShowingPlayer,
                   let videoID = state.youtube.videoID {
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
            width: state.youtube.minimized && !state.isExpanded ? 520 : notchSize.width,
            height: notchSize.height
        )
        .overlay(alignment: .top) {
            if showExpandPulse {
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .strokeBorder(activeDeckAccent.opacity(0.7), lineWidth: 2)
                    .scaleEffect(showExpandPulse ? 1.12 : 1.0, anchor: .top)
                    .opacity(showExpandPulse ? 0 : 1)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.6), value: showExpandPulse)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
        .scaleEffect(state.isHovered && !state.isExpanded && !state.youtube.minimized ? 1.05 : 1.0, anchor: .top)
        .shadow(color: activeDeckAccent.opacity(state.isExpanded ? 0.18 : 0), radius: state.isExpanded ? 28 : 0, y: state.isExpanded ? 10 : 0)
        .shadow(color: .black.opacity(state.isExpanded ? 0.36 : 0), radius: state.isExpanded ? 24 : 0, y: state.isExpanded ? 12 : 0)
        .background(
            Group {
                if state.isExpanded && shouldShowDeck && isClickExpanded {
                    ZStack {
                        RoundedRectangle(cornerRadius: NotchDesign.islandRadius, style: .continuous)
                            .fill(NotchDesign.bgMain)
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
            if state.youtube.minimized && !state.isExpanded {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    state.youtube.minimized = false
                    state.isExpanded = true
                }
            } else if isClickExpanded && !shouldShowDeck && !state.youtube.isShowingPlayer {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    state.isExpanded = false
                    isClickExpanded = false
                    state.hud = .none
                }
            } else if state.youtube.showPrompt && !state.isExpanded {
                playDetectedVideo()
            } else if !state.youtube.isShowingPlayer && state.isExpanded && !isClickExpanded {
                handleTap()
            } else if !state.youtube.isShowingPlayer && !state.isExpanded { handleTap() }
        }
        .onHover { handleHover($0) }
        .onChange(of: state.activity) { _, newActivity in
            if case .music = newActivity { startAudioTimer() } else { stopAudioTimer() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("refreshWeather"))) { _ in
            // Weather refresh is handled by ExpandedNotchContent
        }
        .onAppear { if case .music = state.activity { startAudioTimer() } }
        .onDisappear {
            stopAudioTimer()
            hoverWorkItem?.cancel()
            hoverWorkItem = nil
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
        }
        .onChange(of: state.hud) { _, newValue in if newValue != .none { showHUD() } }
        .onChange(of: isClickExpanded) { _, newValue in
            if newValue {
                showExpandPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showExpandPulse = false
                }
            }
        }
        .onChange(of: state.system.showUnlockAnimation) { _, newValue in
            if newValue {
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) { state.isExpanded = true }
                unlockScale = 0.5
                unlockOpacity = 0
                scheduleCollapse(delay: 2.0)
            }
        }
        .onChange(of: state.system.isScreenLocked) { _, isLocked in
            if isLocked {
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    state.isExpanded = true
                }
                scheduleCollapse(delay: 1.5)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: state.system.isScreenLocked)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: state.system.showUnlockAnimation)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: state.youtube.showPrompt)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: state.activity)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.battery.info.isCharging)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.battery.showChargingAnimation)
    }

    // MARK: - Interaction Handlers

    private func handleTap() {
        guard !state.youtube.isShowingPlayer else { return }
        hoverWorkItem?.cancel()
        collapseWorkItem?.cancel()
        if hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
            state.activeDeckCard = .home
            state.isExpanded = true
            isClickExpanded = true
        }
    }

    private func handleHover(_ hovering: Bool) {
        if state.youtube.isShowingPlayer {
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) { state.isHovered = hovering }
            return
        }

        hoverWorkItem?.cancel()
        if hovering && hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
        withAnimation(.spring(duration: 0.25, bounce: 0.4)) { state.isHovered = hovering }

        if hovering {
            if !isClickExpanded {
                let work = DispatchWorkItem { [self] in
                    guard UserDefaults.standard.object(forKey: "expandOnHover") as? Bool ?? true else { return }
                    withAnimation(.spring(duration: 0.5, bounce: 0.35)) { self.state.isExpanded = true }
                    if self.hapticFeedbackEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
                }
                hoverWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
            }
        } else {
            if !isClickExpanded {
                collapseWorkItem?.cancel()
                let work = DispatchWorkItem { [self] in
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        self.state.isExpanded = false
                        self.state.hud = .none
                    }
                }
                collapseWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            }
        }
    }

    private func scheduleCollapse(delay: TimeInterval) {
        guard !state.youtube.isShowingPlayer else { return }
        collapseWorkItem?.cancel()
        let storedDelay = (UserDefaults.standard.object(forKey: "autoCollapseDelay") as? Int).map(Double.init) ?? (UserDefaults.standard.object(forKey: "autoCollapseDelay") as? Double) ?? 4.0
        let effectiveDelay = delay > 0 ? delay : storedDelay
        guard effectiveDelay > 0 else { return }
        let work = DispatchWorkItem { [self] in
            if !self.state.isHovered {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    self.state.isExpanded = false
                    self.isClickExpanded = false
                    self.state.hud = .none
                }
            }
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + effectiveDelay, execute: work)
    }

    private func showHUD() {
        guard !state.youtube.isShowingPlayer else { return }
        collapseWorkItem?.cancel()
        if !isMinimalMode {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { state.isExpanded = true }
        }
        let work = DispatchWorkItem { [self] in
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                if !self.state.isHovered && !self.isMinimalMode { self.state.isExpanded = false; self.isClickExpanded = false }
                self.state.hud = .none
            }
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func playDetectedVideo() {
        guard let url = state.youtube.detectedURL,
              let request = YouTubeURLParser.playbackRequest(from: url) else {
            return
        }

        guard YouTubeURLParser.isValidVideoID(request.videoID) else { return }

        YouTubeHistoryStore.shared.add(videoID: request.videoID)
        state.youtube.startTime = request.startTime
        state.youtube.minimized = false

        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            state.activeDeckCard = .youtube
            state.youtube.videoID = request.videoID
            state.youtube.isShowingPlayer = true
            state.youtube.showPrompt = false
            state.isExpanded = true
        }
    }

    // MARK: - Audio Timer

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
        let tR = min(topRadius, rect.width / 2, rect.height / 2)
        let bR = min(bottomRadius, rect.width / 2, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: tR, y: 0))
        path.addLine(to: CGPoint(x: rect.width - tR, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: tR),
            control: CGPoint(x: rect.width, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - bR))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - bR, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        path.addLine(to: CGPoint(x: bR, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - bR),
            control: CGPoint(x: 0, y: rect.height)
        )
        path.addLine(to: CGPoint(x: 0, y: tR))
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
    func staggeredEntrance(index: Int, appeared: Bool) -> some View {
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
