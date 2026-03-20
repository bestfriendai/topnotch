import SwiftUI

// MARK: - NotchHUDOverlay
// Volume and brightness HUD display, delegating to the appropriate HUD style.

struct NotchHUDOverlay: View {
    let hud: HUDType

    @AppStorage("hudDisplayMode") private var hudDisplayMode = "progressBar"

    var body: some View {
        switch hud {
        case .volume(let level, let muted):
            volumeHUD(level: level, muted: muted)
                .padding(.horizontal, 16).padding(.vertical, 8)
        case .brightness(let level):
            brightnessHUD(level: level)
                .padding(.horizontal, 16).padding(.vertical, 8)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func volumeHUD(level: CGFloat, muted: Bool) -> some View {
        if hudDisplayMode == "notched" { NotchedVolumeHUD(level: level, muted: muted) }
        else { ProgressBarVolumeHUD(level: level, muted: muted) }
    }

    @ViewBuilder
    private func brightnessHUD(level: CGFloat) -> some View {
        if hudDisplayMode == "notched" { NotchedBrightnessHUD(level: level) }
        else { ProgressBarBrightnessHUD(level: level) }
    }
}
