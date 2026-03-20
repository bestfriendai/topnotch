import Combine
import EventKit
import SwiftUI

// MARK: - Design Colors (focused)
// Colors without a NotchDesign equivalent
private let cyanFV = Color(red: 0.024, green: 0.714, blue: 0.831)

// MARK: - Media Focused View

struct MediaFocusedView: View {
    @StateObject private var mediaController = MediaRemoteController.shared
    @StateObject private var lyricsStore = LyricsStore.shared
    @StateObject private var queueStore = MusicQueueStore.shared
    @AppStorage("lyricsEnabled") private var lyricsEnabled = true
    @AppStorage("showAlbumArt") private var showAlbumArt = true
    @AppStorage("nowPlayingControls") private var showControls = true
    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var accentColor: Color { Color(info.appColor) }

    @State private var artworkGlowPulse = false
    @State private var isHoveringPlayPause = false
    @State private var isHoveringPrevious = false
    @State private var isHoveringNext = false

    var body: some View {
        VStack(spacing: 0) {
        HStack(spacing: 16) {
            // 160x160 Glowing Album Art (sized to fit 320pt card with padding 16)
            if showAlbumArt {
            ZStack {
                if let artwork = info.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 160)
                        .cornerRadius(14)
                        .blur(radius: 20)
                        .opacity(0.4)
                        .offset(y: 6)
                        .scaleEffect(artworkGlowPulse ? 1.1 : 1.0)

                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 160)
                        .cornerRadius(14)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Color(hex: "FA2D48"), Color(hex: "9E1A30")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 160, height: 160)
                        .shadow(color: Color(hex: "FA2D48").opacity(0.4), radius: 20, y: 6)

                    Image(systemName: info.appIcon)
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 180, height: 180)
            .clipped()
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    artworkGlowPulse = true
                }
            }
            } // end if showAlbumArt

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title.isEmpty ? NSLocalizedString("media.notPlaying", comment: "") : info.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                        .lineLimit(1)

                    Text(info.artist.isEmpty ? NSLocalizedString("media.unknownArtist", comment: "") : info.artist)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(NotchDesign.textMuted)
                        .lineLimit(1)
                }

                // Full Scrubber
                MediaScrubber(
                    progress: info.progress,
                    elapsedTime: info.elapsedTimeString,
                    remainingTime: info.remainingTimeString,
                    isPlaying: info.isPlaying,
                    accentColor: accentColor,
                    totalDuration: info.duration > 0 ? info.duration : nil
                ) { progress in
                    mediaController.seekToProgress(progress)
                }

                // Large Playback Controls
                if showControls {
                HStack(spacing: 32) {
                    Button(action: {
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        mediaController.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .scaleEffect(isHoveringPrevious ? 1.08 : 1.0)
                            .animation(.spring(duration: 0.2), value: isHoveringPrevious)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPrevious = $0 }

                    Button(action: {
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        mediaController.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(NotchDesign.textPrimary)
                                .frame(width: 56, height: 56)
                            Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.black)
                                .offset(x: info.isPlaying ? 0 : 1)
                        }
                        .scaleEffect(isHoveringPlayPause ? 1.08 : 1.0)
                        .animation(.spring(duration: 0.2), value: isHoveringPlayPause)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPlayPause = $0 }

                    Button(action: {
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        mediaController.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .scaleEffect(isHoveringNext ? 1.08 : 1.0)
                            .animation(.spring(duration: 0.2), value: isHoveringNext)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringNext = $0 }

                    Button(action: { /* Repeat not supported via MediaRemote */ }) {
                        Image(systemName: "repeat")
                            .font(.system(size: 18))
                            .foregroundStyle(NotchDesign.textSecondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                } // end if showControls

                // "Playing from" badge
                if !info.appName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: info.appIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(NotchDesign.textSecondary)
                        Text(String(format: NSLocalizedString("media.playingFrom", comment: ""), info.appName))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchDesign.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(NotchDesign.elevated))
                }
            }
        }
        .padding(16)

        // Lyrics section
        if lyricsEnabled && !lyricsStore.lines.isEmpty {
            lyricsSection
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        } // end outer VStack
        .frame(maxWidth: .infinity)
        .onAppear {
            fetchLyrics()
            Task { await queueStore.fetchQueue(appName: info.appName) }
        }
        .onChange(of: info.title) { _, _ in
            fetchLyrics()
            Task { await queueStore.fetchQueue(appName: info.appName) }
        }
        .onChange(of: info.elapsedTime) { _, newTime in
            if info.isPlaying {
                lyricsStore.updateCurrentLine(elapsedTime: newTime)
            }
        }
    }

    private var lyricsSection: some View {
        lyricsScrollContent
    }

    private var lyricsScrollContent: some View {
        let activeIndex = lyricsStore.currentLineIndex
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(Array(lyricsStore.lines.enumerated()), id: \.element.id) { idx, line in
                        LyricLineView(line: line, isActive: idx == activeIndex)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .frame(height: 80)
            .onChange(of: lyricsStore.currentLineIndex) { _, newIdx in
                if newIdx < lyricsStore.lines.count {
                    let lineID = lyricsStore.lines[newIdx].id
                    withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(lineID, anchor: .center) }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func fetchLyrics() {
        guard lyricsEnabled, !info.title.isEmpty else { return }
        Task { await lyricsStore.fetchLyrics(artist: info.artist, title: info.title, album: info.album) }
    }
}

// MARK: - Lyric Line View (helper to avoid type-check complexity)

private struct LyricLineView: View {
    let line: LRCLine
    let isActive: Bool
    var body: some View {
        Text(line.text.isEmpty ? "♪" : line.text)
            .id(line.id)
            .font(.system(size: isActive ? 14 : 12, weight: isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.3))
            .multilineTextAlignment(.center)
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - Weather Focused View

struct WeatherFocusedView: View {
    @ObservedObject var weatherStore: NotchWeatherStore

    @State private var selectedDayIndex: Int? = nil
    @State private var tempOpacity: Double = 1.0
    @State private var daysAppeared = false

    /// Gradient background colors based on weather condition
    private var conditionGradient: LinearGradient {
        let colors: [Color]
        switch weatherStore.weatherCode {
        case 0: // Clear sky - warm golden
            colors = [
                Color(red: 0.95, green: 0.68, blue: 0.20).opacity(0.12),
                Color(red: 0.90, green: 0.45, blue: 0.10).opacity(0.06),
                Color.clear
            ]
        case 1, 2, 3: // Partly cloudy - soft blue
            colors = [
                Color(red: 0.35, green: 0.55, blue: 0.80).opacity(0.10),
                Color(red: 0.50, green: 0.60, blue: 0.70).opacity(0.05),
                Color.clear
            ]
        case 45, 48: // Fog - muted grey
            colors = [
                Color(white: 0.55).opacity(0.12),
                Color(white: 0.45).opacity(0.06),
                Color.clear
            ]
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: // Rain - cool blue
            colors = [
                Color(red: 0.15, green: 0.40, blue: 0.75).opacity(0.14),
                Color(red: 0.10, green: 0.55, blue: 0.80).opacity(0.07),
                Color.clear
            ]
        case 71, 73, 75, 77, 85, 86: // Snow - icy white-blue
            colors = [
                Color(red: 0.70, green: 0.80, blue: 0.95).opacity(0.12),
                Color(red: 0.50, green: 0.65, blue: 0.85).opacity(0.06),
                Color.clear
            ]
        case 95, 96, 99: // Thunderstorm - deep purple
            colors = [
                Color(red: 0.45, green: 0.20, blue: 0.70).opacity(0.14),
                Color(red: 0.30, green: 0.15, blue: 0.55).opacity(0.08),
                Color.clear
            ]
        default:
            colors = [Color.clear, Color.clear, Color.clear]
        }
        return LinearGradient(colors: colors, startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    var body: some View {
        ZStack {
            // Ambient live weather animation (rain streaks, snow, sun rays, etc.)
            WeatherAmbientCanvas(weatherCode: weatherStore.weatherCode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: weatherStore.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NotchDesign.amber)
                        .symbolRenderingMode(.hierarchical)
                    Text(NSLocalizedString("weather.title", comment: ""))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                    Spacer(minLength: 0)
                    if !weatherStore.cityName.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                            Text(weatherStore.cityName.components(separatedBy: ", ").first ?? weatherStore.cityName)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(NotchDesign.textTertiary)
                    }
                }

                // Main weather display
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Large temperature with roll animation
                        Text(weatherStore.temperatureText)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .opacity(tempOpacity)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.4), value: weatherStore.temperatureText)
                            .onChange(of: weatherStore.temperatureText) { oldVal, newVal in
                                if oldVal != newVal {
                                    withAnimation(.easeOut(duration: 0.15)) { tempOpacity = 0.5 }
                                    withAnimation(.easeIn(duration: 0.3).delay(0.15)) { tempOpacity = 1.0 }
                                }
                            }

                        Text(weatherStore.conditionText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(NotchDesign.textMuted)

                        HStack(spacing: 10) {
                            if let h = weatherStore.highTemp {
                                HStack(spacing: 3) {
                                    Text(NSLocalizedString("weather.high", comment: ""))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(NotchDesign.textSecondary)
                                    Text(h)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(NotchDesign.red)
                                }
                            }
                            if let l = weatherStore.lowTemp {
                                HStack(spacing: 3) {
                                    Text(NSLocalizedString("weather.low", comment: ""))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(NotchDesign.textSecondary)
                                    Text(l)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(NotchDesign.blue)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    AnimatedWeatherIcon(
                        symbolName: weatherStore.symbolName,
                        weatherCode: weatherStore.weatherCode,
                        size: 52
                    )
                }

                // 7-day tappable forecast
                if !weatherStore.forecastDays.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(weatherStore.forecastDays.prefix(7).enumerated()), id: \.offset) { index, day in
                            DayForecastCard(
                                day: day,
                                isSelected: selectedDayIndex == index,
                                appeared: daysAppeared,
                                staggerIndex: index
                            ) {
                                withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                                    selectedDayIndex = selectedDayIndex == index ? nil : index
                                }
                            }
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            daysAppeared = true
                        }
                    }
                }

                // Hourly strip — slides in when a day is selected
                if let idx = selectedDayIndex, idx < weatherStore.forecastDays.count {
                    let dayKey = weatherStore.forecastDays[idx].dateKey
                    let hours = weatherStore.hoursByDay[dayKey] ?? []
                    if !hours.isEmpty {
                        HourlyStrip(entries: hours)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity.animation(.easeOut(duration: 0.15))
                            ))
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(conditionGradient)
        .onDisappear {
            daysAppeared = false
            selectedDayIndex = nil
        }
    }
}

// MARK: - Day Forecast Card

private struct DayForecastCard: View {
    let day: NotchWeatherStore.ForecastDay
    let isSelected: Bool
    let appeared: Bool
    let staggerIndex: Int
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(day.dayLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? NotchDesign.textPrimary : NotchDesign.textSecondary)
                    .lineLimit(1)
                Text(day.emoji)
                    .font(.system(size: 17))
                Text(day.temp)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NotchDesign.textPrimary)
                Text(day.lowTemp)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(NotchDesign.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? NotchDesign.elevated : NotchDesign.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? NotchDesign.borderStrong : NotchDesign.borderSubtle,
                                lineWidth: isSelected ? 1.0 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(appeared ? (isHovering ? 1.04 : 1.0) : 0.75)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(
            .spring(duration: 0.45, bounce: 0.3).delay(Double(staggerIndex) * 0.04),
            value: appeared
        )
        .animation(.spring(duration: 0.2), value: isHovering)
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

// MARK: - Hourly Strip

private struct HourlyStrip: View {
    let entries: [NotchWeatherStore.HourlyEntry]
    @State private var appeared = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    VStack(spacing: 3) {
                        Text(entry.hour)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(NotchDesign.textTertiary)
                            .lineLimit(1)
                        Text(entry.emoji)
                            .font(.system(size: 14))
                        Text(entry.temp)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NotchDesign.textPrimary)
                    }
                    .frame(width: 40, height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(NotchDesign.cardBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
                            )
                    )
                    .scaleEffect(appeared ? 1.0 : 0.8)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(
                        .spring(duration: 0.3, bounce: 0.25).delay(Double(index) * 0.015),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
    }
}

// MARK: - Weather Ambient Canvas

/// Live condition-based animation drawn via Canvas + TimelineView at 30fps.
/// Rain streaks, snowfall, sun rays, fog drifts, thunder flashes.
private struct WeatherAmbientCanvas: View {
    let weatherCode: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                switch weatherCode {
                case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
                    drawRain(&context, size: size, time: t)
                case 71, 73, 75, 77, 85, 86:
                    drawSnow(&context, size: size, time: t)
                case 95, 96, 99:
                    drawThunder(&context, size: size, time: t)
                case 0:
                    drawSunRays(&context, size: size, time: t)
                case 45, 48:
                    drawFog(&context, size: size, time: t)
                default:
                    break
                }
            }
        }
        .allowsHitTesting(false)
        .opacity(0.6)
    }

    private func drawRain(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        for i in 0..<18 {
            let seed = Double(i) * 137.508
            let x = (sin(seed * 0.7) * 0.5 + 0.5) * size.width
            let speed = 0.4 + Double(i % 5) * 0.07
            let phase = (time * speed + Double(i) * 0.11).truncatingRemainder(dividingBy: 1.0)
            let y = phase * (size.height + 24) - 12
            let opacity = 0.12 + 0.10 * abs(sin(seed * 1.3))
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 1.5, y: y + 11))
            context.stroke(path, with: .color(.cyan.opacity(opacity)), lineWidth: 1.0)
        }
    }

    private func drawSnow(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        for i in 0..<12 {
            let seed = Double(i) * 137.508
            let xBase = (sin(seed * 0.7) * 0.5 + 0.5) * size.width
            let speed = 0.10 + Double(i % 3) * 0.03
            let phase = (time * speed + Double(i) * 0.09).truncatingRemainder(dividingBy: 1.0)
            let y = phase * (size.height + 14) - 8
            let x = xBase + sin(time * 0.45 + seed) * 14
            let radius: CGFloat = 1.5 + CGFloat(i % 3) * 0.6
            let opacity = 0.18 + 0.14 * abs(sin(seed * 1.3))
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(opacity))
            )
        }
    }

    private func drawThunder(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        // Occasional double flash — subtle white then purple
        let cycle = (time * 1.4).truncatingRemainder(dividingBy: 5.0)
        if cycle < 0.12 {
            let alpha = (1.0 - cycle / 0.12) * 0.10
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(alpha)))
        }
        let cycle2 = ((time * 1.4) + 0.25).truncatingRemainder(dividingBy: 5.0)
        if cycle2 < 0.08 {
            let alpha = (1.0 - cycle2 / 0.08) * 0.07
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.purple.opacity(alpha)))
        }
    }

    private func drawSunRays(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let cx = size.width * 0.83
        let cy = size.height * 0.13
        let rayCount = 8
        for i in 0..<rayCount {
            let angle = Double(i) * (Double.pi * 2.0 / Double(rayCount)) + time * 0.12
            let innerR = CGFloat(14)
            let outerR = CGFloat(22 + (i % 3) * 7) + innerR
            let opacity = 0.08 + 0.05 * sin(time * 0.8 + Double(i))
            var path = Path()
            path.move(to: CGPoint(x: cx + CGFloat(cos(angle)) * innerR, y: cy + CGFloat(sin(angle)) * innerR))
            path.addLine(to: CGPoint(x: cx + CGFloat(cos(angle)) * outerR, y: cy + CGFloat(sin(angle)) * outerR))
            context.stroke(path, with: .color(.yellow.opacity(opacity)), lineWidth: 1.5)
        }
    }

    private func drawFog(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        for i in 0..<4 {
            let yBase = size.height * CGFloat(i) / 4.0 + size.height * 0.1
            let drift = CGFloat(sin(time * 0.15 + Double(i) * 1.1)) * 8
            var path = Path()
            path.move(to: CGPoint(x: 0, y: yBase + drift))
            path.addCurve(
                to: CGPoint(x: size.width, y: yBase + drift + 6),
                control1: CGPoint(x: size.width * 0.3, y: yBase + drift - 8),
                control2: CGPoint(x: size.width * 0.7, y: yBase + drift + 14)
            )
            context.stroke(path, with: .color(.white.opacity(0.04 + 0.02 * Double(i))), lineWidth: 10)
        }
    }
}

