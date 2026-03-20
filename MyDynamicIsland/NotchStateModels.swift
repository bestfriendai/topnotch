import Foundation
import SwiftUI

// MARK: - Battery Sub-State

struct BatteryState: Equatable {
    var info = BatteryInfo()
    var showChargingAnimation = false
    var showUnplugAnimation = false
}

// MARK: - YouTube Sub-State

struct YouTubeState: Equatable {
    var detectedURL: String? = nil
    var showPrompt = false
    var videoID: String? = nil
    var playerWidth: CGFloat = 480
    var playerHeight: CGFloat = 270
    var minimized: Bool = false
    var startTime: Int = 0
    var isPlaying: Bool = false
    var progress: Double = 0
    var isShowingPlayer: Bool = false
}

// MARK: - System Sub-State

struct SystemState: Equatable {
    var isScreenLocked = false
    var showUnlockAnimation = false
    var focusMode: String? = nil
}
