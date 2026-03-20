import Combine
import EventKit
import SwiftUI

// MARK: - ExpandedNotchContent
// The expanded content view: HUDs, inline YouTube player, dashboard/deck, alerts, and media controls.

struct ExpandedNotchContent: View {
    @ObservedObject var state: NotchState
    @Binding var isClickExpanded: Bool

    @AppStorage("showLockIndicator") private var showLockIndicator = true
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("hudDisplayMode") private var hudDisplayMode = "progressBar"
    @AppStorage("notchWeatherCity") private var weatherCity = "San Francisco"
    @AppStorage("youtubeEnabled") private var youtubeEnabled = true
    @AppStorage("weatherEnabled") private var weatherEnabled = true
    @AppStorage("calendarEnabled") private var calendarEnabled = true
    @AppStorage("pomodoroEnabled") private var pomodoroEnabled = true
    @AppStorage("clipboardEnabled") private var clipboardEnabled = true
    @AppStorage("batteryWidgetEnabled") private var batteryWidgetEnabled = true
    @AppStorage("shortcutsWidgetEnabled") private var shortcutsWidgetEnabled = true
    @AppStorage("notificationsWidgetEnabled") private var notificationsWidgetEnabled = true
    @AppStorage("quickCaptureEnabled") private var quickCaptureEnabled = true
    @AppStorage("lyricsEnabled") private var lyricsEnabled = true

    @State private var youtubeURLInput = ""
    @State private var youtubeInputError: String?
    @StateObject private var youtubeHistory = YouTubeHistoryStore.shared
    @State private var deckDragOffset: CGFloat = 0
    @State private var verticalDragOffset: CGFloat = 0
    @State private var deckCardsAppeared = false
    @State private var deckContentAppeared = false
    @State private var hoveringCard: Int? = nil
    @State private var hoveringIcon: String? = nil

    @StateObject private var weatherStore = NotchWeatherStore()
    @StateObject private var calendarStore = CalendarStore.shared

    @State private var lockPulse = false
    @State private var unlockScale: CGFloat = 0.5
    @State private var unlockOpacity: CGFloat = 0
    @State private var chargingBoltScale: CGFloat = 0.5
    @State private var chargingGlow = false
    @State private var unplugScale: CGFloat = 1.2

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var currentDateDayName: String { Self.dayNameFormatter.string(from: Date()) }
    private var currentDateMonthDay: String { Self.monthDayFormatter.string(from: Date()) }

    var shouldShowDeck: Bool {
        state.isExpanded
            && state.hud == .none
            && !state.youtube.isShowingPlayer
            && !state.battery.showChargingAnimation
            && !state.battery.showUnplugAnimation
            && !state.system.showUnlockAnimation
            && !state.system.isScreenLocked
    }

    private var youtubePreviewVideoID: String? {
        youtubeDraftRequest?.videoID
    }

    private var youtubeDraftRequest: YouTubeURLParser.PlaybackRequest? {
        YouTubeURLParser.playbackRequest(from: youtubeURLInput)
    }

    /// Ordered list of deck cards for swipe navigation, filtered by enabled settings
    var deckCardOrder: [NotchDeckCard] {
        var cards: [NotchDeckCard] = [.home]
        if youtubeEnabled { cards.append(.youtube) }
        cards.append(.media) // Media is always available
        if weatherEnabled { cards.append(.weather) }
        if calendarEnabled { cards.append(.calendar) }
        if pomodoroEnabled { cards.append(.pomodoro) }
        if clipboardEnabled { cards.append(.clipboard) }
        if batteryWidgetEnabled { cards.append(.battery) }
        if shortcutsWidgetEnabled { cards.append(.shortcuts) }
        if notificationsWidgetEnabled { cards.append(.notifications) }
        if quickCaptureEnabled { cards.append(.quickCapture) }
        return cards
    }

    private func deckCardIndex(for card: NotchDeckCard) -> Int {
        deckCardOrder.firstIndex(of: card) ?? 0
    }