// MARK: - Animated Weather Icon

/// Subtle condition-based animation for weather SF Symbols.
/// Sun: slow rotation, Clouds: gentle horizontal drift,
/// Rain: slight bounce, Snow: gentle float.
struct AnimatedWeatherIcon: View {
    let symbolName: String
    let weatherCode: Int
    let size: CGFloat

    @State private var rotation: Double = 0
    @State private var offset: CGFloat = 0
    @State private var bounce: CGFloat = 0

    private var iconColor: Color {
        switch weatherCode {
        case 0: return .yellow
        case 1, 2, 3: return .white
        case 45, 48: return Color(white: 0.7)
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return .cyan
        case 71, 73, 75, 77, 85, 86: return Color(white: 0.9)
        case 95, 96, 99: return .purple
        default: return NotchDesign.amber
        }
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(iconColor)
            .symbolRenderingMode(.hierarchical)
            .rotationEffect(.degrees(isSunny ? rotation : 0))
            .offset(x: isCloudy ? offset : 0, y: isRain ? bounce : (isSnow ? offset : 0))
            .onAppear { startAnimation() }
            .onChange(of: weatherCode) { _, _ in
                rotation = 0; offset = 0; bounce = 0
                startAnimation()
            }
    }

    private var isSunny: Bool { weatherCode == 0 }
    private var isCloudy: Bool { [1, 2, 3, 45, 48].contains(weatherCode) }
    private var isRain: Bool { [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99].contains(weatherCode) }
    private var isSnow: Bool { [71, 73, 75, 77, 85, 86].contains(weatherCode) }

