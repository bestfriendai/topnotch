import Combine
import EventKit
import SwiftUI

// MARK: - Pomodoro Timer Card

struct PomodoroDeckCard: View {
    @StateObject private var timer = PomodoroTimer()
    @State private var resetHovered = false
    @State private var playHovered = false
    @State private var skipHovered = false
    @State private var glowPulse = false

    private var accentColor: Color { timer.isBreak ? .green : .orange }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text("Focus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                // Session dots
                HStack(spacing: 4) {
                    ForEach(0..<timer.totalSessions, id: \.self) { i in
                        Circle()
                            .fill(i < timer.completedSessions ? accentColor : Color.white.opacity(0.15))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Spacer(minLength: 0)

            // Circular progress ring with timer
            ZStack {
                // Pulsing glow behind the ring when running
                if timer.isRunning {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 78, height: 78)
                        .blur(radius: 10)
                        .scaleEffect(glowPulse ? 1.15 : 0.95)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowPulse)
                }

                // Background track circle
                Circle()
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 70, height: 70)

                // Progress arc
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        AngularGradient(
                            colors: [accentColor.opacity(0.6), accentColor],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * timer.progress)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: timer.progress)
                    .shadow(color: accentColor.opacity(0.5), radius: 4)

                // Timer text centered inside ring
                VStack(spacing: 1) {
                    Text(timer.timeString)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: timer.remainingSeconds))
                        .animation(.spring(duration: 0.3), value: timer.remainingSeconds)
                }
            }
            .onAppear { glowPulse = true }

            // Status text
            Text(timer.statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            Spacer(minLength: 0)

            // Controls
            HStack(spacing: 10) {
                // Reset button
                Button(action: timer.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(resetHovered ? 0.9 : 0.6))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(resetHovered ? 0.14 : 0.08)))
                        .scaleEffect(resetHovered ? 1.1 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: resetHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in resetHovered = hovering }

                // Play/Pause button
                Button(action: timer.togglePlayPause) {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: timer.isBreak ? [.green, .green.opacity(0.8)] : [.orange, .orange.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                        .shadow(color: accentColor.opacity(playHovered ? 0.6 : 0.4), radius: playHovered ? 8 : 6, y: 2)
                        .scaleEffect(playHovered ? 1.08 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: playHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in playHovered = hovering }

                // Skip button
                Button(action: timer.skip) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(skipHovered ? 0.9 : 0.6))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(skipHovered ? 0.14 : 0.08)))
                        .scaleEffect(skipHovered ? 1.1 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: skipHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in skipHovered = hovering }
            }
        }
    }
}

// MARK: - Pomodoro Timer Model

@MainActor
final class PomodoroTimer: ObservableObject {
    @Published var remainingSeconds: Double = 25 * 60
    @Published var isRunning = false
    @Published var isBreak = false
    @Published var completedSessions = 0
    let totalSessions = 4

    private var timer: Timer?
    private let workDuration: Double = 25 * 60
    private let shortBreakDuration: Double = 5 * 60
    private let longBreakDuration: Double = 15 * 60

    var timeString: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var statusText: String {
        if !isRunning && remainingSeconds == workDuration { return "Ready to focus" }
        if isBreak { return "Take a break" }
        return "Deep focus"
    }

    var progress: CGFloat {
        let total = isBreak ? (completedSessions % 4 == 0 ? longBreakDuration : shortBreakDuration) : workDuration
        return 1.0 - (remainingSeconds / total)
    }

    func togglePlayPause() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.completePhase()
                }
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        isBreak = false
        remainingSeconds = workDuration
    }

    func skip() {
        completePhase()
    }

    private func completePhase() {
        pause()
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        if isBreak {
            // Break finished, start new work session
            isBreak = false
            remainingSeconds = workDuration
        } else {
            // Work finished
            completedSessions += 1
            isBreak = true
            remainingSeconds = completedSessions % 4 == 0 ? longBreakDuration : shortBreakDuration
        }
    }
}

// MARK: - Calendar Card

struct CalendarDeckCard: View {
    @StateObject private var store = CalendarStore()
    @State private var badgeAppeared = false
    @State private var pulseShadow = false
    @State private var hoveredEventId: String?

    private let calendar = Calendar.current
    private var today: Date { Date() }
    private var dayNumber: Int { calendar.component(.day, from: today) }
    private var weekdayShort: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: today).uppercased()
    }
    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with month and live time
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                Text(monthName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                // Live time display
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(Self.formatTime(context.date))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .monospacedDigit()
                }
            }

            // Date display
            HStack(spacing: 8) {
                // Big day number in a red rounded square (like Apple Calendar icon)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: .red.opacity(pulseShadow ? 0.45 : 0.25), radius: pulseShadow ? 8 : 5, y: 2)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseShadow)

                    VStack(spacing: -2) {
                        Text(weekdayShort)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("\(dayNumber)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(badgeAppeared ? 1.0 : 0.8)
                .opacity(badgeAppeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: badgeAppeared)
                .onAppear {
                    badgeAppeared = true
                    pulseShadow = true
                }

                // Week days row
                VStack(alignment: .leading, spacing: 4) {
                    weekRow
                }
            }

            Spacer(minLength: 0)

            // Upcoming events (max 2)
            if store.events.isEmpty {
                HStack(spacing: 4) {
                    Circle().fill(.green.opacity(0.5)).frame(width: 4, height: 4)
                    Text("No upcoming events")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    // "Today" label
                    Text("TODAY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(0.5)

                    ForEach(store.events.prefix(2), id: \.eventIdentifier) { event in
                        let isHovered = hoveredEventId == event.eventIdentifier
                        HStack(spacing: 6) {
                            // Colored dot instead of rectangle bar
                            Circle()
                                .fill(Color(cgColor: event.calendar.cgColor))
                                .frame(width: 4, height: 4)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(Self.formatEventTime(event))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(isHovered ? 0.06 : 0.0))
                        )
                        .animation(.easeOut(duration: 0.15), value: isHovered)
                        .onHover { hovering in
                            hoveredEventId = hovering ? event.eventIdentifier : nil
                        }
                    }
                }
            }
        }
    }

    private var weekRow: some View {
        let weekday = calendar.component(.weekday, from: today) // 1=Sun
        let symbols = calendar.veryShortWeekdaySymbols // ["S","M","T","W","T","F","S"]

        return HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                let isToday = (i + 1) == weekday
                Text(symbols[i])
                    .font(.system(size: 8, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .white.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .background(
                        Circle().fill(isToday ? Color.red.opacity(0.7) : Color.clear)
                    )
            }
        }
    }

    private static func formatEventTime(_ event: EKEvent) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        if event.isAllDay { return "All day" }
        return "\(f.string(from: event.startDate)) - \(f.string(from: event.endDate))"
    }

    private static func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Calendar Store

@MainActor
final class CalendarStore: ObservableObject {
    @Published var events: [EKEvent] = []
    private let store = EKEventStore()

    init() {
        requestAccess()
    }

    private func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, error in
            guard granted, error == nil else { return }
            Task { @MainActor in
                self?.fetchTodayEvents()
            }
        }
    }

    func fetchTodayEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let fetched = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        events = fetched
    }
}
