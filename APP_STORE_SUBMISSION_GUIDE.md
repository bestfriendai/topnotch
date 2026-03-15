# Mac App Store Submission Guide for Top Notch

> **Last Updated:** March 2026 | **Guideline Version:** February 6, 2026

## Executive Summary

The codebase now supports two build variants:

- `Debug` / `Release`: direct distribution build with the full feature set
- `AppStoreDebug` / `AppStoreRelease`: App Store-safe build with private integrations compiled out

**Current status:** the App Store-safe variant now compiles successfully, but feature parity is intentionally reduced and App Store submission still depends on final signing, entitlements, review-safe positioning, and runtime validation.

The app uses multiple private APIs and features that violate App Store Review Guidelines (specifically **Guideline 2.5.1**):

| Feature | Status | Impact | Guideline |
|---------|--------|--------|-----------|
| SkyLight framework | ❌ **REJECTION** | Private API - immediate rejection | 2.5.1 |
| MediaRemote framework | ❌ **REJECTION** | Private API - immediate rejection | 2.5.1 |
| DisplayServices framework | ❌ **REJECTION** | Private API - immediate rejection | 2.5.1 |
| CGEvent.tapCreate | ❌ **REJECTION** | Requires accessibility + incompatible with sandbox | 2.4.5(i) |
| Lock screen visibility | ❌ **NOT POSSIBLE** | Cannot show windows on lock screen in sandbox | 2.4.5(i) |
| canBecomeVisibleWithoutLogin | ❌ **NOT POSSIBLE** | Requires special entitlement not available to third parties | 2.4.5(v) |
| YouTube Player (future) | ⚠️ **CONDITIONAL** | Must use WebKit framework, cannot download content | 2.5.6, 5.2.3 |

### Distribution Options (Ranked by Feasibility)

| Option | Functionality | Requirements | Best For |
|--------|--------------|--------------|----------|
| **1. Direct Distribution (Notarized)** | ✅ Full feature set | Developer ID + Notarization | Private integrations allowed outside App Store |
| **2. Mac App Store** | ⚠️ Reduced feature set | App Sandbox + Public APIs only | Visibility-focused notch utility |
| **3. TestFlight (macOS)** | ⚠️ Reduced feature set | Same as App Store | Beta testing sandboxed version |

### Recommended Path

Use both:

- direct distribution for the premium system-integration version
- App Store distribution for the public-API-safe version

## Build Variants

### Direct Build

- Configurations: `Debug`, `Release`
- Bundle identifier: `com.topnotch.app`
- Includes private/system integrations where implemented

Build command:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

### App Store Build

- Configurations: `AppStoreDebug`, `AppStoreRelease`
- Swift compilation flag: `APP_STORE_BUILD`
- Bundle identifier: `com.topnotch.appstore`
- Product name: `Top Notch Store`
- Sandbox enabled

Build command:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration AppStoreDebug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

### Verified Status

- `Debug`: build succeeded
- `AppStoreDebug`: build succeeded

## What Is Disabled In App Store Builds

The App Store-safe build compiles out or disables the following direct-only capabilities:

1. SkyLight-based lock screen window placement
2. MediaRemote-based advanced media control and now-playing integration
3. DisplayServices-based brightness control
4. Event-tap-driven media key interception paths that rely on system-wide interception behavior

The UI now adapts to this variant and shows compatibility notes instead of exposing unsupported controls.

## Remaining Submission Risks

Even with private APIs compiled out, submission is not guaranteed yet. Remaining work includes:

1. Final sandbox entitlement review
2. Code signing and notarization strategy per variant
3. App Review positioning for the reduced App Store feature set
4. Runtime validation that the App Store build behaves correctly without direct-only integrations
5. Final copy/screenshots that do not advertise disabled features

## YouTube Status

The notch YouTube experience has been reworked into an inline, resizable player, but reliable embedded playback is still not fully solved.

- The last verified runtime test reached player initialization
- YouTube then returned error `152`
- The app correctly falls back to a watch-page mode

This means the build split is complete, but YouTube embed reliability still needs separate follow-up work before treating that feature as finished.

---

## 1. App Store Review Guidelines Analysis

### 1.1 Private API Usage (Guideline 2.5.1)

> "Apps may only use public APIs and must run on the currently shipping OS."

**Your Current Private API Usage:**

#### SkyLight Framework (`/System/Library/PrivateFrameworks/SkyLight.framework`)
```swift
// ❌ WILL CAUSE REJECTION - These functions are private:
- SLSMainConnectionID()
- SLSSpaceCreate()
- SLSSpaceDestroy()
- SLSSpaceSetAbsoluteLevel()
- SLSShowSpaces()
- SLSHideSpaces()
- SLSSpaceAddWindowsAndRemoveFromSpaces()
```
**Purpose**: Shows window on lock screen
**App Store Alternative**: **NONE** - This functionality is impossible in a sandboxed app