    private func startAnimation() {
        if isSunny {
            // Slow continuous rotation
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else if isCloudy {
            // Gentle horizontal drift
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                offset = 4
            }
        } else if isRain {
            // Slight bounce
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                bounce = 3
            }
        } else if isSnow {
            // Gentle float up and down
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                offset = -4
            }
        }
    }
}

// MARK: - Calendar Focused View

struct CalendarFocusedView: View {
    @StateObject private var store = CalendarStore.shared

    private let calendarRedFV = Color(red: 1.0, green: 0.271, blue: 0.227)
    private let cal = Calendar.current

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left: Today + Mini month calendar
            VStack(alignment: .leading, spacing: 14) {
                // Header with today's date prominent
                VStack(alignment: .leading, spacing: 2) {
                    Text(fullDayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(calendarRedFV)
                    Text(todayDateString)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                }

                // Mini month calendar grid
                VStack(spacing: 4) {
                    // Weekday headers: Mon-Sun
                    HStack(spacing: 0) {
                        ForEach(orderedWeekdaySymbols, id: \.self) { sym in
                            Text(sym)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NotchDesign.textTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Date grid
                    let weeks = monthWeeks()
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 0) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                if let day = day {
                                    let isToday = cal.isDateInToday(day)
                                    Text("\(cal.component(.day, from: day))")
                                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                                        .foregroundStyle(isToday ? .white : (isCurrentMonth(day) ? NotchDesign.textPrimary : NotchDesign.textTertiary))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 22)
                                        .background(
                                            Circle()
                                                .fill(isToday ? calendarRedFV : Color.clear)
                                                .frame(width: 22, height: 22)
                                        )
                                } else {
                                    Text("")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 22)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NotchDesign.cardBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
                )
            }
            .frame(width: 240)

            // Right: Events list
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(calendarRedFV)
                    Text(NSLocalizedString("calendar.todaysEvents", comment: ""))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                    Spacer(minLength: 0)
                }

