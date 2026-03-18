import SwiftUI

/// Custom progress/scrubber view for media playback
struct MediaScrubber: View {
    let progress: Double
    let elapsedTime: String
    let remainingTime: String
    let isPlaying: Bool
    let accentColor: Color
    var totalDuration: TimeInterval?
    var onSeek: ((Double) -> Void)?

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var showTooltip = false
    @State private var tooltipProgress: Double = 0
    @State private var isHoveringTrack = false

    private var displayProgress: Double {
        isDragging ? dragProgress : progress
    }

    var body: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background — borderSubtle, 3px height
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(NotchDesign.borderSubtle)
                        .frame(height: 3)

                    // Filled track — accent color
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(accentColor)
                        .frame(width: max(0, geometry.size.width * displayProgress), height: 3)

                    // Knob — 10px white circle, appears on hover, subtle shadow
                    if isHoveringTrack || isDragging {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1)
                            .offset(x: max(0, min(geometry.size.width - 10, geometry.size.width * displayProgress - 5)))
                            .transition(.opacity.combined(with: .scale(scale: 0.5)))
                            .animation(.spring(), value: isDragging)
                    }

                    // Tooltip on hover/drag — show time at position
                    if showTooltip && isDragging {
                        TimeTooltip(progress: dragProgress, totalDuration: totalDuration)
                            .offset(
                                x: min(
                                    max(20, geometry.size.width * dragProgress),
                                    geometry.size.width - 20
                                ) - 20,
                                y: -28
                            )
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.spring()) {
                        isHoveringTrack = hovering
                    }
                    if !isDragging && !hovering {
                        showTooltip = false
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            showTooltip = true
                            dragProgress = max(0, min(1, value.location.x / geometry.size.width))
                            tooltipProgress = dragProgress
                        }
                        .onEnded { value in
                            let finalProgress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek?(finalProgress)

                            withAnimation(.spring()) {
                                isDragging = false
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showTooltip = false
                            }
                        }
                )
            }
            .frame(height: 14)

            // Time labels — 11px, textMuted
            HStack {
                Text(elapsedTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(NotchDesign.textMuted)

                Spacer()

                Text(remainingTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(NotchDesign.textMuted)
            }
        }
    }
}

/// Tooltip showing time when scrubbing
private struct TimeTooltip: View {
    let progress: Double
    let totalDuration: TimeInterval?

    private var timeString: String {
        guard let duration = totalDuration else { return "\(Int(progress * 100))%" }
        let time = progress * duration
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Text(timeString)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(NotchDesign.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(NotchDesign.elevated)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
                    )
            )
    }
}

/// Compact inline scrubber for collapsed state
struct CompactMediaScrubber: View {
    let progress: Double
    let accentColor: Color
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.white.opacity(0.2))
                
                // Progress
                Capsule()
                    .fill(accentColor)
                    .frame(width: max(2, geometry.size.width * animatedProgress))
            }
        }
        .frame(height: 3)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.linear(duration: 0.1)) {
                animatedProgress = newValue
            }
        }
    }
}

/// Waveform-style progress indicator
struct WaveformProgress: View {
    let progress: Double
    let isPlaying: Bool
    let accentColor: Color
    
    @State private var waveAmplitudes: [CGFloat] = Array(repeating: 0.5, count: 20)
    @State private var animationTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { index in
                    let indexProgress = Double(index) / 20.0
                    let isPast = indexProgress < progress
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPast ? accentColor : Color.white.opacity(0.2))
                        .frame(width: 3, height: isPast && isPlaying ? 4 + waveAmplitudes[index] * 12 : 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 16)
        .onAppear {
            if isPlaying { startAnimation() }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing { startAnimation() } else { stopAnimation() }
        }
        .onDisappear { stopAnimation() }
    }
    
    private func startAnimation() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.1)) {
                    waveAmplitudes = waveAmplitudes.map { _ in CGFloat.random(in: 0.3...1.0) }
                }
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            waveAmplitudes = Array(repeating: 0.5, count: 20)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        MediaScrubber(
            progress: 0.35,
            elapsedTime: "1:45",
            remainingTime: "-3:20",
            isPlaying: true,
            accentColor: .green
        ) { progress in
            print("Seek to: \(progress)")
        }
        
        CompactMediaScrubber(progress: 0.6, accentColor: .green)
            .frame(width: 60)
        
        WaveformProgress(progress: 0.5, isPlaying: true, accentColor: .green)
            .frame(width: 100)
    }
    .padding()
    .background(Color.black)
}
