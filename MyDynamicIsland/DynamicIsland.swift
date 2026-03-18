import AppKit
import AudioToolbox
import Combine
import IOKit.ps
import OSLog
import SwiftUI

#if APP_STORE_BUILD
final class LockScreenWindowManager {
    static let shared: LockScreenWindowManager? = nil

    func moveWindowToLockScreen(_ window: NSWindow) {}
}
#else
final class LockScreenWindowManager {
    static let shared: LockScreenWindowManager? = LockScreenWindowManager()

    private enum SpaceLevel: Int32 {
        case `default` = 0, setupAssistant = 100, securityAgent = 200
        case screenLock = 300, notificationCenterAtScreenLock = 400
        case bootProgress = 500, voiceOver = 600
    }

    private let connection: Int32
    private let space: Int32
    private let SLSMainConnectionID: @convention(c) () -> Int32
    private let SLSSpaceCreate: @convention(c) (Int32, Int32, Int32) -> Int32
    private let SLSSpaceDestroy: @convention(c) (Int32, Int32) -> Int32
    private let SLSSpaceSetAbsoluteLevel: @convention(c) (Int32, Int32, Int32) -> Int32
    private let SLSShowSpaces: @convention(c) (Int32, CFArray) -> Int32
    private let SLSHideSpaces: @convention(c) (Int32, CFArray) -> Int32
    private let SLSSpaceAddWindowsAndRemoveFromSpaces: @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private init?() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/SkyLight.framework")) else { return nil }

        guard let p1 = CFBundleGetFunctionPointerForName(bundle, "SLSMainConnectionID" as CFString),
              let p2 = CFBundleGetFunctionPointerForName(bundle, "SLSSpaceCreate" as CFString),
              let p3 = CFBundleGetFunctionPointerForName(bundle, "SLSSpaceDestroy" as CFString),
              let p4 = CFBundleGetFunctionPointerForName(bundle, "SLSSpaceSetAbsoluteLevel" as CFString),
              let p5 = CFBundleGetFunctionPointerForName(bundle, "SLSShowSpaces" as CFString),
              let p6 = CFBundleGetFunctionPointerForName(bundle, "SLSHideSpaces" as CFString),
              let p7 = CFBundleGetFunctionPointerForName(bundle, "SLSSpaceAddWindowsAndRemoveFromSpaces" as CFString)
        else { return nil }

        SLSMainConnectionID = unsafeBitCast(p1, to: (@convention(c) () -> Int32).self)
        SLSSpaceCreate = unsafeBitCast(p2, to: (@convention(c) (Int32, Int32, Int32) -> Int32).self)
        SLSSpaceDestroy = unsafeBitCast(p3, to: (@convention(c) (Int32, Int32) -> Int32).self)
        SLSSpaceSetAbsoluteLevel = unsafeBitCast(p4, to: (@convention(c) (Int32, Int32, Int32) -> Int32).self)
        SLSShowSpaces = unsafeBitCast(p5, to: (@convention(c) (Int32, CFArray) -> Int32).self)
        SLSHideSpaces = unsafeBitCast(p6, to: (@convention(c) (Int32, CFArray) -> Int32).self)
        SLSSpaceAddWindowsAndRemoveFromSpaces = unsafeBitCast(p7, to: (@convention(c) (Int32, Int32, CFArray, Int32) -> Int32).self)

        connection = SLSMainConnectionID()
        space = SLSSpaceCreate(connection, 1, 0)
        _ = SLSSpaceSetAbsoluteLevel(connection, space, SpaceLevel.notificationCenterAtScreenLock.rawValue)
        _ = SLSShowSpaces(connection, [space] as CFArray)
    }

    deinit {
        _ = SLSHideSpaces(connection, [space] as CFArray)
        _ = SLSSpaceDestroy(connection, space)
    }

    func moveWindowToLockScreen(_ window: NSWindow) {
        _ = SLSSpaceAddWindowsAndRemoveFromSpaces(connection, space, [window.windowNumber] as CFArray, 7)
    }
}
#endif

final class NotchPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        #if !APP_STORE_BUILD
        canBecomeVisibleWithoutLogin = true
        #endif
        level = .mainMenu + 1
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

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

enum HUDDisplayMode: String, CaseIterable {
    case minimal = "Minimal"
    case progressBar = "Progress Bar"
    case notched = "Notched"
}

enum NotchDeckCard: String, CaseIterable {
    case home
    case weather
    case youtube
    case media
    case pomodoro
    case clipboard
    case calendar
    case fileShelf
}