#### MediaRemote Framework (`/System/Library/PrivateFrameworks/MediaRemote.framework`)
```swift
// ❌ WILL CAUSE REJECTION
- MRMediaRemoteGetNowPlayingInfo
```
**Purpose**: Detect currently playing media
**App Store Alternative**: Use `MPNowPlayingInfoCenter` (limited functionality)

#### DisplayServices Framework (`/System/Library/PrivateFrameworks/DisplayServices.framework`)
```swift
// ❌ WILL CAUSE REJECTION
- DisplayServicesGetBrightness()
- DisplayServicesSetBrightness()
```
**Purpose**: Control display brightness
**App Store Alternative**: **NONE** - Brightness control is not possible in sandbox

### 1.2 Sandboxing Requirements (Guideline 2.4.5)

All Mac App Store apps must be sandboxed. The sandbox restricts:

| Feature | Sandbox Status | Your App Uses |
|---------|----------------|---------------|
| CGEvent taps | ❌ **BLOCKED** | ✅ Yes |
| Window above all apps | ⚠️ **LIMITED** | ✅ Yes |
| Lock screen access | ❌ **BLOCKED** | ✅ Yes |
| System volume control | ❌ **BLOCKED** | ✅ Yes |
| Brightness control | ❌ **BLOCKED** | ✅ Yes |
| Distributed notifications | ⚠️ **LIMITED** | ✅ Yes |
| IOKit power monitoring | ✅ **ALLOWED** | ✅ Yes |

### 1.3 Accessibility API Usage (Guideline 2.5.4)

`AXIsProcessTrusted()` and `CGEvent.tapCreate()` require:
- **Accessibility permission** from the user
- **com.apple.security.temporary-exception.mach-lookup.global-name** entitlement (rarely approved)
- For App Store: Event taps are not allowed in sandboxed apps

---

## 2. Sandboxing Concerns - Detailed Analysis

### 2.1 Required Entitlements (If You Could Make It Work)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for ALL Mac App Store apps -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Battery monitoring - ALLOWED -->
    <key>com.apple.security.device.usb</key>
    <false/>
    
    <!-- Network for potential future features -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- User-selected file access (if needed) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- ⚠️ THESE WOULD BE REJECTED: -->
    
    <!-- Event taps - NOT AVAILABLE in sandbox -->
    <!-- <key>com.apple.security.temporary-exception.mach-lookup.global-name</key> -->
    
    <!-- Accessibility - NOT AVAILABLE via entitlement -->
    <!-- Requires user to manually grant in System Settings -->
</dict>
</plist>
```

### 2.2 Feature-by-Feature Sandbox Analysis

#### 🔴 Floating Window Above All Apps
**Current Implementation**:
```swift
level = .mainMenu + 1
collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
```
**Sandbox Status**: Partially works, but window levels are limited
**Alternative**: `NSWindow.Level.floating` works but will be below system UI

#### 🔴 Media Key Interception
**Current Implementation**: `CGEvent.tapCreate()` with event mask for system-defined events
**Sandbox Status**: **BLOCKED** - Event taps cannot be created in sandboxed apps
**Alternative**: **NONE** - Must remove this feature entirely

#### ✅ Battery Monitoring
**Current Implementation**: `IOPSCopyPowerSourcesInfo()`
**Sandbox Status**: **ALLOWED** - No special entitlement needed
**No changes required**

#### ⚠️ Distributed Notifications
**Current Implementation**:
```swift
DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.apple.Music.playerInfo"), ...
)
```
**Sandbox Status**: **PARTIALLY BLOCKED** - Some system notifications are filtered
**Alternative**: Use `MPNowPlayingInfoCenter` for music detection (limited)

### 2.3 Features That Must Be Removed for App Store

1. **Lock screen window placement** (SkyLight APIs)
2. **Media key interception** (CGEvent taps)  
3. **Brightness control** (DisplayServices)
4. **Volume HUD replacement** (CGEvent taps)
5. **Now playing detection via MediaRemote** (replace with limited public API)
6. **canBecomeVisibleWithoutLogin** (not allowed)

---

## 3. Required Changes for App Store Submission

### 3.1 Complete LockScreenWindowManager Replacement

**Remove entirely** - there is no public API alternative.

**New Implementation** (App Store compliant):
```swift
// AppStoreCompliantWindow.swift
import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: backing, defer: flag)
        
        // App Store compliant settings
        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        hasShadow = false
        
        // Sandbox-compliant collection behavior
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces
            // REMOVED: .ignoresCycle - optional
        ]
        
        // REMOVED: canBecomeVisibleWithoutLogin = true (not allowed)
        
        // Use floating level instead of above-menubar
        level = .floating  // Was: .mainMenu + 1
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

