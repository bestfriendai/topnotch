import SwiftUI

// MARK: - NotchNavBar
// The deck navigation bar: home icon, widget icons, time, settings, and collapse button.

struct NotchNavBar: View {
    @ObservedObject var state: NotchState
    @Binding var isClickExpanded: Bool
    let deckCardOrder: [NotchDeckCard]

    @AppStorage("youtubeEnabled") private var youtubeEnabled = true
    @AppStorage("weatherEnabled") private var weatherEnabled = true
    @AppStorage("calendarEnabled") private var calendarEnabled = true
    @AppStorage("pomodoroEnabled") private var pomodoroEnabled = true
    @AppStorage("clipboardEnabled") private var clipboardEnabled = true
    @AppStorage("batteryWidgetEnabled") private var batteryWidgetEnabled = true
    @AppStorage("shortcutsWidgetEnabled") private var shortcutsWidgetEnabled = true
    @AppStorage("notificationsWidgetEnabled") private var notificationsWidgetEnabled = true
    @AppStorage("quickCaptureEnabled") private var quickCaptureEnabled = true

    @StateObject private var pomodoroTimerForNav = PomodoroTimer.shared

    var body: some View {
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
                if batteryWidgetEnabled { navHeaderButton(systemName: "battery.100percent", card: .battery) }
                if shortcutsWidgetEnabled { navHeaderButton(systemName: "wand.and.stars", card: .shortcuts) }
                if notificationsWidgetEnabled { navHeaderButton(systemName: "bell.badge", card: .notifications) }
                if quickCaptureEnabled { navHeaderButton(systemName: "pencil.and.list.clipboard", card: .quickCapture) }
            }
            .padding(4)
            .background(NotchDesign.elevated.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5))

            Spacer()

            // Right: Time + gear + collapse
            HStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(Self.formatHeaderTime(context.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .monospacedDigit()
                }

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

    // MARK: - Nav Button

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

    // MARK: - Helpers

    private func navigateToDeckCard(_ card: NotchDeckCard) {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            state.activeDeckCard = card
        }
    }

    static func formatHeaderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
