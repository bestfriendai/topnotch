import AppKit
import Combine
import EventKit
import SwiftUI

// MARK: - Design Colors (shared)
// Colors without a NotchDesign equivalent
private let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)

// MARK: - Pomodoro Timer Card

struct PomodoroDeckCard: View {
    @StateObject private var timer = PomodoroTimer.shared

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // Header: timer icon (orange) + "Focus" title
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchDesign.orange)
                Text(NSLocalizedString("pomodoro.focus", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchDesign.textPrimary)
            }

            // Progress ring: 72px diameter, stroke-only
            ZStack {
                Circle()
                    .stroke(NotchDesign.borderSubtle, lineWidth: 3)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(NotchDesign.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: timer.progress)

                // Time display centered in ring
                Text(timer.timeString)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .monospacedDigit()
            }

            // Session dots — scale up on completion
            HStack(spacing: 6) {
                ForEach(0..<timer.totalSessions, id: \.self) { i in
                    let filled = i < timer.completedSessions
                    Circle()
                        .fill(filled ? NotchDesign.orange : NotchDesign.borderSubtle)
                        .frame(width: filled ? 8 : 6, height: filled ? 8 : 6)
                        .shadow(color: filled ? NotchDesign.orange.opacity(0.6) : .clear, radius: 4)
                        .animation(.spring(duration: 0.35, bounce: 0.5), value: timer.completedSessions)
                }
            }

            // Controls: reset, play/pause, skip
            HStack(spacing: 16) {
                Button(action: timer.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(NotchDesign.elevated))
                }
                .buttonStyle(.plain)

                Button(action: timer.togglePlayPause) {
                    ZStack {
                        Circle()
                            .fill(NotchDesign.orange)
                            .frame(width: 32, height: 32)
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                            .offset(x: timer.isRunning ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)

                Button(action: timer.skip) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(NotchDesign.elevated))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Pomodoro Timer Model

@MainActor
final class PomodoroTimer: ObservableObject {
    static let shared = PomodoroTimer()

    @Published var remainingSeconds: Double = 25 * 60
    @Published var isRunning = false
    @Published var isBreak = false
    @Published var completedSessions = 0
    @Published var workDuration: Double = 25 * 60
    let totalSessions = 4

    private var timer: Timer?
    private let shortBreakDuration: Double = 5 * 60
    private let longBreakDuration: Double = 15 * 60

    // MARK: - Persistence keys
    private static let kRemaining  = "pomodoro.remainingSeconds"
    private static let kCompleted  = "pomodoro.completedSessions"
    private static let kWorkMins   = "pomodoro.workDurationMinutes"
    private static let kIsBreak    = "pomodoro.isBreak"

    private init() {
        let ud = UserDefaults.standard
        let savedMins = ud.double(forKey: Self.kWorkMins)
        if savedMins > 0 {
            workDuration = savedMins * 60
        }
        let savedRemaining = ud.double(forKey: Self.kRemaining)
        if savedRemaining > 0 {
            remainingSeconds = min(savedRemaining, workDuration)
        }
        completedSessions = ud.integer(forKey: Self.kCompleted)
        isBreak = ud.bool(forKey: Self.kIsBreak)
    }

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(remainingSeconds, forKey: Self.kRemaining)
        ud.set(completedSessions, forKey: Self.kCompleted)
        ud.set(workDuration / 60, forKey: Self.kWorkMins)
        ud.set(isBreak, forKey: Self.kIsBreak)
    }

    var timeString: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var statusText: String {
        if !isRunning && remainingSeconds == workDuration { return NSLocalizedString("pomodoro.readyToFocus", comment: "") }
        if isBreak { return NSLocalizedString("pomodoro.takeABreak", comment: "") }
        return NSLocalizedString("pomodoro.deepFocus", comment: "")
    }

    var progress: CGFloat {
        let total = isBreak ? (completedSessions > 0 && completedSessions % 4 == 0 ? longBreakDuration : shortBreakDuration) : workDuration
        guard total > 0 else { return 0 }
        return max(0, min(1, 1.0 - (remainingSeconds / total)))
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
        timer?.invalidate()
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
        persist()
    }

    func reset() {
        pause()
        isBreak = false
        remainingSeconds = workDuration
        persist()
    }

    func skip() {
        completePhase()
    }

    func setDuration(minutes: Double) {
        let newDuration = minutes * 60
        workDuration = newDuration
        if !isRunning && !isBreak {
            remainingSeconds = newDuration
        }
        persist()
    }

    func adjustDuration(byMinutes delta: Double) {
        let newMinutes = max(5, min(120, (workDuration / 60) + delta))
        setDuration(minutes: newMinutes)
    }

    var workDurationMinutes: Int {
        Int(workDuration / 60)
    }

    private func completePhase() {
        pause()
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        if isBreak {
            // Break finished, start new work session
            isBreak = false
            remainingSeconds = workDuration
        } else {
            // Work finished — dot completion is animated by .animation(..., value:) on the view
            completedSessions += 1
            isBreak = true
            remainingSeconds = completedSessions % 4 == 0 ? longBreakDuration : shortBreakDuration
        }
        persist()
    }
}