### 3.2 Replace MediaRemote with Public API

```swift
// AppStoreNowPlaying.swift
import MediaPlayer

final class NowPlayingMonitor: ObservableObject {
    @Published var isPlaying = false
    @Published var currentApp = ""
    @Published var trackName = ""
    @Published var artistName = ""
    @Published var artwork: NSImage?
    
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Use timer to poll MPNowPlayingInfoCenter
        // Note: This is LIMITED - only works for apps using MPNowPlayingInfoCenter
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkNowPlaying()
        }
    }
    
    private func checkNowPlaying() {
        // For App Store, we can only use DistributedNotificationCenter
        // which has limited reliability in sandbox
        
        // The MPNowPlayingInfoCenter is primarily for SETTING info,
        // not reading from other apps
        
        // Best effort: Listen for distributed notifications
        // This will work for Apple Music and some third-party apps
    }
    
    deinit {
        timer?.invalidate()
    }
}

// Music detection via DistributedNotificationCenter (limited in sandbox)
final class AppStoreMusicDetector {
    private var observers: [NSObjectProtocol] = []
    var onMusicStateChanged: ((Bool, String) -> Void)?
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let center = DistributedNotificationCenter.default()
        
        // These notifications MAY work in sandbox
        let musicNotifications = [
            "com.apple.Music.playerInfo",
            "com.spotify.client.PlaybackStateChanged"
        ]
        
        for noteName in musicNotifications {
            let observer = center.addObserver(
                forName: NSNotification.Name(noteName),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleMusicNotification(notification)
            }
            observers.append(observer)
        }
    }
    
    private func handleMusicNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let playerState = info["Player State"] as? String else { return }
        
        let isPlaying = playerState == "Playing"
        let app = notification.name.rawValue.contains("spotify") ? "Spotify" : "Music"
        onMusicStateChanged?(isPlaying, app)
    }
    
    deinit {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }
}
```

### 3.3 Remove Brightness Control Entirely

```swift
// BrightnessController.swift - REMOVED for App Store
// There is NO public API to control brightness in macOS
// This feature must be completely removed

// If you want to show brightness, you can DISPLAY it but not CONTROL it:
final class BrightnessDisplay {
    // For App Store: Can only SHOW current brightness, not change it
    // Must let macOS handle brightness keys natively
    
    // Note: Even reading brightness is not reliably possible
    // without private APIs in sandbox
}
```

### 3.4 Remove Media Key Handling

```swift
// MediaKeyManager.swift - MUST BE COMPLETELY REWRITTEN OR REMOVED

// App Store compliant version - VERY LIMITED
final class AppStoreMediaKeyManager {
    // ❌ CANNOT intercept media keys in sandbox
    // ❌ CANNOT replace system volume/brightness HUD
    // ❌ CANNOT use CGEvent.tapCreate()
    
    // Only option: Let macOS handle keys natively
    // Your app will NOT be able to show custom HUDs for volume/brightness
    
    // Possible alternative: React to volume changes AFTER they happen
    // using CoreAudio notifications, but cannot intercept the keys
    
    private var volumeObserver: AudioObjectPropertyListenerBlock?
    
    func observeVolumeChanges(callback: @escaping (Float) -> Void) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let deviceID = getDefaultOutputDevice()
        
        // This lets you REACT to volume changes, not intercept keys
        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &address,
            DispatchQueue.main
        ) { _, _ in
            let volume = self.getCurrentVolume()
            callback(volume)
        }
    }
    
    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }
    
    private func getCurrentVolume() -> Float {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(getDefaultOutputDevice(), &address, 0, nil, &size, &volume)
        return volume
    }
}
```

### 3.5 Accessibility Permission Request

For direct distribution (not App Store), proper accessibility request:

```swift
// AccessibilityHelper.swift
import AppKit

struct AccessibilityHelper {
    
    /// Check if accessibility is enabled
    static var isEnabled: Bool {
        AXIsProcessTrusted()
    }
    
    /// Request accessibility permission with user prompt
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    /// Open System Settings to accessibility pane
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Show accessibility required alert
    static func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            MyDynamicIsland needs accessibility permission to:
            • Show custom volume & brightness indicators
            • Intercept media keys
            
            Please enable it in System Settings > Privacy & Security > Accessibility.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
}
```

---

## 4. Required Configuration Files

