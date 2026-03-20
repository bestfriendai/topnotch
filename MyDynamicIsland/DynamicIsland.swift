import AppKit
import AudioToolbox
import Combine
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
    case battery
    case shortcuts
    case notifications
    case quickCapture
}

struct BatteryInfo: Equatable {
    var level: Int = 100
    var isCharging: Bool = false
    var timeRemaining: Int? = nil
}

final class NotchState: ObservableObject {
    private static let activeDeckCardDefaultsKey = "activeNotchDeckCard"

    // Core UI state (kept directly on NotchState)
    @Published var activity: LiveActivity = .none
    @Published var isExpanded = false
    @Published var isHovered = false
    @Published var hud: HUDType = .none
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 32
    @Published var hasPhysicalNotch: Bool = true
    @Published var focusedContentHeight: CGFloat = 200
    @Published var activeDeckCard: NotchDeckCard = .home {
        didSet {
            UserDefaults.standard.set(activeDeckCard.rawValue, forKey: Self.activeDeckCardDefaultsKey)
        }
    }

    // Domain-specific sub-state objects
    @Published var battery = BatteryState()
    @Published var youtube = YouTubeState()
    @Published var system = SystemState()

    // Reference-type YouTube player objects (cannot live in a struct)
    let inlineYouTubePlayerState = YouTubePlayerState()
    let inlineYouTubePlayerController = YouTubePlayerController()

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
    private var nowPlayingTimer: Timer?
    private var cachedMRGetNowPlayingInfo: ((DispatchQueue, @escaping ([String: Any]) -> Void) -> Void)?
    private var lastMusicNotificationTime: Date = .distantPast
    private var lastMusicActivitySetTime: Date = .distantPast
    private var lastMusicAutoExpandTime: Date = .distantPast
    private var mediaControllerCancellable: AnyCancellable?
    private var activityCancellable: AnyCancellable?

    // Coordinators
    private var batteryCoordinator: BatteryCoordinator?
    private var clipboardCoordinator: ClipboardCoordinator?

    init() {
        setupWindow()
        AppLogger.lifecycle.info("DynamicIsland initializing — variant: \(AppBuildVariant.current.releaseChannelName, privacy: .public)")
        // Always set up music detection — DistributedNotificationCenter is available in both builds.
        // The MediaRemote polling path inside is gated with #if !APP_STORE_BUILD.
        setupMusicDetection()
        if AppBuildVariant.current.supportsPrivateSystemIntegrations {
            setupMediaKeys()
        }
        if AppBuildVariant.current.supportsLockScreenIndicators {
            setupLockDetection()
        }
        batteryCoordinator = BatteryCoordinator(state: state)
        batteryCoordinator?.start()
        setupLifecycleObservers()
        clipboardCoordinator = ClipboardCoordinator(state: state)
        clipboardCoordinator?.start()
        setupKeyboardShortcuts()
        setupYouTubeNotifications()
        setupFocusMonitoring()
        BatteryDeviceStore.shared.startMonitoring()
        NotificationDigestStore.shared.startMonitoring()
        AppLogger.lifecycle.info("DynamicIsland fully initialized")
    }

    deinit {
        // Remove all block-based observers (covers NotificationCenter, DistributedNotificationCenter,
        // and NSWorkspace.shared.notificationCenter)
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        // Remove global/local event monitors to prevent leaks
        for monitor in eventMonitors {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        nowPlayingTimer?.invalidate()
        mediaKeyManager?.stop()
        activityCancellable?.cancel()
        // Coordinators clean up in their own deinit
        batteryCoordinator = nil
        clipboardCoordinator = nil
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
        let hasPhysicalNotch = screen.safeAreaInsets.top > 0 && screen.auxiliaryTopLeftArea != nil
        state.notchHeight = hasPhysicalNotch ? screen.safeAreaInsets.top : screen.frame.maxY - screen.visibleFrame.maxY
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            state.notchWidth = screen.frame.width - left.width - right.width
        } else {
            // No physical notch — use a compact floating bar width
            state.notchWidth = 220
        }
        state.hasPhysicalNotch = hasPhysicalNotch
    }

    private func handleScreenChange() {
        guard let screen = NSScreen.main else { return }
        detectNotchSize(screen: screen)
        panel?.setFrame(screen.frame, display: true)
    }

    private func setupLifecycleObservers() {
        guard AppBuildVariant.current.supportsAdvancedMediaControls else { return }

        // NSWorkspace notifications are posted on NSWorkspace.shared.notificationCenter,
        // not NotificationCenter.default.
        let workspaceNC = NSWorkspace.shared.notificationCenter

        observers.append(workspaceNC.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.nowPlayingTimer?.invalidate(); self?.nowPlayingTimer = nil })