struct BatteryInfo: Equatable {
    var level: Int = 100
    var isCharging: Bool = false
    var timeRemaining: Int? = nil
}

final class NotchState: ObservableObject {
    private static let activeDeckCardDefaultsKey = "activeNotchDeckCard"

    @Published var activity: LiveActivity = .none
    @Published var isExpanded = false
    @Published var isHovered = false
    @Published var hud: HUDType = .none
    @Published var isScreenLocked = false
    @Published var showUnlockAnimation = false
    @Published var battery = BatteryInfo()
    @Published var showChargingAnimation = false
    @Published var showUnplugAnimation = false
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 32
    @Published var detectedYouTubeURL: String? = nil
    @Published var showYouTubePrompt = false
    @Published var inlineYouTubeVideoID: String? = nil
    @Published var youtubePlayerWidth: CGFloat = 480
    @Published var youtubePlayerHeight: CGFloat = 270
    @Published var focusedContentHeight: CGFloat = 200
    @Published var inlineYouTubeMinimized: Bool = false
    @Published var inlineYouTubeStartTime: Int = 0
    @Published var inlineYouTubeIsPlaying: Bool = false
    @Published var inlineYouTubeProgress: Double = 0
    let inlineYouTubePlayerState = YouTubePlayerState()
    let inlineYouTubePlayerController = YouTubePlayerController()

    @Published var isShowingInlineYouTubePlayer = false
    @Published var activeDeckCard: NotchDeckCard = .home {
        didSet {
            UserDefaults.standard.set(activeDeckCard.rawValue, forKey: Self.activeDeckCardDefaultsKey)
        }
    }

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.activeDeckCardDefaultsKey),
           let storedCard = NotchDeckCard(rawValue: rawValue) {
            activeDeckCard = storedCard
        }
    }
}

final class DynamicIsland {
    private var panel: NSPanel?
    private let state = NotchState()
    private var mediaKeyManager: MediaKeyManager?
    private var observers: [NSObjectProtocol] = []
    private var eventMonitors: [Any?] = []
    private var batteryRunLoopSource: CFRunLoopSource?
    private var lastChargingState = false
    private var nowPlayingTimer: Timer?
    private var clipboardTask: Task<Void, Never>?
    private var lastClipboardChangeCount: Int = 0
    private var lastMusicNotificationTime: Date = .distantPast

    init() {
        setupWindow()
        AppLogger.lifecycle.info("DynamicIsland initializing — variant: \(AppBuildVariant.current.releaseChannelName, privacy: .public)")
        if AppBuildVariant.current.supportsAdvancedMediaControls {
            setupMusicDetection()
        }
        if AppBuildVariant.current.supportsPrivateSystemIntegrations {
            setupMediaKeys()
        }
        if AppBuildVariant.current.supportsLockScreenIndicators {
            setupLockDetection()
        }
        setupBatteryMonitoring()
        setupLifecycleObservers()
        setupClipboardMonitoring()
        setupKeyboardShortcuts()
        setupYouTubeNotifications()
        AppLogger.lifecycle.info("DynamicIsland fully initialized")
    }

    deinit {
        // Remove all block-based observers (covers both NotificationCenter and DistributedNotificationCenter)
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        // Remove global/local event monitors to prevent leaks
        for monitor in eventMonitors {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        nowPlayingTimer?.invalidate()
        clipboardTask?.cancel()
        mediaKeyManager?.stop()
        if let source = batteryRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            // Balance the passRetained from setupBatteryMonitoring
            Unmanaged.passUnretained(self).release()
        }
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        detectNotchSize(screen: screen)
        AppLogger.lifecycle.info("Setting up notch panel on screen \(screen.localizedName, privacy: .public)")

        let panel = NotchPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: true
        )