### 4.1 Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Bundle Information -->
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    
    <!-- macOS Specific -->
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    
    <!-- App runs as accessory (menu bar only, optional) -->
    <key>LSUIElement</key>
    <false/>
    
    <!-- High resolution support -->
    <key>NSHighResolutionCapable</key>
    <true/>
    
    <!-- Supports macOS 13.0+ notch detection -->
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    
    <!-- Copyright -->
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
    
    <!-- Privacy Usage Descriptions (required even if not using these) -->
    
    <!-- If your app accesses microphone -->
    <!-- <key>NSMicrophoneUsageDescription</key>
    <string>MyDynamicIsland needs microphone access for audio level visualization.</string> -->
    
    <!-- For screen recording (if showing screen content) -->
    <!-- <key>NSScreenCaptureUsageDescription</key>
    <string>MyDynamicIsland needs screen recording permission to display content.</string> -->
    
    <!-- For App Store: Apple Events (optional) -->
    <key>NSAppleEventsUsageDescription</key>
    <string>MyDynamicIsland uses Apple Events to detect currently playing media.</string>
    
    <!-- Required for hardened runtime with AppleScript -->
    <key>NSAppleScriptEnabled</key>
    <false/>
    
    <!-- Export Compliance (required for App Store) -->
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
</dict>
</plist>
```

### 4.2 App Store Entitlements

**File: `MyDynamicIsland.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- REQUIRED: App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Outgoing network connections (for future features) -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Team ID for App Groups (if needed) -->
    <!-- <key>com.apple.security.application-groups</key>
    <array>
        <string>$(TeamIdentifierPrefix)com.yourcompany.mydynamicisland</string>
    </array> -->
</dict>
</plist>
```

### 4.3 Direct Distribution Entitlements (Non-App Store)

**File: `MyDynamicIsland-DirectDist.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime (required for notarization) -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>  <!-- Needed for private frameworks -->
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    
    <!-- Accessibility (not an entitlement, but runtime permission) -->
    <!-- App will request at runtime via AXIsProcessTrustedWithOptions -->
    
    <!-- Audio (for CoreAudio access) -->
    <key>com.apple.security.device.audio-input</key>
    <false/>
    
    <!-- For Apple Events (if using) -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### 4.4 Hardened Runtime Settings

For notarization (direct distribution), add to your Xcode project:

**Build Settings:**
```
ENABLE_HARDENED_RUNTIME = YES
CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES
OTHER_CODE_SIGN_FLAGS = --timestamp --options runtime
```

---

## 5. App Icon Requirements

### 5.1 Required Sizes for App Store

Create `AppIcon.appiconset` with these sizes:

| Size (px) | Scale | Filename | Use |
|-----------|-------|----------|-----|
| 16x16 | 1x | icon_16x16.png | Menu bar, small |
| 32x32 | 1x | icon_16x16@2x.png | Menu bar, small @2x |
| 32x32 | 1x | icon_32x32.png | Finder, list |
| 64x64 | 2x | icon_32x32@2x.png | Finder, list @2x |
| 128x128 | 1x | icon_128x128.png | Finder, preview |
| 256x256 | 2x | icon_128x128@2x.png | Finder, preview @2x |
| 256x256 | 1x | icon_256x256.png | Finder, cover flow |
| 512x512 | 2x | icon_256x256@2x.png | Finder, cover flow @2x |
| 512x512 | 1x | icon_512x512.png | App Store |
| 1024x1024 | 2x | icon_512x512@2x.png | App Store @2x |

### 5.2 Contents.json for AppIcon

```json
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

---

## 6. Privacy & Legal Requirements

### 6.1 Privacy Policy

**Required for App Store submission.** Must include:

```markdown
# Privacy Policy for MyDynamicIsland

Last updated: [Date]

## Information We Collect

MyDynamicIsland does NOT collect, store, or transmit any personal information.

### Local Data Only

All data processed by this app remains on your device:
- Currently playing media information (song title, artist)
- System volume and brightness levels
- Battery status
- User preferences (stored in UserDefaults)

### No Analytics

We do not use any analytics frameworks or tracking.

### No Network Access

This app does not connect to the internet and has no backend services.

## Permissions

This app may request the following permissions:

- **Accessibility**: Required for media key handling (direct distribution only)

## Data Retention

All preferences are stored locally on your Mac and can be removed by deleting the app.

## Contact

