# Top Notch - Complete Technical Specification

**Version:** 1.0  
**Date:** 2026-03-16  
**Platform:** macOS 14.0+ (MacBook with notch display)  
**Tech Stack:** SwiftUI + AppKit

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Features](#features)
4. [Data Flow & State Management](#data-flow--state-management)
5. [UI Components](#ui-components)
6. [APIs & Private Frameworks](#apis--private-frameworks)
7. [Build Variants](#build-variants)
8. [Keyboard Shortcuts](#keyboard-shortcuts)
9. [Settings & Persistence](#settings--persistence)
10. [Future Improvements](#future-improvements)

---

## Overview

Top Notch transforms the MacBook notch into a Dynamic Island-inspired interactive command center. It replaces the unused black notch area with a functional, beautiful UI that displays real-time information and provides quick access to controls.

### Core Philosophy

- **Embrace the notch** rather than hiding it
- **Fluid animations** using SwiftUI springs
- **Haptic feedback** for tactile confirmation
- **Dark mode native** design
- **Minimal footprint** — only shows what you need
- **Privacy-first** — no data collection, works entirely offline

---

## Architecture

### Project Structure

```
MyDynamicIsland/
├── MyDynamicIslandApp.swift          # App entry point (TopNotchApp)
├── DynamicIsland.swift                # Core controller (665 lines)
│   ├── LockScreenWindowManager       # SkyLight integration (lock screen visibility)
│   ├── NotchPanel                    # Custom NSPanel (floating window)
│   ├── NotchState                    # Observable state container
│   └── DynamicIsland                 # Main controller (setup & coordination)
├── IslandView.swift                  # SwiftUI views (1100+ lines)
├── DeckWidgets.swift                 # Widget cards (Pomodoro, Calendar)
├── DeckPagingLogic.swift            # Card swipe/paging calculations
├── MediaControlView.swift            # Media player UI (1341 lines)
├── MediaRemoteController.swift        # Media remote control
├── MediaKeyManager.swift             # Volume/brightness keys
├── MediaScrubber.swift               # Progress scrubber
├── VideoPlayerContentView.swift      # Video player content
├── VideoPlayerPanel.swift            # Floating video window
├── VideoWindowManager.swift          # Window management
├── NotchBrowserView.swift            # Browser view
├── YouTubePlayerWebView.swift        # YouTube player
├── YouTubePlayerState.swift          # YouTube state
├── YouTubeURLParser.swift            # URL parsing
├── DeckExtras.swift                 # Additional deck utilities
├── AppVariant.swift                  # Build variant configuration
└── NowPlayingInfo.swift              # Now playing data model
```

### Architecture Pattern

**MVVM with Observable State**

- **Model:** `NotchState` (ObservableObject) — Single source of truth
- **View:** SwiftUI views (`NotchView`, `DeckWidgets`, `MediaControlView`)
- **Controller:** `DynamicIsland` class coordinates all subsystems

### Window Management

The app uses a custom `NSPanel` (not a regular `NSWindow`) positioned at the top of the screen to overlay the notch area:

```swift
final class NotchPanel: NSPanel {
    // Floating, transparent, non-activating panel
    isFloatingPanel = true
    isOpaque = false
    level = .mainMenu + 1
    collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
}
```

---

## Features

### 1. Volume & Brightness HUD

Replaces default macOS overlays with notch-integrated HUD.

**Display Modes:**
- **Minimal** — Icon on left, percentage on right, no expansion
- **Progress Bar** — Classic style with animated progress bar
- **Notched** — Premium segmented design inspired by iOS

**Implementation:**
- Volume control via `CoreAudio` (`AudioObjectSetPropertyData`)
- Brightness control via `DisplayServices` (private framework)

### 2. Now Playing

Automatically detects music playback and shows animated audio visualizer with full media controls.

**Supported Apps:**
- Apple Music
- Spotify
- TIDAL
- Deezer
- Amazon Music
- Safari, Chrome, Firefox, Arc (browser media)

**UI Elements:**
- Album artwork with blur glow effect
- Track title and artist
- Progress scrubber with time display
- Play/Pause, Previous, Next controls
- App indicator badge
- Vinyl spin animation when playing

### 3. YouTube Integration

Watch YouTube videos from a notch-native inline player.

**Features:**
- **Clipboard Detection** — Automatically detects YouTube URLs in clipboard
- **Inline Player** — Opens inside the notch, resizable
- **Persistent Mini Player** — Stays open while working in other apps
- **Fallback Mode** — Falls back to browser when embedded playback is blocked
- **Search/URL Input** — Paste URL or search directly

**Technical Implementation:**
- Uses `WKWebView` for YouTube embed player
- URL parsing via `YouTubeURLParser`
- Notification-based communication between components

### 4. Battery Monitoring

**Features:**
- Animated charging indicator when plugged in
- Unplug notification with battery status
- Sound effects for plug/unplug events (customizable)
- Battery percentage display
- Time remaining estimation

**Technical Implementation:**
- Uses `IOKit.ps` for battery info (`IOPSCopyPowerSourcesInfo`)
- Real-time monitoring via `IOPSNotificationCreateRunLoopSource`

### 5. Lock Screen Integration

**Features:**
- Lock indicator when screen is locked
- Unlock animation with haptic feedback
- Works on lock screen using SkyLight framework

**Technical Implementation:**
- Uses private `SkyLight` framework to move window to lock screen space
- `DistributedNotificationCenter` for lock/unlock notifications

### 6. Calendar Widget

**Features:**
- Current date with calendar icon
- Day of week
- Week progress indicator (S M T W T F S)
- Current time
- Today's events list (up to 2)
- Quick open Calendar app button

**Technical Implementation:**
- Uses `EventKit` (`EKEventStore`) for calendar access
- Requests full calendar access

### 7. Pomodoro Timer

**Features:**
- 25-minute work sessions (configurable)
- 5-minute short breaks
- 15-minute long breaks (every 4 sessions)
- Visual progress ring with gradient
- Session dots indicator
- Start/Pause/Reset controls
- Haptic feedback on phase completion

### 8. Weather Widget

**Features:**
- Current temperature
- Weather condition icon
- High/Low temperatures
- City location
- Weather particles animation

**Technical Implementation:**
- Uses weather API (needs configuration)
- `NotchWeatherStore` for state management

### 9. Clipboard Monitoring

**Features:**
- Monitors clipboard for YouTube URLs
- Shows prompt when URL detected
- One-tap to play detected video
- Auto-dismiss after 3 seconds

---

## Data Flow & State Management

### NotchState (Central State)

```swift
final class NotchState: ObservableObject {
    // Expansion state
    @Published var isExpanded = false
    @Published var isHovered = false
    
    // HUD state
    @Published var hud: HUDType = .none  // .volume, .brightness, .none
    
    // Activity state
    @Published var activity: LiveActivity = .none  // .music, .timer, .none
    
    // Battery
    @Published var battery = BatteryInfo()
    @Published var showChargingAnimation = false
    @Published var showUnplugAnimation = false
    
    // Lock state
    @Published var isScreenLocked = false
    @Published var showUnlockAnimation = false
    
    // YouTube
    @Published var detectedYouTubeURL: String?
    @Published var showYouTubePrompt = false
    @Published var inlineYouTubeVideoID: String?
    @Published var isShowingInlineYouTubePlayer = false
    @Published var isShowingInlineBrowser = false
    
    // Deck navigation
    @Published var activeDeckCard: NotchDeckCard = .home
    
    // Notch dimensions
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 32
}
```

### Enums

```swift
enum LiveActivity: Equatable {
    case none
    case music(app: String)
    case timer(remaining: TimeInterval, total: TimeInterval)
}

enum HUDType: Equatable {
    case none
    case volume(level: CGFloat, muted: Bool)
    case brightness(level: CGFloat)
}

enum NotchDeckCard: String, CaseIterable {
    case home
    case weather
    case youtube
    case media
    case pomodoro
    case clipboard
    case calendar
}

enum HUDDisplayMode: String, CaseIterable {
    case minimal = "Minimal"
    case progressBar = "Progress Bar"
    case notched = "Notched"
}
```

### Media Remote Control

Uses `MediaRemoteController` singleton to interface with system media:

```swift
MediaRemoteController.shared.togglePlayPause()
MediaRemoteController.shared.previousTrack()
MediaRemoteController.shared.nextTrack()
MediaRemoteController.shared.seekToProgress(progress)
MediaRemoteController.shared.refresh()  // Force refresh now playing info
```

---

## UI Components

### NotchView (Main Component)

The main SwiftUI view that renders the entire notch interface.

**States:**
- Collapsed (default, ~36pt height)
- Expanded (~280pt height with deck)
- With inline YouTube player (variable height)

**Animations:**
- Scale on hover (1.08x)
- Shadow depth changes
- Blur transitions
- Content fade in/out

### Deck System

**Home View:** Scrollable card grid showing:
- YouTube card (195pt width)
- Weather card (185pt)
- Calendar card (185pt)
- Pomodoro card (185pt)
- Now Playing card (175pt)

**Focused View:** Single full-width card with:
- Gradient background
- Accent color top border
- Shadow effects
- Card-specific content

### Card Components

| Card | Accent Color | Features |
|------|---------------|----------|
| Weather | Blue (#0A84FF) | Temperature, icon, condition, high/low |
| Calendar | Red (#FF453A) | Date badge, week row, events list |
| Pomodoro | Orange (#FF9F0A) | Progress ring, timer, controls |
| YouTube | Red (#FF0000) | Search input, play button, browser |
| Media | Green (#30D158) | Artwork, track info, controls, scrubber |

### Media Controls

- **Artwork View:** Album art with blur glow, vinyl spin overlay
- **Track Info:** Title, artist, app indicator
- **Scrubber:** Progress bar with elapsed/remaining time
- **Controls:** Previous, Play/Pause, Next with hover effects

### HUD Components

- **NotchedVolumeHUD:** iOS-style segmented bars
- **ProgressBarVolumeHUD:** Classic horizontal bar
- **NotchedBrightnessHUD:** iOS-style segmented bars
- **ProgressBarBrightnessHUD:** Classic horizontal bar

---

## APIs & Private Frameworks

### Public Frameworks

| Framework | Purpose |
|-----------|---------|
| SwiftUI | User interface |
| AppKit | Window management |
| Combine | Reactive updates |
| IOKit.ps | Battery monitoring |
| CoreAudio | Volume control |
| WebKit | YouTube player |
| EventKit | Calendar access |
| ServiceManagement | Launch at login |

### Private Frameworks (Direct Build Only)

| Framework | Purpose |
|-----------|---------|
| SkyLight | Lock screen window visibility |
| MediaRemote | Now Playing detection & control |
| DisplayServices | Brightness control |

### App Build Variant Feature Matrix

| Feature | Direct Build | App Store Build |
|---------|--------------|-----------------|
| Advanced Media Controls | ✓ | ✗ |
| Private System Integrations | ✓ | ✗ |
| Global Keyboard Shortcuts | ✓ | ✗ |
| Brightness HUD Replacement | ✓ | ✗ |
| Lock Screen Indicators | ✓ | ✗ |

---

## Build Variants

### AppBuildVariant Enum

```swift
enum AppBuildVariant: String {
    case direct
    case appStore
    
    var supportsPrivateSystemIntegrations: Bool { self == .direct }
    var supportsAdvancedMediaControls: Bool { self == .direct }
    var supportsGlobalKeyboardShortcuts: Bool { self == .direct }
    var supportsInterceptedBrightnessHUD: Bool { self == .direct }
    var supportsLockScreenIndicators: Bool { self == .direct }
}
```

### Build Targets

- **Debug / Release:** Direct distribution build
- **AppStoreDebug / AppStoreRelease:** App Store-safe build (sandboxed)

### Build Commands

```bash
# Direct build
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# App Store build
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration AppStoreDebug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

---

## Keyboard Shortcuts

### Global Shortcuts (Direct Build Only)

| Shortcut | Action |
|----------|--------|
| ⌥Space | Play/Pause |
| ⌥← | Previous Track |
| ⌥→ | Next Track |
| ⌥↑ | Volume Up |
| ⌥↓ | Volume Down |
| ⌥M | Mute Toggle |
| ⌘⇧Y | Open YouTube |

### Notch Context Menu (Right-Click)

- Open YouTube Video
- Play Detected Video
- Media Controls (if available)
- Settings
- Quit

---

## Settings & Persistence

### UserDefaults Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `hudDisplayMode` | String | "progressBar" | HUD display style |
| `showLockIndicator` | Bool | true | Show lock indicator |
| `showBatteryIndicator` | Bool | true | Show battery indicator |
| `showHapticFeedback` | Bool | true | Enable haptic feedback |
| `expandOnHover` | Bool | true | Expand on mouse hover |
| `autoCollapseDelay` | Double | 4.0 | Seconds before auto-collapse |
| `notchWeatherCity` | String | "San Francisco" | Weather city |
| `activeNotchDeckCard` | String | "home" | Last active deck card |
| `youtubeClipboardDetection` | Bool | true | Detect YouTube URLs |
| `chargingSoundEnabled` | Bool | true | Play charging sounds |

### Settings Access

Right-click on the notch → Settings

---

## Future Improvements

### From Implementation Plan (2026-03-14)

1. **Test Targets for Deck Logic**
   - Unit tests for `DeckPagingLogic`
   - Edge case testing

2. **Persist Last Active Deck Card**
   - Currently implemented via `UserDefaults`

3. **Refine Deck Header/Tab Hierarchy**
   - Better breadcrumb navigation
   - Improved card indicators

4. **Improve Card Focus, Drag Feedback, and Motion**
   - Enhanced gesture handling
   - Better visual feedback on drag
   - Smoother transitions

### Potential Additions

1. **More Widgets**
   - Notes widget
   - Shortcuts widget
   - System stats widget (CPU, RAM)

2. **Enhanced Weather**
   - Hourly forecast
   - Weather alerts

3. **Calendar Enhancements**
   - Week view
   - Event creation

4. **Shortcuts Integration**
   - Run shortcuts from notch

5. **Themes**
   - Custom accent colors
   - Light mode support

---

# UI/UX Improvements Specification

This section outlines comprehensive UI/UX improvements to enhance the user experience, polish visual design, and fix known issues.

---

## 1. Animation Refinements

### 1.1 Spring Animation Consistency

**Issue:** Inconsistent spring parameters across components create jarring transitions.

**Current State:**
- Various components use different bounce/duration values
- Some animations feel too fast, others too slow

**Improvements:**

```swift
// Consistent spring configuration
private struct AnimationConstants {
    static let quickSpring = Animation.spring(duration: 0.25, bounce: 0.4)
    static let standardSpring = Animation.spring(duration: 0.35, bounce: 0.3)
    static let expandSpring = Animation.spring(duration: 0.45, bounce: 0.35)
    static let collapseSpring = Animation.spring(duration: 0.3, bounce: 0.2)
    static let cardSpring = Animation.spring(duration: 0.4, bounce: 0.25)
}

// Apply consistently
.animation(AnimationConstants.standardSpring, value: state.isExpanded)
.animation(AnimationConstants.quickSpring, value: state.isHovered)
.animation(AnimationConstants.cardSpring, value: state.activeDeckCard)
```

### 1.2 Staggered Card Entrance Animation

**Issue:** Cards appear simultaneously without staggered entrance.

**Improvement:**
```swift
// Add staggered delay for each card
private func cardEntranceDelay(for index: Int) -> Double {
    Double(index) * 0.08  // 80ms stagger
}

// Apply in view
.cardOverlayHint("YouTube")
    .deckCardEntrance(appeared: deckCardsAppeared, delay: 0.06)
    .transition(.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)),
        removal: .opacity.combined(with: .scale(scale: 0.95))
    ))
```

### 1.3 Micro-Interactions on State Changes

**Add subtle feedback for state transitions:**

| Action | Animation | Duration |
|--------|-----------|----------|
| Card tap | Scale down to 0.96, then back | 150ms |
| Button press | Scale to 0.92 with bounce | 120ms |
| Toggle on | Checkmark draws in | 200ms |
| Volume change | Smooth interpolation | 100ms |
| HUD show | Fade + slide from top | 250ms |

### 1.4 Smooth Notch Resize Animation

**Issue:** Notch resizing can feel abrupt when switching between states.

**Improvement:**
```swift
// Animate size changes with matched geometry effect
.matchedGeometryEffect(id: "notchSize", in: namespace)
.animation(AnimationConstants.expandSpring, value: notchSize)
```

---

## 2. Card Interactions & Gestures

### 2.1 Drag-to-Swipe Cards

**Issue:** Current implementation lacks drag gesture for card navigation.

**Improvement:**
```swift
// Add drag gesture to deck
.gesture(
    DragGesture()
        .onChanged { value in
            deckDragOffset = value.translation.width
        }
        .onEnded { value in
            let threshold: CGFloat = 50
            if value.translation.width < -threshold {
                navigateToNextCard()
            } else if value.translation.width > threshold {
                navigateToPreviousCard()
            }
            withAnimation(AnimationConstants.cardSpring) {
                deckDragOffset = 0
            }
        }
)
.offset(x: deckDragOffset)
```

### 2.2 Long-Press for Quick Actions

**Add context menu via long-press:**

| Card | Long-Press Action |
|------|------------------|
| YouTube | Recent videos, paste URL |
| Weather | Refresh, change location |
| Calendar | Add event, open in Calendar.app |
| Pomodoro | Skip session, customize timer |
| Media | Queue, shuffle, repeat mode |

```swift
// Implement long-press
.onLongPressGesture(minimumDuration: 0.5) {
    showQuickActionsMenu()
} onPressingChanged: { pressing in
    withAnimation(.easeInOut(duration: 0.15)) {
        cardScale = pressing ? 0.97 : 1.0
    }
}
```

### 2.3 Swipe-to-Dismiss for Focused Cards

**Issue:** No gesture to dismiss focused card view.

**Improvement:**
```swift
.gesture(
    DragGesture()
        .onEnded { value in
            if value.translation.height > 100 {
                navigateToDeckCard(.home)
            }
        }
)
```

### 2.4 Pull-to-Refresh for Weather & Calendar

**Add pull-to-refresh gesture:**
```swift
// For weather and calendar cards
.refreshable {
    await refreshWeather()
    await refreshCalendar()
}
```

---

## 3. Visual Polish

### 3.1 Consistent Color System

**Create a centralized color palette:**

```swift
struct NotchColors {
    // Primary
    static let primaryBackground = Color.black
    static let secondaryBackground = Color(white: 0.08)
    static let tertiaryBackground = Color(white: 0.12)
    
    // Accents
    static let spotifyGreen = Color(hex: "1DB954")
    static let youtubeRed = Color(hex: "FF0000")
    static let appleMusicPurple = Color(hex: "FA2D48")
    static let weatherBlue = Color(hex: "0A84FF")
    static let pomodoroOrange = Color(hex: "FF9F0A")
    static let calendarRed = Color(hex: "FF453A")
    
    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let textDisabled = Color.white.opacity(0.3)
    
    // Borders & Dividers
    static let border = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.06)
    
    // Gradients
    static let notchGlow = RadialGradient(
        colors: [Color.purple.opacity(0.12), Color.clear],
        center: .bottom,
        startRadius: 20,
        endRadius: 180
    )
}
```

### 3.2 Unified Corner Radius

**Standardize corner radius values:**

```swift
struct CornerRadius {
    static let small: CGFloat = 6      // Buttons, badges
    static let medium: CGFloat = 10     // Cards, inputs
    static let large: CGFloat = 14     // Panels
    static let xlarge: CGFloat = 18   // Notch collapsed
    static let xxlarge: CGFloat = 24   // Notch expanded
}

// Apply consistently
.clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
```

### 3.3 Improved Shadow System

**Unified shadow configurations:**

```swift
struct NotchShadows {
    static func card(_ isActive: Bool = false) -> some View {
        .shadow(
            color: .black.opacity(isActive ? 0.5 : 0.4),
            radius: isActive ? 24 : 20,
            y: isActive ? 8 : 6
        )
    }
    
    static func button(_ isHovered: Bool) -> some View {
        .shadow(
            color: .black.opacity(isHovered ? 0.3 : 0.15),
            radius: isHovered ? 12 : 8,
            y: 2
        )
    }
    
    static func glow(_ color: Color, _ isActive: Bool) -> some View {
        .shadow(
            color: color.opacity(isActive ? 0.6 : 0.3),
            radius: isActive ? 16 : 8
        )
    }
}
```

### 3.4 Glassmorphism Effects

**Add subtle blur backgrounds:**
```swift
// Use Material (available in macOS 13+)
.background(.ultraThinMaterial)

// Or custom blur with color tint
.background(
    Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(Color.black.opacity(0.2))
)
```

### 3.5 Consistent Icon Sizing

**Standardize SF Symbol sizes:**

| Context | Size | Weight |
|--------|------|--------|
| Mini indicators | 10pt | Medium |
| Badges | 12pt | Semibold |
| Card headers | 14pt | Semibold |
| Primary actions | 18pt | Bold |
| Large icons | 24pt | Medium |

---

## 4. Accessibility

### 4.1 VoiceOver Support

**Add accessibility labels:**
```swift
// Example accessibility
.accessibilityLabel("Volume slider")
.accessibilityValue("\(Int(level * 100)) percent")
.accessibilityHint("Drag to adjust volume")
.accessibilityAddTraits(.adjustable)
```

### 4.2 Reduced Motion Support

**Respect system reduced motion preference:**
```swift
@Environment(\.reduceMotion) var reduceMotion

private var animation: Animation {
    reduceMotion ? .easeInOut(duration: 0.1) : AnimationConstants.standardSpring
}
```

### 4.3 Dynamic Type Support

**Support text scaling:**
```swift
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 20
@ScaledMetric(relativeTo: .headline) var titleSize: CGFloat = 17

.font(.system(size: titleSize, weight: .semibold))
```

### 4.4 High Contrast Mode

**Ensure visibility in high contrast:**
```swift
// Check for increased contrast
@Environment(\.accessibilityContrast) var accessibilityContrast

var borderColor: Color {
    accessibilityContrast ? .white : Color.white.opacity(0.08)
}
```

### 4.5 Focus Indicators

**Add visible focus rings for keyboard navigation:**
```swift
.buttonStyle(.plain)
.focused($isFocused)
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(Color.accentColor, lineWidth: 2)
        .opacity(isFocused ? 1 : 0)
)
```

---

## 5. Motion & Transitions

### 5.1 Consistent Transition Types

**Standardize transitions:**

| Transition | Use Case | Animation |
|------------|----------|-----------|
| `.opacity` | Simple show/hide | 200ms ease |
| `.scale` | Card focus | 250ms spring |
| `.move(edge:)` | Navigation | 200ms spring |
| `.asymmetric` | Complex | Combined |

### 5.2 Hero Animations

**Implement shared element transitions:**
```swift
// When navigating from card to focused view
.matchedGeometryEffect(id: "artwork", in: namespace)
.matchedGeometryEffect(id: "title", in: namespace)
```

### 5.3 Parallax Effects

**Add subtle depth on hover:**
```swift
.gesture(
    DragGesture()
        .onChanged { value in
            let xOffset = value.translation.width / 20
            let yOffset = value.translation.height / 20
            cardOffset = CGSize(width: xOffset, height: yOffset)
        }
)
.offset(cardOffset)
```

### 5.4 Loading States

**Add skeleton/shimmer animations:**
```swift
struct ShimmerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (shimmerOffset * geo.size.width * 3))
                }
            )
            .mask(content)
    }
}
```

---

## 6. Gesture Handling

### 6.1 Unified Gesture System

**Create gesture coordinator:**
```swift
class GestureCoordinator: ObservableObject {
    @Published var currentGesture: GestureType?
    @Published var isDragging = false
    
    enum GestureType {
        case tap, longPress, drag, magnification, rotation
    }
}
```

### 6.2 Gesture Priority

**Handle conflicting gestures:**
```swift
// Priority: Drag > LongPress > Tap
.gesture(tapGesture)
.gesture(longPressGesture.exclusively(before: tapGesture))
.gesture(dragGesture.exclusively(before: longPressGesture))
```

### 6.3 Haptic Feedback Integration

**Provide tactile feedback:**
```swift
func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    guard UserDefaults.standard.bool(forKey: "showHapticFeedback") else { return }
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}
```

---

## 7. Feedback Systems

### 7.1 Toast Notifications

**Add non-blocking feedback:**
```swift
enum ToastType {
    case success, error, info, warning
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

// Show toast
showToast(.success, message: "Settings saved")
```

### 7.2 Progress Indicators

**Unified loading states:**
```swift
struct NotchProgressView: View {
    enum Style { circular, linear, dots }
    
    // Circular: Default media loading
    // Linear: Progress bar for downloads/sync
    // Dots: Sequential operations
}
```

### 7.3 Error States

**Consistent error presentation:**
```swift
struct ErrorState: View {
    let title: String
    let message: String
    let retryAction: () -> Void
    
    // Include: Icon, title, message, retry button
    // Animation: Shake on appear
}
```

### 7.4 Success Feedback

**Confirm successful actions:**
```swift
// Checkmark animation for successful actions
// Confetti for achievements (Pomodoro completion)
// Subtle pulse for toggle switches
```

---

## 8. Layout Improvements

### 8.1 Responsive Card Sizing

**Dynamic card widths based on notch size:**
```swift
private func cardWidth(for screenWidth: CGFloat) -> CGFloat {
    let baseWidth: CGFloat = 180
    let maxWidth: CGFloat = 220
    
    // Scale based on available space
    let scaleFactor = screenWidth / 1500  // Base reference
    return min(max(baseWidth * scaleFactor, baseWidth), maxWidth)
}
```

### 8.2 Safe Area Handling

**Proper notch and menu bar spacing:**
```swift
// Account for Dynamic Island/notch
.padding(.top, screen.safeAreaInsets.top + 8)
.padding(.horizontal, screen.safeAreaInsets.left + 16)

// Bottom safe area for expanded content
.padding(.bottom, max(20, screen.safeAreaInsets.bottom))
```

### 8.3 Adaptive Layout

**Different layouts for different states:**
```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass

var cardGridColumns: Int {
    horizontalSizeClass == .compact ? 2 : 5
}
```

---

## 9. Color & Typography Refinements

### 9.1 Dark Mode Optimization

**Optimized dark palette:**
```swift
// Pure black for OLED displays (MacBook Pro)
static let trueBlack = Color(red: 0, green: 0, blue: 0)

// Near-black for better contrast
static let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.07)
```

### 9.2 Semantic Color Usage

**Replace hardcoded colors:**
```swift
// Instead of:
Color.white.opacity(0.5)

// Use:
NotchColors.textTertiary
```

### 9.3 Typography Scale

**Consistent text hierarchy:**
```swift
struct Typography {
    static let caption3 = Font.system(size: 10, weight: .regular)  // 10pt
    static let caption2 = Font.system(size: 11, weight: .regular)  // 11pt
    static let caption1 = Font.system(size: 12, weight: .regular)  // 12pt
    static let body = Font.system(size: 13, weight: .regular)      // 13pt
    static let subheadline = Font.system(size: 14, weight: .medium) // 14pt
    static let headline = Font.system(size: 16, weight: .semibold) // 16pt
    static let title = Font.system(size: 20, weight: .bold)        // 20pt
    static let largeTitle = Font.system(size: 28, weight: .bold)   // 28pt
}
```

---

## 10. Performance Optimizations

### 10.1 Lazy Loading

**Defer expensive views:**
```swift
// Lazy load weather particles
LazyVStack {
    WeatherParticleLite(weatherCode: code)
        .allowsHitTesting(false)
}
```

### 10.2 Image Caching

**Cache album artwork:**
```swift
struct CachedArtwork: View {
    let url: URL
    @State private var image: NSImage?
    
    // Implement disk/memory cache
}
```

### 10.3 Animation Performance

**Reduce compositor burden:**
```swift
// Use transforms instead of frame changes
.modifier(ScaleModifier(scale: scale))
    .animation(.spring(), value: scale)

// Avoid animating blur in real-time
// Pre-render blur states
```

### 10.4 Memory Management

**Clean up timers and observers:**
```swift
// In deinit or onDisappear
timer?.invalidate()
timer = nil
cancellables.removeAll()

// Use weak references in closures
{ [weak self] in self?.update() }
```

---

## 11. Implementation Priority

### Phase 1: Quick Wins (Low Effort, High Impact)
1. Fix animation consistency
2. Add staggered card entrance
3. Standardize colors and typography
4. Add haptic feedback

### Phase 2: Core Improvements (Medium Effort)
5. Implement drag gestures for cards
6. Add long-press quick actions
7. Create unified error/toast system
8. Add accessibility labels

### Phase 3: Polish (Higher Effort)
9. Hero animations
10. Pull-to-refresh
11. Loading skeletons
12. Focus indicators

### Phase 4: Advanced (Complex)
13. Parallax effects
14. Advanced gesture coordination
15. Performance profiling
16. Dynamic Type full support

---

## 12. Testing Checklist

- [ ] Animation smoothness (60fps)
- [ ] Gesture responsiveness
- [ ] Dark mode contrast
- [ ] Accessibility audit
- [ ] Memory usage profiling
- [ ] CPU usage during animations
- [ ] Battery impact
- [ ] Reduced motion preference
- [ ] VoiceOver navigation
- [ ] Keyboard navigation
- [ ] Focus indicators visible

---

## Dependencies

### Swift Package Manager

None currently (all native frameworks)

### System Frameworks

- AppKit
- SwiftUI
- Combine
- Foundation
- CoreGraphics
- CoreAudio
- AVFoundation
- WebKit
- IOKit
- EventKit
- ServiceManagement

### Private Frameworks (Runtime Loading)

- `/System/Library/PrivateFrameworks/SkyLight.framework`
- `/System/Library/PrivateFrameworks/MediaRemote.framework`

---

## License

MIT License

---

## Author

Mark Kozhydlo

---

## Trademark Notice

Top Notch is not affiliated with Apple Inc. Dynamic Island is a trademark of Apple Inc.