        observers.append(workspaceNC.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.startNowPlayingMonitor() })
    }

    private func setupMusicDetection() {
        // DistributedNotificationCenter is available in both direct and App Store builds.
        // This is the primary mechanism for detecting when a music app starts/stops playing
        // and for setting state.activity so the notch expands to show the media card.
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

        // MediaRemote polling is only available in the direct (non-App Store) build.
        // The App Store build relies on the distributed notifications above and
        // MediaRemoteController's own 3-second AppleScript polling.
        #if !APP_STORE_BUILD
        startNowPlayingMonitor()
        #endif

        // Combine fallback: sync state.activity from MediaRemoteController's published
        // isPlaying state. This handles cases where Spotify doesn't send distributed
        // notifications (newer Spotify versions on macOS) but is detected via polling.
        mediaControllerCancellable = MediaRemoteController.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self else { return }
                // If a distributed notification just fired, trust it for 5 seconds
                // to avoid flickering from polling lag.
                let recentNotification = Date().timeIntervalSince(self.lastMusicNotificationTime) < 5
                if recentNotification { return }

                let info = MediaRemoteController.shared.nowPlayingInfo
                if isPlaying, !info.title.isEmpty {
                    let appName = info.appName.isEmpty ? "Music" : info.appName
                    if case .music(let current) = self.state.activity, current == appName { return }
                    self.state.activity = .music(app: appName)
                    self.lastMusicActivitySetTime = Date()
                } else if !isPlaying {
                    // Only clear if nothing set the music activity recently (from any path)
                    let recentActivity = Date().timeIntervalSince(self.lastMusicActivitySetTime) < 10
                    if !recentActivity, case .music(_) = self.state.activity {
                        self.state.activity = .none
                    }
                }
            }

        // Auto-expand notch when music activity starts (like iOS Dynamic Island)
        activityCancellable = state.$activity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activity in
                guard let self else { return }
                if case .music = activity { self.triggerMusicStarted() }
            }
    }

    private func handleMusicNotification(_ notif: Notification, app: String) {
        // "Player State" may be absent in newer Spotify versions — don't hard-require it.
        let playerState = notif.userInfo?["Player State"] as? String
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastMusicNotificationTime = Date()
            // Force MediaRemoteController to re-fetch so the card picks up the track info
            MediaRemoteController.shared.refresh()
            if playerState == "Playing" || playerState == nil {
                // nil means the notification fired without an explicit state key;
                // treat it as a play event and let MediaRemote confirm the track.
                self.state.activity = .music(app: app)
                self.lastMusicActivitySetTime = Date()
            } else if playerState == "Paused" || playerState == "Stopped" {
                if case .music(let currentApp) = self.state.activity, currentApp == app {
                    self.state.activity = .none
                }
            }
        }
    }

    private func startNowPlayingMonitor() {
        guard AppBuildVariant.current.supportsAdvancedMediaControls else { return }
        nowPlayingTimer?.invalidate()
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

        // Cache the function pointer on first use instead of reloading the framework every poll cycle.
        if cachedMRGetNowPlayingInfo == nil {
            if let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
               let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                typealias Func = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
                cachedMRGetNowPlayingInfo = unsafeBitCast(ptr, to: Func.self)
            }
        }

        guard let getInfo = cachedMRGetNowPlayingInfo else { return }

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
                self.lastMusicActivitySetTime = Date()
            } else {
                // Don't clear if music activity was set recently from ANY path (notification or polling)
                let recentActivity = Date().timeIntervalSince(self.lastMusicActivitySetTime) < 15
                if !recentActivity {
                    if case .music(let app) = self.state.activity, ["Safari", "Chrome", "Firefox", "Arc", "Media"].contains(app) {
                        self.state.activity = .none
                    }
                    // Also clear known music apps only if MediaRemote confirms they're not playing
                    // and bundleId is non-empty (i.e. MediaRemote is reporting a real app, just not playing)
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
            self?.state.system.isScreenLocked = true
            self?.state.system.showUnlockAnimation = false
        })

        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            guard let self, UserDefaults.standard.object(forKey: "showLockIndicator") as? Bool ?? true else { return }
            self.state.system.isScreenLocked = false
            self.state.system.showUnlockAnimation = true
            self.playSound("Glass", volume: 0.4, fallback: 1057)
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.state.system.showUnlockAnimation = false }
        })
    }

    private func playSound(_ name: String, volume: Float, fallback: UInt32) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = volume
            sound.play()
        } else {
            AudioServicesPlaySystemSound(fallback)
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
            guard let self, !self.state.isHovered, !self.state.youtube.isShowingPlayer else { return }
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
            state.youtube.showPrompt = false
            state.isExpanded = true
        }

        panel?.makeKeyAndOrderFront(nil)
    }

    /// Briefly expands the notch to show Now Playing info when music starts.
    /// Throttled to once per 30 seconds so repeated play/pause doesn't spam.
    private func triggerMusicStarted() {
        let elapsed = Date().timeIntervalSince(lastMusicAutoExpandTime)
        guard elapsed > 30 else { return }
        guard !state.isExpanded, !state.isHovered, !state.youtube.isShowingPlayer else { return }
        lastMusicAutoExpandTime = Date()
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { state.isExpanded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, !self.state.isHovered, !self.state.youtube.isShowingPlayer else { return }
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) { self.state.isExpanded = false }
        }
    }

    private func setupFocusMonitoring() {
        let focusObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.donotdisturb.stateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Query current DND state via defaults
            let isDND = UserDefaults(suiteName: "com.apple.ncprefs")?.bool(forKey: "dnd_prefs") ?? false
            self.state.system.focusMode = isDND ? "Focus" : nil
        }
        observers.append(focusObserver)
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
            state.youtube.videoID = videoID
            state.youtube.isShowingPlayer = true
            state.youtube.showPrompt = false
            state.isExpanded = true
        }
    }

    private func closeInlineYouTubeVideo() {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            state.youtube.isShowingPlayer = false
            state.youtube.videoID = nil
            state.activeDeckCard = .home
            if !state.isHovered {
                state.isExpanded = false
            }
        }
    }
}