[Your contact email]
```

### 6.2 App Store Connect Metadata

**Age Rating**: 4+ (no objectionable content)

**Required App Store Screenshots:**
- At least one screenshot for each supported screen size
- 1280x800 pixels minimum for Mac
- Recommended: 2880x1800 (Retina)

---

## 7. Distribution Options Comparison

### Option A: Mac App Store (Severely Limited)

**What Works:**
- ✅ Notch overlay display
- ✅ Battery monitoring
- ✅ Basic music detection (limited to apps posting to DistributedNotificationCenter)
- ✅ Animated UI

**What Must Be Removed:**
- ❌ Volume/Brightness HUD replacement
- ❌ Media key interception
- ❌ Lock screen visibility
- ❌ Now Playing via MediaRemote
- ❌ Brightness control

**Effort**: Complete rewrite of 60-70% of app functionality

### Option B: Direct Distribution (Notarized) - RECOMMENDED

**What Works:**
- ✅ Everything currently implemented
- ✅ Full media key interception
- ✅ Lock screen visibility
- ✅ Volume/Brightness control
- ✅ All private frameworks

**Requirements:**
- Apple Developer ID ($99/year)
- Notarization via `xcrun notarytool`
- Users must allow "Developer ID" apps in System Settings

### Option C: TestFlight for macOS

Same restrictions as Mac App Store. Not recommended for this app.

---

## 8. Notarization Process (Direct Distribution)

### 8.1 Prerequisites

```bash
# 1. Ensure you have Apple Developer ID
# 2. Create app-specific password at appleid.apple.com

# 3. Store credentials in keychain
xcrun notarytool store-credentials "notarize-app" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID"
```

### 8.2 Build and Sign

```bash
# Build archive
xcodebuild archive \
    -scheme MyDynamicIsland \
    -archivePath ./build/MyDynamicIsland.xcarchive \
    -configuration Release

# Export signed app
xcodebuild -exportArchive \
    -archivePath ./build/MyDynamicIsland.xcarchive \
    -exportPath ./build/export \
    -exportOptionsPlist ExportOptions.plist
```

### 8.3 Create DMG and Notarize

```bash
# Create DMG
hdiutil create -volname "MyDynamicIsland" \
    -srcfolder "./build/export/MyDynamicIsland.app" \
    -ov -format UDZO \
    "./build/MyDynamicIsland.dmg"

# Sign DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp \
    "./build/MyDynamicIsland.dmg"

# Submit for notarization
xcrun notarytool submit "./build/MyDynamicIsland.dmg" \
    --keychain-profile "notarize-app" \
    --wait

# Staple the ticket
xcrun stapler staple "./build/MyDynamicIsland.dmg"
```

### 8.4 ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

---

## 9. Version Numbering

### Format
- **CFBundleShortVersionString**: `MAJOR.MINOR.PATCH` (e.g., 1.0.0)
- **CFBundleVersion**: Build number integer (e.g., 1, 2, 3...)

### Rules
- Always increment build number for each upload
- Version must be higher than any previous version
- Direct distribution: No version requirements from Apple

---

## 10. Summary: Recommended Path Forward

### For Full Functionality: Direct Distribution

1. ✅ Keep all current features
2. ✅ Sign with Developer ID
3. ✅ Notarize with Apple
4. ✅ Distribute via your website or services like Gumroad, Paddle, etc.
5. ⚠️ Users must allow apps from identified developers

### For App Store: Stripped-Down Version

Create a separate "MyDynamicIsland Lite" that:
1. Shows a notch overlay with animations
2. Displays battery status
3. Shows limited music info
4. **NO** volume/brightness HUD
5. **NO** media key interception
6. **NO** lock screen visibility

This would be a significantly less capable app but could be submitted to the App Store.

---

## Appendix A: Complete Sandbox-Compliant App

```swift
// MARK: - Complete App Store Compliant Implementation

import SwiftUI
import IOKit.ps

@main
struct MyDynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var island: SandboxedDynamicIsland?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        island = SandboxedDynamicIsland()
    }
}

// Sandbox-compliant version: 
// - NO media key interception
// - NO brightness control
// - NO lock screen visibility
// - Limited music detection

final class SandboxedDynamicIsland {
    private var panel: NSPanel?
    private let state = NotchState()
    private var musicDetector: AppStoreMusicDetector?
    private var batteryTimer: Timer?
    