    var body: some View {
        Group {
            // Inline YouTube player must ALWAYS stay in the view tree while active.
            if state.youtube.isShowingPlayer, let videoID = state.youtube.videoID {
                inlineYouTubePlayer(videoID: videoID)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            } else {
                switch state.hud {
                case .volume, .brightness:
                    NotchHUDOverlay(hud: state.hud)
                case .none:
                    if isClickExpanded {
                        dynamicDeck
                    }
                    else if state.battery.showChargingAnimation && showBatteryIndicator {
                        BatteryChargingAlert(level: state.battery.info.level, notchWidth: state.notchWidth)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    else if state.battery.showUnplugAnimation && showBatteryIndicator {
                        unplugExpanded
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    else if state.system.showUnlockAnimation && showLockIndicator {
                        LockScreenIndicatorView()
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    else if state.system.isScreenLocked && showLockIndicator {
                        LockScreenIndicatorView()
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    else {
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
    }

    // MARK: - Inline YouTube Player

    private func inlineYouTubePlayer(videoID: String) -> some View {
        NotchInlineYouTubePlayerView(
            notchState: state,
            videoID: videoID,
            playerState: state.inlineYouTubePlayerState,
            playerController: state.inlineYouTubePlayerController,
            startTime: state.youtube.startTime
        )
        .id(videoID)
        .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
            ))
    }

    // MARK: - Music Expanded

    private func musicExpanded(app: String) -> some View {
        MediaControlView()
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        ))
    }

    // MARK: - Timer Expanded

    private func timerExpanded(remaining: TimeInterval) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: "timer").font(.system(size: 20, weight: .medium)).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("pomodoro.title", comment: "")).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(formatTime(remaining)).font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange).monospacedDigit()
            }
            Spacer()
        }
    }

    // MARK: - Unplug Expanded

    private var unplugExpanded: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.gray.opacity(0.2)).frame(width: 50, height: 50)
                Image(systemName: "powerplug.fill").font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.gray).scaleEffect(unplugScale)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("battery.unplugged", comment: "")).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text("\(state.battery.info.level)%").font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(state.battery.info.level <= 20 ? .red : .white.opacity(0.7)).monospacedDigit()
                    if let time = state.battery.info.timeRemaining, time > 0 {
                        Text(String(format: NSLocalizedString("battery.remaining", comment: ""), formatBatteryTime(time))).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            Spacer()
            BatteryBarView(level: state.battery.info.level, isCharging: false)
        }
        .onAppear { withAnimation(.spring(duration: 0.4, bounce: 0.3)) { unplugScale = 1.0 } }
        .onDisappear { unplugScale = 1.2 }
    }

    // MARK: - Dynamic Deck

    private var dynamicDeck: some View {
        VStack(spacing: 0) {
            NotchNavBar(
                state: state,
                isClickExpanded: $isClickExpanded,
                deckCardOrder: deckCardOrder
            )

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
        .offset(x: deckDragOffset, y: verticalDragOffset)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let isVertical = abs(value.translation.height) > abs(value.translation.width)
                    if isVertical {
                        if value.translation.height > 0 {
                            verticalDragOffset = value.translation.height * 0.3
                        }
                    } else {
                        let currentIndex = deckCardIndex(for: state.activeDeckCard)
                        deckDragOffset = DeckPagingLogic.resistedOffset(
                            translationWidth: value.translation.width,
                            currentIndex: currentIndex,
                            cardCount: deckCardOrder.count
                        )
                    }
                }
                .onEnded { value in
                    let isVertical = abs(value.translation.height) > abs(value.translation.width)
                    if isVertical && value.translation.height > 60 {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            verticalDragOffset = 0
                            deckDragOffset = 0
                            state.isExpanded = false
                            isClickExpanded = false
                        }
                    } else {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            verticalDragOffset = 0
                        }
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
        .onDisappear {
            deckCardsAppeared = false
            deckContentAppeared = false
        }
        .onChange(of: state.activeDeckCard) { _, newCard in
            if newCard == .youtube { prefillYouTubeInputIfPossible() }
            if newCard == .weather { refreshWeatherIfNeeded(force: weatherStore.cityName != weatherCity) }
        }
    }

    // MARK: - Notch Hub View (Home)

    private var notchHubView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                youtubeHeroCard
                    .frame(width: 340)
                    .staggeredEntrance(index: 0, appeared: deckCardsAppeared)

                nowPlayingHubCard
                    .frame(width: 260)
                    .staggeredEntrance(index: 1, appeared: deckCardsAppeared)

                weatherCalendarComboCard
                    .staggeredEntrance(index: 2, appeared: deckCardsAppeared)
            }
            .frame(maxHeight: .infinity)

            // Page indicator dots
            HStack(spacing: 5) {
                ForEach(Array(deckCardOrder.enumerated()), id: \.offset) { idx, card in
                    let isActive = state.activeDeckCard == card
                    Capsule(style: .continuous)
                        .fill(isActive ? NotchDesign.textPrimary : NotchDesign.borderStrong)
                        .frame(width: isActive ? 16 : 5, height: 5)
                        .animation(.spring(duration: 0.35, bounce: 0.45), value: isActive)
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
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(NSLocalizedString("youtube.title", comment: ""))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { navigateToDeckCard(.youtube) }

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
                    TextField(NSLocalizedString("youtube.urlPlaceholder", comment: ""), text: $youtubeURLInput)
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
                        Text(youtubeDraftRequest != nil ? NSLocalizedString("youtube.play", comment: "") : NSLocalizedString("youtube.browse", comment: ""))
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
                        Text(NSLocalizedString("youtube.browse", comment: ""))
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

                VStack(spacing: 3) {
                    Text(info.title.isEmpty ? NSLocalizedString("media.notPlaying", comment: "") : info.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(info.artist.isEmpty ? NSLocalizedString("media.unknownArtist", comment: "") : info.artist)
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
                        Text(NSLocalizedString("calendar.noUpcoming", comment: ""))
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

    // MARK: - Focused Card Content

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
            case .battery:
                focusedCardShell(accentTop: Color(hex: "0D2D1E")) { BatteryFocusedView() }
            case .shortcuts:
                focusedCardShell(accentTop: Color(hex: "1A0D2E")) { ShortcutsFocusedView() }
            case .notifications:
                focusedCardShell(accentTop: Color(hex: "2E0D1E")) { ActivityFeedFocusedView() }
            case .quickCapture:
                focusedCardShell(accentTop: Color(hex: "0D2622")) { QuickCaptureFocusedView() }
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

    func focusedHeightForCard(_ card: NotchDeckCard) -> CGFloat {
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

    // MARK: - YouTube Focused Content

    private var youtubeFocusedContent: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NotchDesign.red)
                    Text(NSLocalizedString("youtube.title", comment: ""))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                    TextField(NSLocalizedString("youtube.urlPlaceholder", comment: ""), text: $youtubeURLInput)
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

                HStack(spacing: 10) {
                    Button(action: handleBrowseOrPlay) {
                        HStack(spacing: 6) {
                            Image(systemName: youtubeDraftRequest != nil ? "play.fill" : "globe")
                                .font(.system(size: 12, weight: .semibold))
                            Text(youtubeDraftRequest != nil ? NSLocalizedString("youtube.play", comment: "") : NSLocalizedString("youtube.browse", comment: ""))
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
                                Text(NSLocalizedString("youtube.pasteAndPlay", comment: ""))
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
                                Text(NSLocalizedString("youtube.browse", comment: ""))
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

            if !youtubeHistory.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("youtube.recentlyPlayed", comment: ""))
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

    // MARK: - Helpers

    private func navigateToDeckCard(_ card: NotchDeckCard) {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            state.activeDeckCard = card
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatBatteryTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    private var clipboardYouTubeURL: String? {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              YouTubeURLParser.extractVideoID(from: clipboardString) != nil else {
            return nil
        }
        return clipboardString
    }

    private func playDetectedVideo() {
        guard let url = state.youtube.detectedURL,
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
        if let detected = state.youtube.detectedURL,
           YouTubeURLParser.extractVideoID(from: detected) != nil {
            youtubeURLInput = detected
        } else if let clipboardYouTubeURL {
            youtubeURLInput = clipboardYouTubeURL
        }
    }

    private func openInlineVideo(_ videoID: String, startTime: Int = 0) {
        guard YouTubeURLParser.isValidVideoID(videoID) else { return }

        youtubeHistory.add(videoID: videoID)
        state.youtube.startTime = startTime
        state.youtube.minimized = false

        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            state.activeDeckCard = .youtube
            state.youtube.videoID = videoID
            state.youtube.isShowingPlayer = true
            state.youtube.showPrompt = false
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
            if let detected = state.youtube.detectedURL,
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
}
