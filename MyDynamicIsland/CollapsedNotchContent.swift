import Combine
import SwiftUI

// MARK: - CollapsedNotchContent
// Collapsed notch bar: left indicators, camera spacer, right indicators.

struct CollapsedNotchContent: View {
    @ObservedObject var state: NotchState

    let isMinimalMode: Bool
    let shouldShowDeck: Bool

    @AppStorage("showLockIndicator") private var showLockIndicator = true
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true

    @State private var waveformBars: [CGFloat] = [0.3, 0.6, 0.4]
    private let waveformTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    // Design spec: 180pt camera spacer in center
    private let cameraSpacerWidth: CGFloat = 180

    var body: some View {
        HStack(spacing: 0) {
            // Left wing
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
            .clipped()

            // Camera notch spacer - 180pt per design spec
            Color.clear.frame(width: cameraSpacerWidth)

            // Right wing
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                if isMinimalMode, case .volume(let level, let muted) = state.hud {
                    Text(muted ? NSLocalizedString("hud.mute", comment: "") : "\(Int(level * 100))%")
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
            .clipped()
        }
    }

    private func volumeIcon(for level: CGFloat) -> String {
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    @ViewBuilder
    private var leftIndicator: some View {
        if state.system.isScreenLocked && showLockIndicator {
            LockIconView()
        } else if state.system.showUnlockAnimation && showLockIndicator {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
                .shadow(color: .green.opacity(0.8), radius: 6)
                .transition(.scale.combined(with: .opacity))
        } else if (state.battery.info.isCharging || state.battery.showChargingAnimation) && showBatteryIndicator && !state.isExpanded {
            // Spec: Battery icon + charging text (#32D583) on left
            HStack(spacing: 5) {
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotchDesign.green)
                Text(NSLocalizedString("battery.charging", comment: ""))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchDesign.green)
                    .lineLimit(1)
                    .fixedSize()
            }
            .transition(.scale.combined(with: .opacity))
        } else if case .music = state.activity {
            // Album art thumbnail + song title
            HStack(spacing: 6) {
                MiniArtworkView()
                Text(MediaRemoteController.shared.nowPlayingInfo.title.isEmpty ? "Music" : MediaRemoteController.shared.nowPlayingInfo.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 100, alignment: .leading)
            }
            .transition(.scale.combined(with: .opacity))
        } else if case .timer = state.activity {
            // Spec: Orange dot (6pt) + "FOCUS" text
            HStack(spacing: 5) {
                Circle()
                    .fill(NotchDesign.orange)
                    .frame(width: 6, height: 6)
                Text(NSLocalizedString("system.focus", comment: "").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchDesign.orange)
                    .tracking(1)
            }
            .transition(.scale.combined(with: .opacity))
        } else if state.youtube.showPrompt {
            // YouTube Detected collapsed indicator
            HStack(spacing: 6) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchDesign.red)
                Text(NSLocalizedString("youtube.linkDetected", comment: ""))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .lineLimit(1)
            }
            .transition(.scale.combined(with: .opacity))
        } else if state.youtube.minimized {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 18, height: 12)
                    Image(systemName: "play.fill")
                        .font(.system(size: 5, weight: .bold))
                        .foregroundStyle(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.red.opacity(0.85))
                            .frame(width: max(geo.size.width * state.youtube.progress, 0))
                    }
                }
                .frame(height: 3)
                .frame(maxWidth: 120)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if !shouldShowDeck {
            // Idle state: brand text
            Text(NSLocalizedString("about.appName", comment: ""))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchDesign.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var rightIndicator: some View {
        if state.system.isScreenLocked && showLockIndicator {
            LockPulsingDot()
        } else if state.system.showUnlockAnimation && showLockIndicator {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        } else if (state.battery.showChargingAnimation || state.battery.info.isCharging) && showBatteryIndicator && !state.isExpanded {
            // Spec: percentage + zap icon on right for charging state
            HStack(spacing: 3) {
                Text("\(state.battery.info.level)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchDesign.green)
                    .monospacedDigit()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NotchDesign.green)
            }
            .transition(.scale.combined(with: .opacity))
        } else if state.battery.showUnplugAnimation && showBatteryIndicator {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
                .transition(.scale.combined(with: .opacity))
        } else if case .music = state.activity {
            // 3 animated green waveform bars
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(NotchDesign.green)
                        .frame(width: 3, height: waveformBars[i] * 14)
                }
            }
            .onReceive(waveformTimer) { _ in
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) {
                    waveformBars = (0..<3).map { _ in CGFloat.random(in: 0.3...1.0) }
                }
            }
            .transition(.scale.combined(with: .opacity))
        } else if case .timer(let remaining, let total) = state.activity {
            // Countdown time + small progress arc
            HStack(spacing: 6) {
                Text(formatTime(remaining))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchDesign.textPrimary)
                    .monospacedDigit()
                ZStack {
                    Circle()
                        .stroke(NotchDesign.orange.opacity(0.2), lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining / max(total, 1)))
                        .stroke(NotchDesign.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(-90))
                }
            }
        } else if state.youtube.showPrompt {
            // YouTube Detected: red play button on right
            Button(action: { playDetectedVideo() }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(NotchDesign.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .transition(.scale.combined(with: .opacity))
        } else if state.youtube.minimized {
            Button(action: { state.inlineYouTubePlayerController.togglePlayPause() }) {
                Image(systemName: state.youtube.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .transition(.scale.combined(with: .opacity))
        } else if state.system.focusMode != nil {
            // Focus/DND active indicator
            HStack(spacing: 3) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "BF5AF2"))
                Text(NSLocalizedString("system.focus", comment: ""))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchDesign.textSecondary)
            }
            .transition(.scale.combined(with: .opacity))
        } else if !shouldShowDeck {
            // Idle state: Battery indicator
            if showBatteryIndicator {
                CollapsedBatteryIndicator(level: state.battery.info.level)
                    .transition(.opacity)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(NotchDesign.green.opacity(0.6))
                        .frame(width: 4, height: 4)
                    Text(NSLocalizedString("system.active", comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchDesign.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
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
}
