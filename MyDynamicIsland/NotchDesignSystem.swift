import SwiftUI

// MARK: - Animation Presets

extension Animation {
    /// Fast, snappy spring — great for button presses and quick state changes.
    static let notchSnap    = Animation.spring(duration: 0.22, bounce: 0.30)
    /// Default spring — general purpose expand/collapse.
    static let notchDefault = Animation.spring(duration: 0.40, bounce: 0.28)
    /// Bouncy spring — deck navigation, card entrances.
    static let notchBouncy  = Animation.spring(duration: 0.50, bounce: 0.45)
    /// Gentle spring — large panel transitions.
    static let notchGentle  = Animation.spring(duration: 0.55, bounce: 0.15)
}

// MARK: - Press Scale Button Style

/// Scales the label down slightly on press — Apple-style tactile feedback.
struct NotchPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.88
    var hoveredScale: CGFloat = 1.0
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : (isHovering ? hoveredScale : 1.0))
            .animation(.spring(duration: 0.18, bounce: 0.30), value: configuration.isPressed)
            .animation(.spring(duration: 0.22, bounce: 0.25), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension ButtonStyle where Self == NotchPressButtonStyle {
    static var notchPress: NotchPressButtonStyle { NotchPressButtonStyle() }
    static func notchPress(scale: CGFloat, hover: CGFloat = 1.0) -> NotchPressButtonStyle {
        NotchPressButtonStyle(pressedScale: scale, hoveredScale: hover)
    }
}

// MARK: - Glow Modifier

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.55), radius: radius / 2, y: 0)
            .shadow(color: color.opacity(0.30), radius: radius, y: 0)
    }
}

extension View {
    func notchGlow(_ color: Color, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design System

struct NotchDesign {
    // Backgrounds — pure black to blend seamlessly with the hardware notch
    static let bgMain = Color.black // #000000
    static let cardBg = Color(red: 0.086, green: 0.086, blue: 0.102) // #16161A
    static let elevated = Color(red: 0.102, green: 0.102, blue: 0.118) // #1A1A1E

    // Text
    static let textPrimary = Color(red: 0.98, green: 0.98, blue: 0.976) // #FAFAF9
    static let textSecondary = Color(red: 0.42, green: 0.42, blue: 0.44) // #6B6B70
    static let textTertiary = Color(red: 0.29, green: 0.29, blue: 0.31) // #4A4A50
    static let textMuted = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93

    // Legacy aliases
    static let goldAccent = Color(hex: "C9A962")

    // Borders
    static let borderSubtle = Color(red: 0.165, green: 0.165, blue: 0.18) // #2A2A2E
    static let borderStrong = Color(red: 0.227, green: 0.227, blue: 0.251) // #3A3A40

    // Accents
    static let green = Color(red: 0.196, green: 0.835, blue: 0.514) // #32D583
    static let spotify = Color(red: 0.114, green: 0.725, blue: 0.329) // #1DB954
    static let red = Color(red: 0.91, green: 0.353, blue: 0.31) // #E85A4F
    static let orange = Color(red: 1.0, green: 0.624, blue: 0.039) // #FF9F0A
    static let blue = Color(red: 0.039, green: 0.518, blue: 1.0) // #0A84FF
    static let amber = Color(red: 1.0, green: 0.71, blue: 0.278) // #FFB547

    // Radii
    static let cardRadius: CGFloat = 20
    static let islandRadius: CGFloat = 28
    static let panelRadius: CGFloat = 28
}

struct NotchCardShell<Content: View>: View {
    let accent: Color
    let isFocused: Bool
    let content: Content

    init(accent: Color, isFocused: Bool, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(maxHeight: isFocused ? .none : .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: NotchDesign.cardRadius, style: .continuous)
                    .fill(NotchDesign.cardBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: NotchDesign.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NotchDesign.cardRadius, style: .continuous)
                    .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }
}

// MARK: - Surface Components

struct TopNotchSurfaceCard: View {
    let accent: Color
    var isHighlighted: Bool = false
    var isFocused: Bool = false
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "0D0D12"),
                        Color(hex: "080808")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(accent.opacity(isFocused ? 0.28 : 0.20))
                    .frame(width: isFocused ? 240 : 180, height: isFocused ? 180 : 140)
                    .blur(radius: isFocused ? 60 : 44)
                    .offset(x: -28, y: -34)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.white.opacity(isHighlighted ? 0.09 : 0.05))
                    .frame(width: isFocused ? 160 : 110, height: isFocused ? 160 : 110)
                    .blur(radius: isFocused ? 50 : 32)
                    .offset(x: 22, y: 28)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(isHighlighted ? 1.0 : 0.80),
                                accent.opacity(0.28),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: isFocused ? 3 : 2)
                    .padding(.horizontal, isFocused ? 20 : 18)
                    .padding(.top, 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHighlighted ? 0.26 : 0.14),
                                accent.opacity(isHighlighted ? 0.20 : 0.10),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: accent.opacity(isHighlighted ? 0.16 : 0.08), radius: isFocused ? 28 : 14, y: isFocused ? 10 : 5)
            .shadow(color: .black.opacity(isFocused ? 0.50 : 0.35), radius: isFocused ? 30 : 16, y: isFocused ? 12 : 7)
    }
}

struct TopNotchSettingsBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "06070A"),
                    Color(hex: "0C1016"),
                    Color(hex: "07090C")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "FF4D4D").opacity(0.12))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: -280, y: -220)

            Circle()
                .fill(Color(hex: "38BDF8").opacity(0.10))
                .frame(width: 460, height: 460)
                .blur(radius: 150)
                .offset(x: 320, y: 260)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: 120, y: -260)

            Rectangle()
                .fill(Color.black.opacity(0.18))
        }
        .ignoresSafeArea()
    }
}

struct TopNotchIconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 42
    var symbolSize: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.24),
                            color.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)

            Image(systemName: icon)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.14), radius: 10, y: 4)
    }
}

struct TopNotchStatusChip: View {
    let title: String
    var icon: String? = nil
    var tint: Color = .white
    var fillOpacity: Double = 0.10

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .lineLimit(1)
        }
        .foregroundStyle(tint.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(fillOpacity))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
        )
    }
}
