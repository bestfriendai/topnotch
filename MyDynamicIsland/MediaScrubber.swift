import SwiftUI

/// Custom progress/scrubber view for media playback
struct MediaScrubber: View {
    let progress: Double
    let elapsedTime: String
    let remainingTime: String
    let isPlaying: Bool
    let accentColor: Color
    var onSeek: ((Double) -> Void)?
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var showTooltip = false
    @State private var tooltipProgress: Double = 0
    
    private var displayProgress: Double {
        isDragging ? dragProgress : progress
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    
                    // Buffering indicator (subtle animation)
                    if isPlaying {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.3),
                                        accentColor.opacity(0.1),
                                        accentColor.opacity(0.3)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 4)
                            .mask(
                                Rectangle()
                                    .frame(width: geometry.size.width * min(1.0, displayProgress + 0.05))
                            )
                    }
                    
                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * displayProgress), height: 4)
                    
                    // Scrubber knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 14 : 10, height: isDragging ? 14 : 10)
                        .shadow(color: .black.opacity(0.3), radius: isDragging ? 4 : 2, y: 1)
                        .offset(x: max(0, geometry.size.width * displayProgress - (isDragging ? 7 : 5)))
                        .animation(.spring(duration: 0.2), value: isDragging)
                    
                    // Tooltip when dragging
                    if showTooltip && isDragging {
                        TimeTooltip(progress: dragProgress, totalDuration: nil)
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
                            
                            withAnimation(.spring(duration: 0.2)) {
                                isDragging = false
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showTooltip = false
                            }
                        }
                )
                .onHover { isHovering in
                    if !isDragging && !isHovering {
                        showTooltip = false
                    }
                }
            }
            .frame(height: 14)
            
            // Time labels
            HStack {
                Text(elapsedTime)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                Text(remainingTime)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
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
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
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
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                waveAmplitudes = waveAmplitudes.map { _ in CGFloat.random(in: 0.3...1.0) }
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