// MARK: - Calendar Card

struct CalendarDeckCard: View {
    @StateObject private var store = CalendarStore.shared
    @State private var badgeAppeared = false
    @State private var hoveredEventId: String?
    @State private var openCalHovered = false
    @State private var eventDotPulse = false

    private let calendar = Calendar.current
    private var today: Date { Date() }
    private var dayNumber: Int { calendar.component(.day, from: today) }
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private var weekdayShort: String { Self.weekdayFormatter.string(from: today).uppercased() }
    private var monthYearLabel: String { Self.monthYearFormatter.string(from: today).uppercased() }

    // Always red per spec — #FF453A
    private let calendarRed = Color(red: 1.0, green: 0.271, blue: 0.227)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: "MARCH 2026" red left, date badge right
            HStack(spacing: 0) {
                Text(monthYearLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(calendarRed)
                    .tracking(1.2)
                    .lineLimit(1)
                Spacer(minLength: 0)

                // Date badge — red gradient #FF453A -> #CC3333, cornerRadius 10
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [calendarRed, Color(red: 0.8, green: 0.2, blue: 0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 38, height: 42)

                    VStack(spacing: -1) {
                        Text(weekdayShort)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(dayNumber)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .shadow(color: calendarRed.opacity(0.35), radius: 8, y: 2)
                .scaleEffect(badgeAppeared ? 1.0 : 0.8)
                .opacity(badgeAppeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: badgeAppeared)
                .onAppear { badgeAppeared = true }
            }

            // Week row: S M T W T F S — current day highlighted with red circle
            weekRow

            // Divider — 1px white 0.07
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            // Events: colored dot (6px) + title (11px semibold white) + time (9px gray)
            if store.permissionDenied {
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.7))
                    Text(NSLocalizedString("calendar.permissionNeeded", comment: "Calendar access needed"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                .onTapGesture {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else if store.events.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green.opacity(0.7))
                    Text(NSLocalizedString("calendar.noEvents", comment: ""))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(store.events.prefix(2), id: \.eventIdentifier) { event in
                        let isHovered = hoveredEventId == event.eventIdentifier
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(cgColor: event.calendar.cgColor))
                                .frame(width: 6, height: 6)
                                .scaleEffect(eventDotPulse ? 1.15 : 1.0)
                                .opacity(eventDotPulse ? 1.0 : 0.7)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: eventDotPulse)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(Self.formatEventTime(event))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
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
                .onAppear { eventDotPulse = true }
            }

            Spacer(minLength: 0)

            // "Open Calendar" link — blue #0A84FF, 9px, with arrow-right icon
            Button(action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
            }) {
                HStack(spacing: 3) {
                    Text(NSLocalizedString("calendar.openCalendar", comment: ""))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(NotchDesign.blue)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(NotchDesign.blue)
                        .offset(x: openCalHovered ? 3 : 0)
                        .animation(.easeOut(duration: 0.2), value: openCalHovered)
                }
                .opacity(openCalHovered ? 1.0 : 0.8)
            }
            .buttonStyle(.plain)
            .onHover { openCalHovered = $0 }
        }
        .onDisappear {
            badgeAppeared = false
            eventDotPulse = false
        }
    }

    private var weekRow: some View {
        let weekday = calendar.component(.weekday, from: today)
        let symbols = calendar.veryShortWeekdaySymbols

        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let isToday = (i + 1) == weekday
                Text(symbols[i])
                    .font(.system(size: 9, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .white.opacity(0.3))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle().fill(isToday ? calendarRed : Color.clear)
                    )
            }
        }
    }

    private static let eventTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static func formatEventTime(_ event: EKEvent) -> String {
        if event.isAllDay { return NSLocalizedString("calendar.allDay", comment: "") }
        let f = Self.eventTimeFormatter
        return "\(f.string(from: event.startDate)) - \(f.string(from: event.endDate))"
    }
}

// MARK: - Calendar Store

@MainActor
final class CalendarStore: ObservableObject {
    static let shared = CalendarStore()

    @Published var events: [EKEvent] = []
    @Published var permissionDenied = false
    private let store = EKEventStore()
    private var refreshTimer: Timer?

    private init() {
        requestAccess()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, error in
                Task { @MainActor [weak self] in
                    if granted && error == nil {
                        self?.permissionDenied = false
                        self?.fetchTodayEvents()
                        self?.startPeriodicRefresh()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                Task { @MainActor [weak self] in
                    if granted && error == nil {
                        self?.permissionDenied = false
                        self?.fetchTodayEvents()
                        self?.startPeriodicRefresh()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        }
    }

    private func startPeriodicRefresh() {
        // Refresh events every 5 minutes so upcoming events stay current
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchTodayEvents()
            }
        }
    }

    func fetchTodayEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let fetched = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        events = fetched
    }
}
