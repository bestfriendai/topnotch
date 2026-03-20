import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var currentStep = 0
    @State private var isVisible = true
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 1
    
    private let steps: [(icon: String, color: Color, title: String, description: String)] = [
        (
            "hand.point.up.left.fill",
            Color(hex: "30D158"),
            "Hover to Peek",
            "Move your cursor over the notch to reveal music controls, weather, and quick info without interrupting your flow."
        ),
        (
            "cursorarrow.click.2",
            Color(hex: "0A84FF"),
            "Click to Open",
            "Click the notch to open the full dashboard. Browse weather, media, calendar, clipboard, and more."
        ),
        (
            "hand.draw",
            Color(hex: "BF5AF2"),
            "Swipe to Navigate",
            "Swipe left or right across the notch to move between widgets — music, weather, shortcuts, and more."
        ),
        (
            "sparkles",
            Color(hex: "FF9F0A"),
            "You're All Set",
            "Right-click the notch anytime to access Settings. Customize which widgets appear and how the notch behaves."
        )
    ]
    
    var body: some View {
        if isVisible && !onboardingCompleted {
            ZStack {
                // Backdrop
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                
                // Card
                VStack(spacing: 0) {
                    // Step indicator dots
                    HStack(spacing: 6) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep ? steps[currentStep].color : Color.white.opacity(0.2))
                                .frame(width: i == currentStep ? 20 : 6, height: 6)
                                .animation(.spring(duration: 0.3, bounce: 0.3), value: currentStep)
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(steps[currentStep].color.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(steps[currentStep].color)
                    }
                    .padding(.bottom, 20)
                    
                    // Title
                    Text(steps[currentStep].title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(NotchDesign.textPrimary)
                        .padding(.bottom, 8)
                    
                    // Description
                    Text(steps[currentStep].description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(NotchDesign.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    
                    // Buttons
                    HStack(spacing: 12) {
                        if currentStep < steps.count - 1 {
                            Button("Skip") {
                                dismiss()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(NotchDesign.textMuted)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(NotchDesign.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            
                            Button("Next") {
                                advance()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(steps[currentStep].color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            Button("Get Started") {
                                dismiss()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(steps[currentStep].color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.bottom, 28)
                }
                .frame(width: 340)
                .background(Color(hex: "16161A"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
                .offset(y: cardOffset)
                .opacity(cardOpacity)
            }
            .onAppear {
                cardOffset = 20
                cardOpacity = 0
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    cardOffset = 0
                    cardOpacity = 1
                }
            }
        }
    }
    
    private func advance() {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            cardOffset = -10
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentStep += 1
            cardOffset = 15
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
                cardOffset = 0
                cardOpacity = 1
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            cardOffset = 30
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onboardingCompleted = true
            isVisible = false
        }
    }
}