                if store.events.isEmpty {
                    VStack(spacing: 8) {
                        Spacer(minLength: 4)
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(NotchDesign.textTertiary)
                        Text(NSLocalizedString("calendar.noEvents", comment: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(NotchDesign.textSecondary)
                        Spacer(minLength: 4)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 6) {
                        ForEach(store.events.prefix(4), id: \.eventIdentifier) { event in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(cgColor: event.calendar.cgColor))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(NotchDesign.textPrimary)
                                        .lineLimit(1)
                                    Text(formatEventTime(event))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(NotchDesign.textSecondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(NotchDesign.cardBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
                            )
                        }
                    }
                }

                Spacer(minLength: 0)

                // Open Calendar link
                Button(action: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
                }) {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("calendar.openCalendar", comment: ""))
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(NotchDesign.blue)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var orderedWeekdaySymbols: [String] {
        // Mon-Sun order
        let symbols = cal.veryShortWeekdaySymbols // S M T W T F S
        return Array(symbols[1...]) + [symbols[0]]
    }

    private static let dayNameFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }()
    private static let todayDateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"; return f
    }()
    private static let eventTimeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var fullDayName: String {
        Self.dayNameFmt.string(from: Date())
    }

    private var todayDateString: String {
        Self.todayDateFmt.string(from: Date())
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        cal.component(.month, from: date) == cal.component(.month, from: Date())
    }

    /// Returns weeks of the current month, where each week is Mon-Sun.
    /// nil entries represent days outside the month grid.
    private func monthWeeks() -> [[Date?]] {
        let today = Date()
        let month = cal.component(.month, from: today)
        let year = cal.component(.year, from: today)

        guard let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        // weekday: 1=Sun, 2=Mon ... 7=Sat. Convert to Mon=0 index.
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let mondayIndex = (firstWeekday + 5) % 7 // Mon=0, Tue=1 ... Sun=6

        var grid: [Date?] = Array(repeating: nil, count: mondayIndex)

        for day in range {
            if let date = cal.date(from: DateComponents(year: year, month: month, day: day)) {
                grid.append(date)
            }
        }

        // Pad to fill last week
        while grid.count % 7 != 0 {
            grid.append(nil)
        }

        return stride(from: 0, to: grid.count, by: 7).map { Array(grid[$0..<min($0+7, grid.count)]) }
    }

    private func formatEventTime(_ event: EKEvent) -> String {
        if event.isAllDay { return NSLocalizedString("calendar.allDay", comment: "") }
        return Self.eventTimeFmt.string(from: event.startDate)
    }
}

