import SwiftUI

// MARK: - Lock Indicators

struct LockIconView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle().fill(Color.orange.opacity(0.25)).frame(width: 24, height: 24)
                .scaleEffect(isPulsing ? 1.6 : 1.0).opacity(isPulsing ? 0.0 : 0.7)
            Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold))
                .foregroundStyle(.orange).shadow(color: .orange.opacity(0.9), radius: isPulsing ? 8 : 4)
        }
        .frame(width: 28, height: 28)
        .clipped()
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
        .frame(width: 22, height: 22)
        .clipped()
        .onAppear { withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) { isPulsing = true } }
    }
}

// MARK: - Battery Indicators

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

struct CollapsedBatteryIndicator: View {
    let level: Int

    // Design spec: battery indicator 32x14, cornerRadius 4, #32D583 fill+stroke
    private var batteryColor: Color {
        if level <= 20 { return NotchDesign.red }
        if level <= 50 { return NotchDesign.orange }
        return NotchDesign.green // #32D583
    }

    var body: some View {
        HStack(spacing: 2) {
            ZStack(alignment: .leading) {
                // Outer shell: 32x14, cornerRadius 4, stroke
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(batteryColor, lineWidth: 1)
                    .frame(width: 32, height: 14)
                // Fill bar
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(batteryColor)
                    .frame(width: max(3, 26 * CGFloat(level) / 100), height: 8)
                    .padding(.leading, 3)
            }
            // Battery tip
            RoundedRectangle(cornerRadius: 1)
                .fill(batteryColor)
                .frame(width: 2, height: 6)
        }
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

    private var chargingGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "30D158"), Color(hex: "4AE68A")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(CGFloat(i) < animatedLevel / 10
                        ? (isCharging ? AnyShapeStyle(chargingGradient) : AnyShapeStyle(color))
                        : AnyShapeStyle(Color.white.opacity(0.15)))
                    .frame(width: 4, height: 18)
                    .scaleEffect(y: isCharging && pulseAnimation && CGFloat(i) < animatedLevel / 10 ? 1.1 : 1.0)
                    .shadow(color: isCharging && CGFloat(i) < animatedLevel / 10
                        ? Color(hex: "30D158").opacity(0.4) : .clear,
                        radius: 4)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { animatedLevel = CGFloat(level) }
            if isCharging { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulseAnimation = true } }
        }
        .onChange(of: level) { _, newLevel in
            withAnimation(.easeOut(duration: 0.4)) { animatedLevel = CGFloat(newLevel) }
        }
    }
}

// MARK: - Calendar Widget

struct CalendarWidgetView: View {
    private let calendar = Calendar.current

    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let yearFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy"; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let currentDay = calendar.component(.day, from: now)
            let currentWeekday = Self.weekdayFmt.string(from: now).uppercased()
            let currentMonth = Self.monthFmt.string(from: now).uppercased()
            let currentYear = Self.yearFmt.string(from: now)
            let timeString = Self.timeFmt.string(from: now)

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
                        let dayOfWeek = calendar.component(.weekday, from: now)
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
}

// MARK: - Progress Bar HUDs

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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.063), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.37), radius: 16, y: 4)
        )
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
                    Capsule().fill(Color.white.opacity(0.2)).frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFD60A"), Color(hex: "FF9F0A")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * level), height: 6)
                }
            }
            .frame(height: 6)
            if showPercent {
                Text("\(Int(level * 100))%").font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.063), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.37), radius: 16, y: 4)
        )
    }
}

// MARK: - Notched HUDs

struct NotchedVolumeHUD: View {
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
            HStack(spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CGFloat(i) < level * 16 ? (muted ? Color.gray : Color.white) : Color.white.opacity(0.15))
                        .frame(width: 6, height: 16)
                }
            }
            if showPercent {
                Text("\(Int(level * 100))%").font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(muted ? .gray : .white).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct NotchedBrightnessHUD: View {
    let level: CGFloat
    @AppStorage("brightnessShowPercent") private var showPercent = true

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
            if showPercent {
                Text("\(Int(level * 100))%").font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
    }
}
