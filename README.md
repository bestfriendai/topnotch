![Preview](preview.png)

# Top Notch

**Transform your MacBook's notch into a stunning, interactive command center.**

A Dynamic Island-inspired notch enhancement for MacBooks with notch displays. Takes the black notch area and turns it into a beautiful, functional space with fluid animations and real-time indicators.

This repository now supports two product variants:

- Direct build: full feature set for direct distribution
- App Store build: sandboxed, public-API-safe variant with reduced system integrations

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

### 🔊 Volume & Brightness HUD
Replace the default macOS volume and brightness overlays with a sleek notch-integrated HUD.

**Three display modes:**
- **Minimal** — Icon on left, percentage on right, no expansion
- **Progress Bar** — Classic style with animated progress bar
- **Notched** — Premium segmented design inspired by iOS

### 🎵 Now Playing
Automatically detects music playback and shows animated audio visualizer with full media controls.

**Supported apps:**
- Apple Music
- Spotify
- TIDAL
- Deezer
- Amazon Music
- Safari, Chrome, Firefox, Arc (browser media)

### ▶️ YouTube Integration
Watch YouTube videos from a notch-native inline player.

- **Clipboard Detection** — Automatically detects YouTube URLs
- **Inline Player** — Opens inside the notch and is resizable
- **Persistent Mini Player** — Designed to stay open while you work in other apps
- **Fallback Mode** — Falls back when embedded playback is blocked by YouTube

Note: embedded playback is still subject to YouTube restrictions. Some videos currently fall back instead of playing inline.

### 🔋 Battery Monitoring
- Animated charging indicator when plugged in
- Unplug notification with battery status
- Sound effects for plug/unplug events

### 🔒 Lock Screen Integration
- Lock indicator when screen is locked
- Unlock animation with haptic feedback
- Works on the lock screen using SkyLight framework

### 📅 Calendar Widget
Expanded view shows:
- Current date with calendar icon
- Day of week
- Week progress indicator
- Current time

## 🚀 Installation

1. Clone the repository
2. Open `MyDynamicIsland.xcodeproj` in Xcode
3. Build and run (⌘R)
4. Grant Accessibility permissions when prompted

### Build Variants

- `Debug` / `Release`: direct distribution build
- `AppStoreDebug` / `AppStoreRelease`: App Store-safe build

Unsigned local build examples:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration AppStoreDebug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## 📋 Requirements

- macOS 14.0 or later
- MacBook with notch display (M1 Pro/Max/Ultra, M2, M3 series)
- Accessibility permissions for media key interception

App Store builds intentionally disable some system-integration features to stay within public API boundaries.

## ⚙️ Settings

Right-click on the notch to access Settings.

### General
- Launch at Login
- Hide from Dock
- Expand on Hover
- Haptic Feedback
- Auto Collapse Delay
- Lock/Unlock Indicators

### Appearance
- HUD Display Mode (Minimal / Progress Bar / Notched)

### Volume & Brightness
- Enable/Disable HUD replacement
- Show/Hide percentage

### Battery
- Charging indicator toggle
- Sound effects toggle

### Music
- Now Playing indicator
- Audio visualizer animation

### YouTube
- Autoplay videos
- Default player size
- Remember window position
- Playback quality
- Default playback speed

## 🏗️ Architecture

```
MyDynamicIsland/
├── MyDynamicIslandApp.swift    # App entry point (TopNotchApp)
├── DynamicIsland.swift         # Core controller
│   ├── LockScreenWindowManager # SkyLight integration
│   ├── NotchPanel              # Custom NSPanel
│   ├── NotchState              # Observable state
│   └── DynamicIsland           # Main controller
├── MediaKeyManager.swift       # Volume/brightness keys
├── YouTubePlayerWebView.swift  # YouTube video player
├── VideoPlayerPanel.swift      # Floating video window
└── IslandView.swift            # SwiftUI views & settings
```

## 🔧 Frameworks Used

- **SwiftUI** — User interface
- **AppKit** — Window management
- **Combine** — Reactive updates
- **IOKit** — Battery monitoring
- **CoreAudio** — Volume control
- **WebKit** — YouTube player
- **SkyLight** (Private) — Lock screen visibility
- **MediaRemote** (Private) — Now Playing detection
- **DisplayServices** (Private) — Brightness control

Private frameworks are used only in the direct build path. The App Store build compiles those integrations out.

## 🔐 Privacy

Top Notch requires the following permissions:
- **Accessibility** — To intercept media keys (volume/brightness)

The app does not collect any data and works entirely offline.

## 🎨 Design Philosophy

Top Notch embraces the MacBook's notch rather than hiding it. Every interaction is designed to feel native, with:

- **Fluid animations** using SwiftUI springs
- **Haptic feedback** for tactile confirmation  
- **Dark mode native** design
- **Minimal footprint** — only shows what you need

## 👤 Author

Mark Kozhydlo

## 📝 License

MIT License — see [LICENSE](LICENSE) for details.

---

**Top Notch** — *Your notch, elevated.*

*Top Notch is not affiliated with Apple Inc. Dynamic Island is a trademark of Apple Inc.*