        panel.contentView = NSHostingView(rootView: NotchContentView(state: state))
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        LockScreenWindowManager.shared?.moveWindowToLockScreen(panel)
        self.panel = panel

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.handleScreenChange() })
    }

    private func detectNotchSize(screen: NSScreen) {
        state.notchHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : screen.frame.maxY - screen.visibleFrame.maxY
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            state.notchWidth = screen.frame.width - left.width - right.width
        } else {
            state.notchWidth = 200
        }
    }

    private func handleScreenChange() {
        guard let screen = NSScreen.main else { return }
        detectNotchSize(screen: screen)
        panel?.setFrame(screen.frame, display: true)
    }

    private func setupLifecycleObservers() {
        guard AppBuildVariant.current.supportsAdvancedMediaControls else { return }

        observers.append(NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.nowPlayingTimer?.invalidate(); self?.nowPlayingTimer = nil })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.startNowPlayingMonitor() })
    }

    private func setupMusicDetection() {
        guard AppBuildVariant.current.supportsAdvancedMediaControls else { return }

        let center = DistributedNotificationCenter.default()
        let musicApps: [(String, String)] = [
            ("com.apple.Music.playerInfo", "Music"),
            ("com.apple.iTunes.playerInfo", "Music"),
            ("com.spotify.client.PlaybackStateChanged", "Spotify"),
            ("com.tidal.desktop.playbackStateChanged", "TIDAL"),
            ("com.deezer.Deezer.playbackStateChanged", "Deezer"),
            ("com.amazon.music.playbackStateChanged", "Amazon Music")
        ]

        for (notification, app) in musicApps {
            observers.append(center.addObserver(forName: NSNotification.Name(notification), object: nil, queue: .main) { [weak self] notif in
                self?.handleMusicNotification(notif, app: app)
            })
        }
        startNowPlayingMonitor()
    }

    private func handleMusicNotification(_ notif: Notification, app: String) {
        guard let info = notif.userInfo, let playerState = info["Player State"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastMusicNotificationTime = Date()
            if playerState == "Playing" {
                self.state.activity = .music(app: app)
                // Force MediaRemoteController to re-fetch so the card picks up the track info
                MediaRemoteController.shared.refresh()
            } else if case .music(let currentApp) = self.state.activity, currentApp == app {
                self.state.activity = .none
            }
        }
    }

    private func startNowPlayingMonitor() {
        guard AppBuildVariant.current.supportsAdvancedMediaControls else { return }
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkNowPlaying()
        }
    }

    private func checkNowPlaying() {
        #if !APP_STORE_BUILD
        // If a known music app notification set the activity recently, don't override it
        let timeSinceLastNotification = Date().timeIntervalSince(lastMusicNotificationTime)
        if case .music(let app) = state.activity, ["Spotify", "Music", "TIDAL", "Deezer", "Amazon Music"].contains(app) {
            // Trust the notification-based state for 15 seconds before re-checking
            if timeSinceLastNotification < 15 { return }
        }

        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { return }

        typealias Func = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        let getInfo = unsafeBitCast(ptr, to: Func.self)

        getInfo(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            let isPlaying = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0

            // Use bundle identifier for more reliable app detection
            let bundleId = info["kMRNowPlayingClientBundleIdentifier"] as? String ?? ""

            if isPlaying {
                var appName = "Media"
                if bundleId.contains("spotify") { appName = "Spotify" }
                else if bundleId.contains("com.apple.Music") || bundleId.contains("music") { appName = "Music" }
                else if bundleId.contains("tidal") { appName = "TIDAL" }
                else if bundleId.contains("deezer") { appName = "Deezer" }
                else if bundleId.contains("amazon") { appName = "Amazon Music" }
                else if bundleId.contains("safari") { appName = "Safari" }
                else if bundleId.contains("chrome") { appName = "Chrome" }
                else if bundleId.contains("firefox") { appName = "Firefox" }
                else if bundleId.contains("arc") { appName = "Arc" }
                else if let deviceId = info["kMRMediaRemoteNowPlayingInfoClientPropertiesDeviceIdentifier"] as? String {
                    // Fallback to device identifier
                    if deviceId.contains("safari") { appName = "Safari" }
                    else if deviceId.contains("chrome") { appName = "Chrome" }
                    else if deviceId.contains("firefox") { appName = "Firefox" }
                    else if deviceId.contains("arc") { appName = "Arc" }
                }
                self.state.activity = .music(app: appName)
            } else {
                // Don't clear activity if a notification set it within the last 15 seconds
                let recentNotification = Date().timeIntervalSince(self.lastMusicNotificationTime) < 15
                if !recentNotification {
                    if case .music(let app) = self.state.activity, ["Safari", "Chrome", "Firefox", "Arc", "Media"].contains(app) {
                        self.state.activity = .none
                    }
                    // Also clear known music apps if MediaRemote confirms they're not playing
                    if case .music(_) = self.state.activity, !bundleId.isEmpty {
                        self.state.activity = .none
                    }
                }
            }
        }
        #endif
    }

    private func setupMediaKeys() {
        guard AppBuildVariant.current.supportsPrivateSystemIntegrations else { return }
        mediaKeyManager = MediaKeyManager(state: state)
        mediaKeyManager?.start()
    }

    private func setupLockDetection() {
        guard AppBuildVariant.current.supportsLockScreenIndicators else { return }
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.state.isScreenLocked = true
            self?.state.showUnlockAnimation = false
        })

        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            guard let self, UserDefaults.standard.object(forKey: "showLockIndicator") as? Bool ?? true else { return }
            self.state.isScreenLocked = false
            self.state.showUnlockAnimation = true
            self.playSound("Glass", volume: 0.4, fallback: 1057)
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.state.showUnlockAnimation = false }
        })
    }

    private func setupBatteryMonitoring() {
        updateBatteryInfo()
        lastChargingState = state.battery.isCharging

        // Use passRetained so the DynamicIsland stays alive as long as the run loop
        // source exists. We balance this in deinit by removing the source.
        let context = Unmanaged.passRetained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let island = Unmanaged<DynamicIsland>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { [weak island] in island?.checkBatteryChanges() }
        }, context)?.takeRetainedValue() {
            batteryRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        } else {
            // If source creation failed, release the retained reference
            Unmanaged<DynamicIsland>.fromOpaque(context).release()
        }
    }

    private func checkBatteryChanges() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { return }

        let isCharging = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let wasCharging = lastChargingState
        lastChargingState = isCharging

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int { self.state.battery.level = capacity }
            self.state.battery.isCharging = isCharging
            if let time = info[kIOPSTimeToEmptyKey] as? Int, time > 0 { self.state.battery.timeRemaining = time }
            else if let time = info[kIOPSTimeToFullChargeKey] as? Int, time > 0 { self.state.battery.timeRemaining = time }
            else { self.state.battery.timeRemaining = nil }

            guard UserDefaults.standard.object(forKey: "showBatteryIndicator") as? Bool ?? true else { return }
            if isCharging && !wasCharging { self.triggerCharging(started: true) }
            else if !isCharging && wasCharging { self.triggerCharging(started: false) }
        }
    }

    private func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { return }

        let isCharging = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int { self.state.battery.level = capacity }
            self.state.battery.isCharging = isCharging
        }
        lastChargingState = isCharging
    }

    private func triggerCharging(started: Bool) {
        if started {
            AppLogger.battery.info("Charging started — battery \(self.state.battery.level, privacy: .public)%")
            state.showChargingAnimation = true
            state.isExpanded = true
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            playSound("Blow", volume: 0.4, fallback: 1004)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self else { return }
                self.state.showChargingAnimation = false
                if !self.state.isHovered && !self.state.isShowingInlineYouTubePlayer { self.state.isExpanded = false }
            }
        } else {
            state.showUnplugAnimation = true
            state.isExpanded = true
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            playSound("Pop", volume: 0.35, fallback: 1057)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self else { return }
                self.state.showUnplugAnimation = false
                if !self.state.isHovered && !self.state.isShowingInlineYouTubePlayer { self.state.isExpanded = false }
            }
        }
    }

    private func playSound(_ name: String, volume: Float, fallback: UInt32) {
        guard UserDefaults.standard.object(forKey: "chargingSoundEnabled") as? Bool ?? true else { return }
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = volume
            sound.play()
        } else {
            AudioServicesPlaySystemSound(fallback)
        }
    }
    
    // MARK: - YouTube Integration
    
    private func setupClipboardMonitoring() {
        lastClipboardChangeCount = NSPasteboard.general.changeCount

        // Ask for consent on first run (App Store build defaults off)
        #if APP_STORE_BUILD
        let defaultEnabled = false
        #else
        let defaultEnabled = true
        #endif

        let consentAsked = UserDefaults.standard.bool(forKey: "clipboardConsentAsked")
        if !consentAsked && defaultEnabled {
            UserDefaults.standard.set(true, forKey: "clipboardConsentAsked")
            UserDefaults.standard.set(true, forKey: "youtubeClipboardDetection")
        }

        clipboardTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.checkClipboardForYouTubeURL() }
            }
        }
        AppLogger.clipboard.info("Clipboard monitoring started (2s interval)")
    }

    private func checkClipboardForYouTubeURL() {
        guard UserDefaults.standard.object(forKey: "youtubeClipboardDetection") as? Bool ?? true else { return }
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastClipboardChangeCount else { return }
        lastClipboardChangeCount = currentCount

        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }
        
        if YouTubeURLParser.extractVideoID(from: clipboardString) != nil {
            AppLogger.clipboard.info("YouTube URL detected in clipboard")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.state.detectedYouTubeURL = clipboardString

                // Show the YouTube prompt inline in the collapsed notch (44pt height per spec)
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    self.state.showYouTubePrompt = true
                }

                // Auto-dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                    guard let self else { return }
                    if !self.state.isHovered && !self.state.isShowingInlineYouTubePlayer {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            self.state.showYouTubePrompt = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        if AppBuildVariant.current.supportsGlobalKeyboardShortcuts {
            let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleGlobalKey(event)
            }
            eventMonitors.append(globalMonitor)
        }

        // Local monitor -- handles events when Top Notch itself is focused
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKey(event)
            // Swallow Option+arrow/space so they don't propagate
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == .option, [49, 123, 124, 125, 126].contains(Int(event.keyCode)) { return nil }
            if mods == [.command, .shift], event.charactersIgnoringModifiers?.lowercased() == "y" { return nil }
            return event
        }
        eventMonitors.append(localMonitor)
    }

    /// Handles all global keyboard shortcuts. Safe to call from any thread.
    private func handleGlobalKey(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘⇧Y — open YouTube video dialog
        if mods == [.command, .shift], event.charactersIgnoringModifiers?.lowercased() == "y" {
            DispatchQueue.main.async { [weak self] in self?.showYouTubeInputDialog() }
            return
        }

        guard AppBuildVariant.current.supportsPrivateSystemIntegrations else { return }

        // ⌥ (Option) + key — media & volume controls, no-focus-steal
        guard mods == .option else { return }

        switch Int(event.keyCode) {
        case 49: // ⌥Space — play / pause
            DispatchQueue.main.async { [weak self] in
                MediaRemoteController.shared.togglePlayPause()
                self?.flashNotch()
            }
        case 123: // ⌥← — previous track
            DispatchQueue.main.async { [weak self] in
                MediaRemoteController.shared.previousTrack()
                self?.flashNotch()
            }
        case 124: // ⌥→ — next track
            DispatchQueue.main.async { [weak self] in
                MediaRemoteController.shared.nextTrack()
                self?.flashNotch()
            }
        case 126: // ⌥↑ — volume up
            DispatchQueue.main.async { [weak self] in self?.mediaKeyManager?.volumeUp() }
        case 125: // ⌥↓ — volume down
            DispatchQueue.main.async { [weak self] in self?.mediaKeyManager?.volumeDown() }
        case 46: // ⌥M — mute toggle
            DispatchQueue.main.async { [weak self] in self?.mediaKeyManager?.mute() }
        case 16: // ⌥Y — also open YouTube dialog
            DispatchQueue.main.async { [weak self] in self?.showYouTubeInputDialog() }
        default:
            break
        }
    }

    /// Briefly expands the notch as visual feedback for a keyboard shortcut.
    private func flashNotch() {
        guard !state.isExpanded else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { state.isExpanded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, !self.state.isHovered, !self.state.isShowingInlineYouTubePlayer else { return }
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) { self.state.isExpanded = false }
        }
    }
    
    private func showYouTubeInputDialog() {
        showYouTubeDeck()
    }

    private func showYouTubeDeck() {
        NSApp.activate(ignoringOtherApps: true)

        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            state.activeDeckCard = .youtube
            state.showYouTubePrompt = false
            state.isExpanded = true
        }

        panel?.makeKeyAndOrderFront(nil)
    }

    private func setupYouTubeNotifications() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .openInlineYouTubeVideo,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let videoID = notification.object as? String else { return }
            self?.openInlineYouTubeVideo(videoID)
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: .closeInlineYouTubeVideo,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeInlineYouTubeVideo()
        })
    }

    private func openInlineYouTubeVideo(_ videoID: String) {
        guard YouTubeURLParser.isValidVideoID(videoID) else {
            AppLogger.youtube.warning("openInlineYouTubeVideo: invalid video ID '\(videoID, privacy: .public)'")
            return
        }
        AppLogger.youtube.info("Opening inline YouTube player for \(videoID, privacy: .public)")

        withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
            state.activeDeckCard = .youtube
            state.inlineYouTubeVideoID = videoID
            state.isShowingInlineYouTubePlayer = true
            state.showYouTubePrompt = false
            state.isExpanded = true
        }
    }

    private func closeInlineYouTubeVideo() {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            state.isShowingInlineYouTubePlayer = false
            state.inlineYouTubeVideoID = nil
            state.activeDeckCard = .home
            if !state.isHovered {
                state.isExpanded = false
            }
        }
    }
}