    init() {
        setupWindow()
        setupMusicDetection()
        setupBatteryMonitoring()
    }
    
    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        
        // Sandbox compliant window settings
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces]
        
        // NO: canBecomeVisibleWithoutLogin (not allowed)
        // NO: LockScreenWindowManager (private API)
        
        panel.contentView = NSHostingView(rootView: NotchContentView(state: state))
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        
        self.panel = panel
    }
    
    private func setupMusicDetection() {
        musicDetector = AppStoreMusicDetector()
        musicDetector?.onMusicStateChanged = { [weak self] isPlaying, app in
            DispatchQueue.main.async {
                self?.state.activity = isPlaying ? .music(app: app) : .none
            }
        }
    }
    
    private func setupBatteryMonitoring() {
        // Battery monitoring works in sandbox
        updateBatteryInfo()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
        }
    }
    
    private func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else { return }
        
        state.battery.level = (info[kIOPSCurrentCapacityKey] as? Int) ?? 100
        state.battery.isCharging = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
    }
}
```

---

*Document generated for Top Notch macOS app. For questions about App Store submission, consult Apple's official documentation at developer.apple.com.*

---

## Appendix B: Latest App Store Guidelines 2025-2026

> Based on Apple's App Review Guidelines last updated **February 6, 2026**

### B.1 Critical Private API Rules (Guideline 2.5.1)

Per the official guidelines:

> "Apps may only use public APIs and must run on the currently shipping OS. Keep your apps up-to-date and make sure you phase out any deprecated features, frameworks or technologies that will no longer be supported in future versions of an OS. Apps should use APIs and frameworks for their intended purposes."

**The following WILL cause immediate rejection:**
- SkyLight.framework (private)
- MediaRemote.framework (private)
- DisplayServices.framework (private)
- Any function starting with `SLS` prefix (SpaceLight Server)
- Using `dlopen()` to load private frameworks

### B.2 Sandboxing Requirements (Guideline 2.4.5)

For Mac App Store distribution, apps MUST:

1. **Be appropriately sandboxed** - follow macOS File System Documentation
2. **Only use appropriate macOS APIs** for modifying user data
3. **Be packaged using Xcode technologies** - no third-party installers
4. **Be self-contained single app installation bundles**
5. **NOT auto-launch or spawn persistent processes** without consent
6. **NOT request root privileges** or use setuid attributes
7. **NOT present license screens at launch**
8. **Use Mac App Store for ALL updates** - other mechanisms not allowed
9. **Run on currently shipping macOS** - no deprecated/optionally installed tech

### B.3 YouTube Player Feature - Guidelines (2025-2026)

Per **Guideline 2.5.6** and **5.2.3**:

> "Apps that browse the web must use the appropriate WebKit framework and WebKit JavaScript."

> "Apps should not facilitate illegal file sharing or include the ability to save, convert, or download media from third-party sources (e.g., Apple Music, YouTube, SoundCloud, Vimeo, etc.) without explicit authorization."

**For your YouTube player feature:**

| Feature | Allowed? | Notes |
|---------|----------|-------|
| Embed YouTube via WebKit WebView | ✅ | Must use WKWebView |
| Play YouTube videos in-app | ✅ | Via official YouTube embed |
| Download YouTube videos | ❌ | Violates 5.2.3 |
| Convert YouTube to audio | ❌ | Violates 5.2.3 |
| Ad-blocking on YouTube | ⚠️ | May violate ToS |
| Use YouTube API | ✅ | With API key, rate limits |
| Show YouTube in Picture-in-Picture | ✅ | Using AVKit |

**Implementation Requirements:**
```swift
import WebKit

// App Store compliant YouTube player
class YouTubePlayerView: NSView {
    private var webView: WKWebView!
    
    func loadVideo(videoId: String) {
        // MUST use WebKit framework per 2.5.6
        let embedHTML = """
        <iframe width="100%" height="100%" 
            src="https://www.youtube.com/embed/\(videoId)?playsinline=1"
            frameborder="0" 
            allow="autoplay; encrypted-media; picture-in-picture">
        </iframe>
        """
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://youtube.com"))
    }
}
```

---

## Appendix C: Complete Entitlements Reference (2025-2026)

### C.1 For App Store Distribution

**Required Entitlements (`TopNotch.entitlements`):**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- MANDATORY for Mac App Store -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Network: Required for YouTube player -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- User-selected files (if implementing file import) -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
```

### C.2 For Notarized Direct Distribution

**Hardened Runtime Entitlements (`TopNotch-Notarized.entitlements`):**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime Options -->
    
    <!-- Allow loading private frameworks (SkyLight, etc.) -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    
    <!-- Allow CGEvent tap creation (for media keys) -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    
    <!-- NOT required - keep false for security -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    
    <!-- NOT needed unless debugging -->
    <key>com.apple.security.cs.debugger</key>
    <false/>
    
    <!-- For Apple Events (music detection) -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### C.3 Hardened Runtime Entitlements Explained

| Entitlement | Purpose | Required? |
|-------------|---------|-----------|
| `allow-jit` | JIT compilation (JavaScript engines) | No |
| `allow-unsigned-executable-memory` | Dynamic code generation | No |
| `disable-library-validation` | Load third-party/private libs | **Yes** |
| `allow-dyld-environment-variables` | DYLD injection | No |
| `disable-executable-page-protection` | Disable code signing | No |
| `debugger` | Attach to other processes | No |

---

## Appendix D: Info.plist Requirements (2025-2026)

### D.1 Required Privacy Descriptions

All apps requiring system permissions MUST include Usage Description strings:

```xml
<!-- Info.plist -->
<dict>
    <!-- REQUIRED for Accessibility (runtime request, not entitlement) -->
    <!-- No Info.plist key - requested via AXIsProcessTrustedWithOptions -->
    
    <!-- If using Apple Events for music detection -->
    <key>NSAppleEventsUsageDescription</key>
    <string>Top Notch uses Apple Events to detect currently playing music.</string>
    
    <!-- If using Screen Recording (not needed for this app) -->
    <!-- <key>NSScreenCaptureUsageDescription</key>
    <string>Explanation of why screen capture is needed.</string> -->
    
    <!-- If using Microphone -->
    <!-- <key>NSMicrophoneUsageDescription</key>
    <string>Top Notch uses microphone for audio visualization.</string> -->
    
    <!-- REQUIRED: Export Compliance -->
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    
    <!-- App Category -->
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    
    <!-- Minimum macOS version -->
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    
    <!-- Retina support -->
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
```

---

## Appendix E: App Store Assets Requirements (2025-2026)

### E.1 App Icon Specifications

Per Apple's Human Interface Guidelines (June 2025 update with Liquid Glass):

**macOS App Icons:**
- **Master size**: 1024x1024 px (layered in Icon Composer)
- **Format**: PNG, no transparency for background
- **Shape**: Square, system applies rounded corners
- **Color space**: sRGB or Display P3

**Required Icon Sizes:**
| Size | Scale | Filename |
|------|-------|----------|
| 16x16 | 1x | icon_16x16.png |
| 32x32 | 2x | icon_16x16@2x.png |
| 32x32 | 1x | icon_32x32.png |
| 64x64 | 2x | icon_32x32@2x.png |
| 128x128 | 1x | icon_128x128.png |
| 256x256 | 2x | icon_128x128@2x.png |
| 256x256 | 1x | icon_256x256.png |
| 512x512 | 2x | icon_256x256@2x.png |
| 512x512 | 1x | icon_512x512.png |
| 1024x1024 | 2x | icon_512x512@2x.png |

### E.2 Screenshot Specifications for macOS

**Required**: 1-10 screenshots per localization

| Display | Resolution | Format |
|---------|------------|--------|
| MacBook Pro 16" | 3456 x 2234 px | PNG/JPEG |
| MacBook Pro 14" | 3024 x 1964 px | PNG/JPEG |
| MacBook Air 15" | 2880 x 1864 px | PNG/JPEG |
| iMac 27" | 2880 x 1620 px | PNG/JPEG |
| **Minimum** | 1280 x 800 px | PNG/JPEG |

**Screenshot Guidelines (Guideline 2.3.3):**
- Show the app in use, not just title/splash screens
- May include text/image overlays for input mechanisms
- Must be 72 DPI or higher
- Status bar time should be 9:41 AM (Apple convention)

### E.3 App Preview Videos (Optional)

| Spec | Requirement |
|------|-------------|
| Duration | 15-30 seconds |
| Format | H.264, M4V, MP4, MOV |
| Resolution | Match screenshot resolutions |
| Frame Rate | 30 fps |
| Audio | Optional, AAC stereo |

**Rules (Guideline 2.3.4):**
- Must use video screen captures of the app itself
- May add narration and text overlays
- Cannot show competing platform names/icons

---

## Appendix F: Code Signing & Notarization (2025-2026)

### F.1 Notarization Requirements

Per Apple's documentation (updated 2026):

**Prerequisites:**
1. Xcode 14+ (notarytool required, altool deprecated)
2. Developer ID Application certificate
3. Developer ID Installer certificate (for PKG)
4. Hardened Runtime enabled
5. Secure timestamp in signature
6. No `com.apple.security.get-task-allow` entitlement

**Prepare for Notarization:**
```bash
# Verify Hardened Runtime and signature
codesign --verify --deep --strict --verbose=4 \
    "TopNotch.app"

# Check entitlements
codesign -d --entitlements :- "TopNotch.app"
```

### F.2 Complete Notarization Script

```bash
#!/bin/bash
# notarize.sh - Complete notarization workflow

APP_NAME="Top Notch"
BUNDLE_ID="com.yourcompany.topnotch"
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
KEYCHAIN_PROFILE="notarize-topnotch"

echo "🔨 Building..."
xcodebuild clean archive \
    -scheme "$APP_NAME" \
    -archivePath "./build/$APP_NAME.xcarchive" \
    -configuration Release \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    ENABLE_HARDENED_RUNTIME=YES

echo "📦 Exporting..."
xcodebuild -exportArchive \
    -archivePath "./build/$APP_NAME.xcarchive" \
    -exportPath "./build/export" \
    -exportOptionsPlist "ExportOptions.plist"

echo "💿 Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "./build/export/$APP_NAME.app" \
    -ov -format UDZO \
    "./build/$APP_NAME.dmg"

echo "✍️ Signing DMG..."
codesign --sign "$DEVELOPER_ID" \
    --timestamp \
    "./build/$APP_NAME.dmg"

echo "🚀 Submitting for notarization..."
xcrun notarytool submit "./build/$APP_NAME.dmg" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "📎 Stapling ticket..."
xcrun stapler staple "./build/$APP_NAME.dmg"

echo "✅ Verifying..."
xcrun stapler validate "./build/$APP_NAME.dmg"
spctl --assess --type open --context context:primary-signature \
    --verbose=4 "./build/$APP_NAME.dmg"

echo "🎉 Done! DMG ready for distribution."
```