// MARK: - Pomodoro Focused View

struct PomodoroFocusedView: View {
    @StateObject private var timer = PomodoroTimer.shared

    var body: some View {
        HStack(spacing: 24) {
            // Left: Progress ring with time
            VStack(spacing: 12) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(NotchDesign.borderSubtle, lineWidth: 10)
                        .frame(width: 160, height: 160)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            AngularGradient(
                                colors: [NotchDesign.orange.opacity(0.6), NotchDesign.orange],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: timer.progress)

                    // Glow at tip
                    if timer.progress > 0.01 {
                        Circle()
                            .fill(NotchDesign.orange)
                            .frame(width: 14, height: 14)
                            .shadow(color: NotchDesign.orange.opacity(0.6), radius: 6)
                            .offset(y: -80)
                            .rotationEffect(.degrees(360 * timer.progress))
                    }

                    VStack(spacing: 2) {
                        Text(timer.timeString)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .monospacedDigit()

                        Text(timer.isBreak ? "BREAK" : "FOCUS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NotchDesign.orange)
                            .tracking(1.5)
                    }
                }

                // Session dots
                HStack(spacing: 8) {
                    ForEach(0..<timer.totalSessions, id: \.self) { i in
                        Circle()
                            .fill(i < timer.completedSessions ? NotchDesign.orange : NotchDesign.borderSubtle)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(String(format: NSLocalizedString("pomodoro.session", comment: ""), timer.completedSessions + 1, timer.totalSessions))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchDesign.textSecondary)
            }

            // Right: Controls + presets
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NotchDesign.orange)
                    Text(NSLocalizedString("pomodoro.title", comment: ""))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                    Spacer(minLength: 0)
                }

