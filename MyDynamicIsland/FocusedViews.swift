import SwiftUI
import EventKit

// MARK: - Design Colors (focused)
// Colors without a NotchDesign equivalent
private let cyanFV = Color(red: 0.024, green: 0.714, blue: 0.831)

// MARK: - Media Focused View

struct MediaFocusedView: View {
    @ObservedObject private var mediaController = MediaRemoteController.shared
    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var accentColor: Color { Color(info.appColor) }

    @State private var artworkGlowPulse = false
    @State private var isHoveringPlayPause = false
    @State private var isHoveringPrevious = false
    @State private var isHoveringNext = false

    var body: some View {
        HStack(spacing: 16) {
            // 160x160 Glowing Album Art (sized to fit 320pt card with padding 16)
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

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title.isEmpty ? "Not Playing" : info.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                        .lineLimit(1)

                    Text(info.artist.isEmpty ? "---" : info.artist)
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
                                .offset(x: 1)
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

                // "Playing from" badge
                if !info.appName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: info.appIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(NotchDesign.textSecondary)
                        Text("Playing from \(info.appName)")
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
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weather Focused View

struct WeatherFocusedView: View {
    @ObservedObject var weatherStore: NotchWeatherStore

    @State private var tempOpacity: Double = 1.0

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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NotchDesign.amber)
                Text("Weather")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(NotchDesign.textPrimary)
                Spacer(minLength: 0)
                Text("Updated 2m ago")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchDesign.textTertiary)
            }

            // Main weather display
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // Large temperature with fade transition on change
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

                    // Condition
                    Text(weatherStore.conditionText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(NotchDesign.textMuted)

                    // Hi/Lo
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("H:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchDesign.textSecondary)
                            Text(weatherStore.highTemp ?? "--")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(NotchDesign.red)
                        }
                        HStack(spacing: 4) {
                            Text("L:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchDesign.textSecondary)
                            Text(weatherStore.lowTemp ?? "--")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(NotchDesign.blue)
                        }
                    }

                    // Feels like + Location on same line
                    HStack(spacing: 12) {
                        Text("Feels like \(weatherStore.temperatureText)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(NotchDesign.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11))
                                .foregroundStyle(NotchDesign.textSecondary)
                            Text(weatherStore.cityName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchDesign.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Large animated weather icon
                AnimatedWeatherIcon(
                    symbolName: weatherStore.symbolName,
                    weatherCode: weatherStore.weatherCode,
                    size: 52
                )
            }

            // 5-day forecast
            if !weatherStore.forecastDays.isEmpty {
                HStack(spacing: 8) {
                    ForEach(weatherStore.forecastDays.prefix(5)) { day in
                        VStack(spacing: 4) {
                            Text(day.dayLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(NotchDesign.textSecondary)

                            Text(day.emoji)
                                .font(.system(size: 20))

                            Text(day.temp)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(NotchDesign.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(NotchDesign.cardBg)
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(conditionGradient)
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
    @ObservedObject private var store = CalendarStore.shared

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
                    Text("Today's Events")
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
                        Text("No events today")
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
                        Text("Open Calendar")
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

    private var fullDayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: Date())
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
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        if event.isAllDay { return "All day" }
        return f.string(from: event.startDate)
    }
}

// MARK: - Pomodoro Focused View

struct PomodoroFocusedView: View {
    @ObservedObject private var timer = PomodoroTimer.shared

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

                Text("Session \(timer.completedSessions + 1) of \(timer.totalSessions)")
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
                    Text("Focus Timer")
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
    @ObservedObject private var clipboard = ClipboardHistoryStore.shared
    @State private var copiedItemID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "clipboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(cyanFV)
                Text("Clipboard History")
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
                    Text("Nothing copied yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NotchDesign.textSecondary)
                    Text("Copy text or URLs to see them here")
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

            // "Clear All" button at the bottom
            if !clipboard.items.isEmpty {
                HStack {
                    Spacer()
                    Button(action: { clipboard.clearAll() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .medium))
                            Text("Clear All")
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
                    Text("Copied!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Delete button (X)
            Button(action: { clipboard.removeItem(item) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(NotchDesign.textTertiary.opacity(0.5))
            }
            .buttonStyle(.plain)
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