---

## Appendix G: Common Rejection Reasons (2025-2026)

### G.1 Top Rejections for Utility Apps

Based on App Review Guidelines and developer forums:

| Reason | Guideline | How to Avoid |
|--------|-----------|--------------|
| **Private API usage** | 2.5.1 | Only use documented APIs |
| **Missing sandbox** | 2.4.5(i) | Enable App Sandbox capability |
| **Crashes/bugs** | 2.1 | Test thoroughly before submission |
| **Incomplete metadata** | 2.3 | Fill all App Store Connect fields |
| **Placeholder content** | 2.1 | Remove "Lorem ipsum" and TODOs |
| **Misleading description** | 2.3.1 | Accurately describe features |
| **Poor functionality** | 4.2 | Provide genuine value |
| **Spam/duplicate** | 4.3 | Don't copy existing apps |
| **Missing privacy policy** | 5.1.1(i) | Include accessible privacy policy |
| **Auto-launch without consent** | 2.4.5(iii) | Get user permission |

### G.2 Specific to Your App's Features

| Feature | Risk | Mitigation |
|---------|------|------------|
| Floating window | Low | Use `.floating` level, not above menu |
| Battery monitoring | None | IOKit power APIs are public |
| Music detection | Medium | Use DistributedNotificationCenter |
| YouTube embedding | Low | Use WKWebView, no downloads |
| Full-screen companion | Low | Use `.fullScreenAuxiliary` |
| Lock screen visibility | **REJECTION** | Remove entirely for App Store |
| Media key capture | **REJECTION** | Remove entirely for App Store |

---

## Appendix H: Alternative Distribution Platforms

If App Store submission is not viable due to private API requirements:

### H.1 Notarized Direct Distribution

**Pros:**
- Full feature set
- No App Store restrictions
- Keep 100% of revenue
- Direct customer relationship

**Cons:**
- No App Store discovery
- Users must adjust security settings
- Handle payments yourself

### H.2 Third-Party Platforms

| Platform | Commission | Features |
|----------|------------|----------|
| **Gumroad** | 10% | Simple checkout, licensing |
| **Paddle** | 5-10% | EU taxes, subscriptions |
| **FastSpring** | ~8% | Global payments |
| **Lemon Squeezy** | 5% + fees | Modern checkout |
| **Your website + Stripe** | 2.9% + $0.30 | Full control |

### H.3 SetApp

- Subscription-based app distribution
- Revenue share based on usage
- Good for utility apps
- Contact: [setapp.com/developers](https://setapp.com/developers)

### H.4 Homebrew Cask

For free/open-source distribution:
```bash
# Users can install via
brew install --cask topnotch
```

---

## Appendix I: Submission Checklist

### Pre-Submission Checklist (Direct Distribution)

- [ ] Code reviewed and tested on macOS 13, 14, 15
- [ ] Hardened Runtime enabled in Xcode
- [ ] Developer ID Application certificate valid
- [ ] App signed with timestamp
- [ ] No `get-task-allow` entitlement
- [ ] `disable-library-validation` entitlement added (for private frameworks)
- [ ] Notarization successful
- [ ] Ticket stapled to app/DMG
- [ ] spctl verification passes
- [ ] Privacy policy accessible
- [ ] Version numbering correct

### Pre-Submission Checklist (App Store - Limited Version)

- [ ] All private frameworks REMOVED
- [ ] CGEvent taps REMOVED
- [ ] Lock screen features REMOVED
- [ ] App Sandbox enabled
- [ ] Only public APIs used
- [ ] Tested in sandbox environment
- [ ] Screenshots (1280x800 min) prepared
- [ ] App icon (1024x1024) ready
- [ ] Description written (no competitor mentions)
- [ ] Privacy policy URL set
- [ ] Age rating completed
- [ ] Export compliance confirmed
- [ ] TestFlight build tested
- [ ] Build number incremented

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| March 2026 | 2.0 | Updated for App Review Guidelines Feb 2026 |
| | | Added YouTube player guidelines |
| | | Added Liquid Glass icon requirements |
| | | Updated notarization workflow |
| | | Added alternative distribution options |

---

*This document is for informational purposes. Always consult Apple's official [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) for authoritative information.*