                // Duration editor: -5 / display / +5
                if !timer.isRunning {
                    HStack(spacing: 10) {
                        Button(action: { timer.adjustDuration(byMinutes: -5) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(NotchDesign.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(NotchDesign.elevated))
                                .overlay(Circle().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Text("\(timer.workDurationMinutes) min")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .frame(width: 70)
                            .monospacedDigit()

                        Button(action: { timer.adjustDuration(byMinutes: 5) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(NotchDesign.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(NotchDesign.elevated))
                                .overlay(Circle().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    // Preset buttons
                    HStack(spacing: 8) {
                        ForEach([25, 45, 60], id: \.self) { mins in
                            Button(action: { timer.setDuration(minutes: Double(mins)) }) {
                                Text("\(mins)m")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(timer.workDurationMinutes == mins ? .white : NotchDesign.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(timer.workDurationMinutes == mins ? NotchDesign.orange : NotchDesign.elevated)
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(timer.workDurationMinutes == mins ? Color.clear : NotchDesign.borderSubtle, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Playback controls
                HStack(spacing: 20) {
                    Button(action: timer.reset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(NotchDesign.elevated))
                            .overlay(Circle().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: timer.togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(NotchDesign.orange)
                                .frame(width: 52, height: 52)
                                .shadow(color: NotchDesign.orange.opacity(0.3), radius: 10, y: 2)
                            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.black)
                                .offset(x: timer.isRunning ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: timer.skip) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(NotchDesign.elevated))
                            .overlay(Circle().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Clipboard Focused View

struct ClipboardFocusedView: View {
    @StateObject private var clipboard = ClipboardHistoryStore.shared
    @State private var copiedItemID: UUID?
    @AppStorage("aiSummarizationEnabled") private var aiEnabled = true
    @State private var summaries: [UUID: String] = [:]
    @State private var summarizingIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "clipboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(cyanFV)
                Text(NSLocalizedString("clipboard.title", comment: ""))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(NotchDesign.textPrimary)
                Spacer(minLength: 0)
                if !clipboard.items.isEmpty {
                    Text("\(clipboard.items.count) items")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                }
            }

            // List of clipboard items -- scrollable, newest first
            if clipboard.items.isEmpty {
                // Empty state
                VStack(spacing: 10) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(NotchDesign.textTertiary.opacity(0.5))
                    Text(NSLocalizedString("clipboard.nothingCopied", comment: ""))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NotchDesign.textSecondary)
                    Text(NSLocalizedString("clipboard.copyPrompt", comment: ""))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotchDesign.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(Array(clipboard.items.enumerated()), id: \.element.id) { index, item in
                            clipboardFocusedItem(item: item, index: index)
                        }
                    }
                }
            }

            // NSLocalizedString("clipboard.clearAll", comment: "") button at the bottom
            if !clipboard.items.isEmpty {
                HStack {
                    Spacer()
                    Button(action: { clipboard.clearAll() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .medium))
                            Text(NSLocalizedString("clipboard.clearAll", comment: ""))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(NotchDesign.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(NotchDesign.red.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private func clipboardFocusedItem(item: ClipboardItem, index: Int) -> some View {
        let isCopied = copiedItemID == item.id
        return HStack(spacing: 12) {
            // Type icon with colored background
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: item.type == .url ? "link" : item.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.iconColor)
            }

            // Content preview (up to 2 lines)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    clipTypePill(for: item.type)
                    Text(item.timeAgo)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchDesign.textTertiary)
                }
            }

            Spacer(minLength: 8)

            // Copy feedback
            if isCopied {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                    Text(NSLocalizedString("clipboard.copied", comment: ""))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // AI Summarize button — only for text/code with enough content
            if aiEnabled && item.type != .url && item.content.count > 80 {
                let isSummarizing = summarizingIDs.contains(item.id)
                let hasSummary = summaries[item.id] != nil
                Button(action: {
                    guard !isSummarizing && !hasSummary else { return }
                    summarizingIDs.insert(item.id)
                    Task {
                        let result = await OnDeviceAIHelper.shared.summarize(item.content)
                        await MainActor.run {
                            summarizingIDs.remove(item.id)
                            if let s = result { summaries[item.id] = s }
                        }
                    }
                }) {
                    Image(systemName: isSummarizing ? "ellipsis" : (hasSummary ? "sparkles" : "sparkle"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(hasSummary ? Color(hex: "BF5AF2") : NotchDesign.textTertiary.opacity(0.6))
                        .symbolEffect(.pulse, isActive: isSummarizing)
                }
                .buttonStyle(.plain)
                .help(hasSummary ? summaries[item.id]! : "Summarize with AI")
            }

            // Delete button (X)
            Button(action: { clipboard.removeItem(item) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(NotchDesign.textTertiary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        // Show AI summary below if available
        .overlay(alignment: .bottom) {
            if let summary = summaries[item.id] {
                Text(summary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "BF5AF2").opacity(0.9))
                    .lineLimit(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "BF5AF2").opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .offset(y: 32)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCopied ? Color.green.opacity(0.06) : NotchDesign.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isCopied ? Color.green.opacity(0.3) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            clipboard.copyItem(item)
            withAnimation(.easeInOut(duration: 0.15)) { copiedItemID = item.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.2)) { copiedItemID = nil }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isCopied)
    }

    private func clipTypePill(for type: ClipboardItem.ClipboardItemType) -> some View {
        let (label, color): (String, Color) = {
            switch type {
            case .text: return ("Text", cyanFV)
            case .url: return ("URL", NotchDesign.blue)
            case .code: return ("Code", NotchDesign.green)
            }
        }()

        return Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

// MARK: - Battery Focused View

struct BatteryFocusedView: View {
    @StateObject private var store = BatteryDeviceStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("battery.title", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchDesign.textSecondary)
                .padding(.bottom, 10)

            if store.devices.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "battery.100percent")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: "34D399").opacity(0.4))
                        Text(NSLocalizedString("battery.noDevices", comment: ""))
                            .font(.system(size: 13))
                            .foregroundStyle(NotchDesign.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(store.devices) { device in
                            BatteryDeviceRow(device: device)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct BatteryDeviceRow: View {
    let device: DeviceBattery

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.type.icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: device.levelColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                        Capsule()
                            .fill(Color(hex: device.levelColor))
                            .frame(width: geo.size.width * CGFloat(device.level) / 100, height: 5)
                    }
                }
                .frame(height: 5)
            }

            Text("\(device.level)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: device.levelColor))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)

            if device.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "34D399"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NotchDesign.cardBg))
    }
}

// MARK: - Shortcuts Focused View

struct ShortcutsFocusedView: View {
    @StateObject private var store = ShortcutsStore.shared

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("shortcuts.title", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchDesign.textSecondary)
                .padding(.bottom, 10)

            if store.isLoading {
                Spacer()
                HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                Spacer()
            } else if store.shortcuts.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: "BF5AF2").opacity(0.4))
                        Text(NSLocalizedString("shortcuts.noShortcuts", comment: ""))
                            .font(.system(size: 13))
                            .foregroundStyle(NotchDesign.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(store.shortcuts) { item in
                            ShortcutButton(item: item, store: store)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { Task { await store.fetchShortcuts() } }
    }
}

private struct ShortcutButton: View {
    let item: ShortcutItem
    @ObservedObject var store: ShortcutsStore
    @State private var isHovered = false
    private var isRunning: Bool { store.isRunning && store.lastRunName == item.name }

    var body: some View {
        Button(action: { store.runShortcut(item.name) }) {
            VStack(spacing: 6) {
                ZStack {
                    if isRunning {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: item.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "BF5AF2"))
                    }
                }
                .frame(width: 28, height: 28)

                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color(hex: "BF5AF2").opacity(0.12) : NotchDesign.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHovered ? Color(hex: "BF5AF2").opacity(0.3) : Color.clear, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Activity Feed Focused View

// MARK: - Activity Feed Focused View

private enum ActivityFilter: String, CaseIterable {
    case all = "All"
    case music = "Music"
    case clipboard = "Clipboard"
    case system = "System"

    func matches(_ event: ActivityEvent) -> Bool {
        switch self {
        case .all:       return true
        case .music:     return event.type == .music
        case .clipboard: return event.type == .clipboard
        case .system:    return event.type == .charging || event.type == .battery
                              || event.type == .focus   || event.type == .system
        }
    }
}

struct ActivityFeedFocusedView: View {
    @StateObject private var store = NotificationDigestStore.shared
    @StateObject private var focusStore = FocusStatusStore.shared
    @State private var selectedFilter: ActivityFilter = .all
    @State private var now = Date()

    private let clockTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var filteredEvents: [ActivityEvent] {
        store.events.filter { selectedFilter.matches($0) }
    }

    var body: some View {
        VStack(spacing: 10) {
            focusBanner
            filterRow
            activityList
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(clockTimer) { now = $0 }
    }

    // MARK: Focus banner

    private var focusBanner: some View {
        let accentColor = Color(hex: "A78BFA")
        let isActive = focusStore.isDNDActive
        return HStack(spacing: 12) {
            // Moon icon with animated glow when active
            ZStack {
                if isActive {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                        .blur(radius: 6)
                }
                Circle()
                    .fill(isActive ? accentColor.opacity(0.15) : Color.white.opacity(0.06))
                    .frame(width: 40, height: 40)
                Image(systemName: isActive ? "moon.fill" : "moon")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isActive ? accentColor : NotchDesign.textSecondary)
            }
            .animation(.easeInOut(duration: 0.4), value: isActive)

            VStack(alignment: .leading, spacing: 2) {
                Text(isActive ? "Do Not Disturb" : "Focus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchDesign.textPrimary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(isActive ? accentColor : Color(hex: "34D399"))
                        .frame(width: 5, height: 5)
                    Text(isActive ? "Active" : "Off")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isActive ? accentColor : NotchDesign.textSecondary)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isActive)

            Spacer()

            // Live clock
            Text(Self.timeFormatter.string(from: now))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NotchDesign.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? accentColor.opacity(0.08) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isActive ? accentColor.opacity(0.3) : Color.white.opacity(0.08),
                            lineWidth: 0.5
                        )
                )
        )
        .animation(.spring(duration: 0.4), value: isActive)
    }

    // MARK: Filter pills + clear button

    private var filterRow: some View {
        HStack(spacing: 6) {
            ForEach(ActivityFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(duration: 0.25, bounce: 0.3)) { selectedFilter = filter }
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selectedFilter == filter ? .black : NotchDesign.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selectedFilter == filter
                                      ? Color(hex: "F472B6")
                                      : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if !store.events.isEmpty {
                Button(action: { withAnimation { store.clearAll() } }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Activity list

    private var activityList: some View {
        Group {
            if filteredEvents.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "F472B6").opacity(0.35))
                    Text(selectedFilter == .all ? "No recent activity" : "No \(selectedFilter.rawValue.lowercased()) events")
                        .font(.system(size: 12))
                        .foregroundStyle(NotchDesign.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(filteredEvents) { event in
                            ActivityEventRow(event: event)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
            }
        }
    }
}

private struct ActivityEventRow: View {
    let event: ActivityEvent

    private var typeColor: Color { Color(hex: event.type.color) }

    private var timeAgo: String {
        let secs = Int(-event.timestamp.timeIntervalSinceNow)
        if secs < 10 { return "just now" }
        if secs < 60 { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Colored accent strip
            RoundedRectangle(cornerRadius: 2)
                .fill(typeColor)
                .frame(width: 2.5, height: 34)

            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(typeColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: event.type.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(typeColor)
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(1)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Text(timeAgo)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchDesign.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}

// MARK: - Quick Capture Focused View

struct QuickCaptureFocusedView: View {
    @StateObject private var store = QuickCaptureStore.shared
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("capture.title", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchDesign.textSecondary)

            // Input bar
            HStack(spacing: 8) {
                TextField("Capture a thought...", text: $store.draftText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .focused($isTextFieldFocused)
                    .onSubmit { store.saveNote() }

                let canSave = !store.draftText.trimmingCharacters(in: .whitespaces).isEmpty
                Button(action: { store.saveNote() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(canSave
                            ? Color(hex: "2DD4BF")
                            : Color(hex: "2DD4BF").opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NotchDesign.elevated))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isTextFieldFocused ? Color(hex: "2DD4BF").opacity(0.4) : Color.clear, lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: isTextFieldFocused)

            // Notes list
            if store.notes.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "2DD4BF").opacity(0.35))
                        Text(NSLocalizedString("capture.notesAppear", comment: ""))
                            .font(.system(size: 12))
                            .foregroundStyle(NotchDesign.textTertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(store.notes) { note in
                            CaptureNoteRow(note: note, store: store)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { isTextFieldFocused = true }
    }
}

private struct CaptureNoteRow: View {
    let note: CaptureNote
    @ObservedObject var store: QuickCaptureStore
    @State private var isCopied = false

    var body: some View {
        HStack(spacing: 10) {
            Text(note.text)
                .font(.system(size: 12))
                .foregroundStyle(NotchDesign.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isCopied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }

            Button(action: {
                store.copyNote(note)
                withAnimation { isCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { isCopied = false }
                }
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(NotchDesign.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: { store.deleteNote(note) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(NotchDesign.textTertiary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NotchDesign.cardBg))
        .animation(.easeInOut(duration: 0.15), value: isCopied)
    }
}
