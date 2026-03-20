import SwiftUI

// MARK: - Segmented Progress Bar (shared by Volume and Brightness HUDs)

struct NotchedHUDProgressBar: View {
    let level: CGFloat
    let segmentCount: Int
    let activeColor: Color
    let inactiveColor: Color
    let segmentHeight: CGFloat
    let gap: CGFloat

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<segmentCount, id: \.self) { i in
                let isActive = CGFloat(i) < level * CGFloat(segmentCount)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isActive ? activeColor : inactiveColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: segmentHeight)
                    .shadow(color: isActive ? activeColor.opacity(0.55) : .clear, radius: 3)
                    .animation(
                        .spring(duration: 0.28, bounce: 0.18).delay(Double(i) * 0.015),
                        value: isActive
                    )
            }
        }
    }
}

// MARK: - Volume HUD
// Spec: 360pt container (cornerRadius 16, fill #0B0B0E, padding 16),
//        inner bar area 320pt x 40pt (cornerRadius 20, fill #16161A),
//        volume-2 icon 18pt, bars gap 3, height 10, percentage DM Sans 12pt 500

struct VolumeHUDView: View {
    let level: CGFloat
    let muted: Bool
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            // Speaker icon -- 18pt, white (#FAFAF9)
            Image(systemName: muted ? "speaker.slash.fill" : volumeIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(muted ? NotchDesign.textMuted : NotchDesign.textPrimary)
                .frame(width: 22)
                .contentTransition(.symbolEffect(.replace.offUp))
                .animation(.spring(duration: 0.3, bounce: 0.25), value: volumeIcon)
                .animation(.spring(duration: 0.3, bounce: 0.25), value: muted)

            // 16 segmented bars -- filled: white, unfilled: borderSubtle, height 10, gap 3
            NotchedHUDProgressBar(
                level: muted ? 0 : level,
                segmentCount: 16,
                activeColor: NotchDesign.textPrimary,
                inactiveColor: NotchDesign.borderSubtle,
                segmentHeight: 10,
                gap: 3
            )

            // Percentage -- 12pt medium, white
            Text("\(Int((muted ? 0 : level) * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchDesign.textPrimary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: Int(level * 100))
        }
        .padding(.horizontal, 16)
        .frame(width: 320, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(NotchDesign.cardBg)
        )
    }

    private var volumeIcon: String {
        if level < 0.01 { return "speaker.fill" }
        else if level < 0.33 { return "speaker.wave.1.fill" }
        else if level < 0.66 { return "speaker.wave.2.fill" }
        else { return "speaker.wave.3.fill" }
    }
}

// MARK: - Brightness HUD
// Spec: same layout as Volume, accent color #FFB547, sun icon

struct BrightnessHUDView: View {
    let level: CGFloat
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            // Sun icon -- 18pt, amber
            Image(systemName: level < 0.01 ? "sun.min.fill" : "sun.max.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NotchDesign.amber)
                .frame(width: 22)
                .contentTransition(.symbolEffect(.replace.offUp))
                .animation(.spring(duration: 0.3, bounce: 0.25), value: level < 0.01)

            // 16 segments -- filled: amber (#FFB547), unfilled: borderSubtle, height 10, gap 3
            NotchedHUDProgressBar(
                level: level,
                segmentCount: 16,
                activeColor: NotchDesign.amber,
                inactiveColor: NotchDesign.borderSubtle,
                segmentHeight: 10,
                gap: 3
            )

            // Percentage
            Text("\(Int(level * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchDesign.textPrimary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: Int(level * 100))
        }
        .padding(.horizontal, 16)
        .frame(width: 320, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(NotchDesign.cardBg)
        )
    }
}

// MARK: - Battery Charging Alert
// Spec: battery-charging icon + NSLocalizedString("battery.charging", comment: "") label (#8E8E93) + percentage (#32D583)

struct BatteryChargingAlert: View {
    let level: Int
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            // Battery icon -- green (#32D583)
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NotchDesign.green)

            // NSLocalizedString("battery.charging", comment: "") text -- muted (#8E8E93)
            Text(NSLocalizedString("battery.charging", comment: ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NotchDesign.textMuted)

            Spacer()

            // Percentage in green (#32D583)
            Text("\(level)%")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NotchDesign.green)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: level)
        }
        .padding(.horizontal, 24)
        .frame(width: 320, height: 48)
    }
}

// MARK: - YouTube Detected Alert

struct YouTubeDetectedAlert: View {
    let url: String
    let notchWidth: CGFloat
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Play icon -- red
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NotchDesign.red)

            // NSLocalizedString("youtube.linkDetected", comment: "") text
            Text(NSLocalizedString("youtube.linkDetected", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchDesign.textPrimary)
                .lineLimit(1)

            Spacer()

            // Red "Play" pill button
            Button(action: onPlay) {
                Text(NSLocalizedString("youtube.play", comment: ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(NotchDesign.red)
                    )
            }
            .buttonStyle(NotchPressButtonStyle())
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(width: 360, height: 56)
    }
}

// MARK: - Lock Screen Indicator

struct LockScreenIndicatorView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(NotchDesign.textMuted)

            Text(NSLocalizedString("system.locked", comment: ""))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NotchDesign.textSecondary)
        }
        .frame(width: 120, height: 48)
    }
}
