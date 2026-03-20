import EventKit
import SwiftUI

// MARK: - Design Colors (settings)

private let bgMainS = Color(red: 0.043, green: 0.043, blue: 0.055)
private let cardBgS = Color(red: 0.086, green: 0.086, blue: 0.102)
private let elevatedS = Color(red: 0.102, green: 0.102, blue: 0.118)
private let textPrimaryS = Color(red: 0.98, green: 0.98, blue: 0.976)
private let textSecondaryS = Color(red: 0.42, green: 0.42, blue: 0.44)
private let textTertiaryS = Color(red: 0.29, green: 0.29, blue: 0.31)
private let textMutedS = Color(red: 0.557, green: 0.557, blue: 0.576)
private let borderSubtleS = Color(red: 0.165, green: 0.165, blue: 0.18)
private let greenS = Color(red: 0.196, green: 0.835, blue: 0.514)
private let redS = Color(red: 0.91, green: 0.353, blue: 0.31)
private let orangeS = Color(red: 1.0, green: 0.624, blue: 0.039)
private let blueS = Color(red: 0.039, green: 0.518, blue: 1.0)

// MARK: - Settings Main View

struct TopNotchSettingsView: View {
    // General
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("expandOnHover") private var hoverToExpand = true
    @AppStorage("autoCollapseDelay") private var autoCollapseDelay = 4
    @AppStorage("showInMenuBar") private var showInMenuBar = true

    // Appearance
    @AppStorage("themeMode") private var themeMode = "Auto"
    @AppStorage("accentColorIndex") private var accentColorIndex = 0

    // Media
    @AppStorage("nowPlayingControls") private var nowPlayingControls = true
    @AppStorage("showAlbumArt") private var showAlbumArt = true
    @AppStorage("vinylAnimation") private var vinylAnimation = false
    @AppStorage("colorMatchApp") private var colorMatchApp = true

    // HUD
    @AppStorage("showVolumeHUD") private var replaceVolumeHUD = true
    @AppStorage("showBrightnessHUD") private var replaceBrightnessHUD = true
    @AppStorage("hudDisplayMode") private var hudDisplayMode = "progressBar"

    // Widgets
    @AppStorage("calendarEnabled") private var calendarEnabled = true
    @AppStorage("weatherEnabled") private var weatherEnabled = true
    @AppStorage("pomodoroEnabled") private var pomodoroEnabled = true
    @AppStorage("clipboardEnabled") private var clipboardEnabled = true
    @AppStorage("youtubeEnabled") private var youtubeEnabled = true
    @AppStorage("batteryWidgetEnabled") private var batteryWidgetEnabled = true
    @AppStorage("shortcutsWidgetEnabled") private var shortcutsWidgetEnabled = true
    @AppStorage("notificationsWidgetEnabled") private var notificationsWidgetEnabled = true
    @AppStorage("quickCaptureEnabled") private var quickCaptureEnabled = true
    @AppStorage("lyricsEnabled") private var lyricsEnabled = true

    // Intelligence / AI
    @State private var claudeAPIKey = KeychainHelper.load()
    @AppStorage("aiSummarizationEnabled") private var aiSummarizationEnabled = true

    // Privacy
    @AppStorage("youtubeClipboardDetection") private var clipboardMonitoring = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false

    // Feedback & indicators
    @AppStorage("showHapticFeedback") private var showHapticFeedback = true
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("showLockIndicator") private var showLockIndicator = true
    @AppStorage("chargingSoundEnabled") private var chargingSoundEnabled = true

    // Note: @Environment(\.dismiss) doesn't work when hosted in a standalone
    // NSWindow via NSHostingController. Close the window directly instead.

    private let accentColors: [(String, Color)] = [
        ("Blue", Color(red: 0.039, green: 0.518, blue: 1.0)),
        ("Orange", Color(red: 1.0, green: 0.624, blue: 0.039)),
        ("Green", Color(red: 0.196, green: 0.835, blue: 0.514)),
        ("Red", Color(red: 0.91, green: 0.353, blue: 0.31)),
        ("Purple", Color(red: 0.749, green: 0.353, blue: 0.949)),
        ("Cyan", Color(red: 0.024, green: 0.714, blue: 0.831)),
    ]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "42"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(textSecondaryS)
                        Text(NSLocalizedString("menu.settings", comment: "").replacingOccurrences(of: "...", with: ""))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(textPrimaryS)
                    }
                    Text("Top Notch v\(appVersion)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(textTertiaryS)
                }
                Spacer()
                Button(action: { NSApp.keyWindow?.close() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(textSecondaryS)
                        .frame(width: 28, height: 28)
                        .background(elevatedS, in: Circle())
                        .overlay(Circle().strokeBorder(borderSubtleS, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .frame(height: 72)

            Rectangle()
                .fill(borderSubtleS)
                .frame(height: 0.5)
                .padding(.horizontal, 24)

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // SECTION 1: GENERAL
                    SettingsSectionNew(title: NSLocalizedString("settings.section.general", comment: "")) {
                        TNSettingsToggleRow(title: NSLocalizedString("settings.general.launchAtLogin", comment: ""), isOn: $launchAtLogin,
                                           icon: "power", iconColor: greenS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.general.hoverToExpand", comment: ""), isOn: $hoverToExpand,
                                           icon: "hand.point.up.left.fill", iconColor: blueS)
                        settingsDividerNew
                        SettingsStepperRow(title: NSLocalizedString("settings.general.autoCollapseDelay", comment: ""), value: $autoCollapseDelay,
                                           range: 1...15, unit: "s", icon: "timer", iconColor: orangeS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.general.showInMenuBar", comment: ""), isOn: $showInMenuBar,
                                           icon: "menubar.rectangle", iconColor: Color(red: 0.557, green: 0.557, blue: 0.576))
                    }

                    // SECTION 2: APPEARANCE
                    SettingsSectionNew(title: NSLocalizedString("settings.section.appearance", comment: "")) {
                        SettingsSegmentRow(title: NSLocalizedString("settings.appearance.theme", comment: ""), options: [NSLocalizedString("settings.appearance.theme.auto", comment: ""), NSLocalizedString("settings.appearance.theme.light", comment: ""), NSLocalizedString("settings.appearance.theme.dark", comment: "")], selection: $themeMode)
                        settingsDividerNew
                        SettingsColorPickerRow(title: NSLocalizedString("settings.appearance.accentColor", comment: ""), colors: accentColors, selection: $accentColorIndex)
                        settingsDividerNew
                        SettingsLanguageRow()
                    }

                    // SECTION 3: MEDIA
                    SettingsSectionNew(title: NSLocalizedString("settings.section.media", comment: "")) {
                        TNSettingsToggleRow(title: NSLocalizedString("settings.media.nowPlaying", comment: ""), isOn: $nowPlayingControls,
                                           icon: "music.note", iconColor: greenS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.media.albumArtwork", comment: ""), isOn: $showAlbumArt,
                                           icon: "photo.fill", iconColor: blueS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.media.vinylSpin", comment: ""), isOn: $vinylAnimation,
                                           icon: "circle.grid.3x3.fill", iconColor: Color(red: 0.557, green: 0.557, blue: 0.576))
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.media.colorMatch", comment: ""), isOn: $colorMatchApp,
                                           icon: "paintpalette.fill", iconColor: Color(red: 0.749, green: 0.353, blue: 0.949))
                    }

                    // SECTION 4: HUD REPLACEMENT
                    SettingsSectionNew(title: NSLocalizedString("settings.section.hud", comment: "")) {
                        TNSettingsToggleRow(title: NSLocalizedString("settings.hud.replaceVolume", comment: ""), isOn: $replaceVolumeHUD,
                                           icon: "speaker.wave.2.fill", iconColor: blueS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.hud.replaceBrightness", comment: ""), isOn: $replaceBrightnessHUD,
                                           icon: "sun.max.fill", iconColor: orangeS)
                        settingsDividerNew
                        SettingsHUDModeRow(title: NSLocalizedString("settings.hud.style", comment: ""), selection: $hudDisplayMode)
                    }

                    // SECTION 4B: INDICATORS & FEEDBACK
                    SettingsSectionNew(title: NSLocalizedString("settings.section.indicators", comment: "")) {
                        TNSettingsToggleRow(title: NSLocalizedString("settings.indicators.battery", comment: ""), isOn: $showBatteryIndicator,
                                           icon: "battery.75percent", iconColor: greenS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.indicators.lockUnlock", comment: ""), isOn: $showLockIndicator,
                                           icon: "lock.fill", iconColor: Color(red: 0.557, green: 0.557, blue: 0.576))
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.indicators.chargingSound", comment: ""), isOn: $chargingSoundEnabled,
                                           icon: "bolt.fill", iconColor: orangeS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.indicators.haptic", comment: ""), isOn: $showHapticFeedback,
                                           icon: "iphone.radiowaves.left.and.right", iconColor: blueS)
                    }

                    // SECTION 5: WIDGETS
                    SettingsSectionNew(title: NSLocalizedString("settings.section.widgets", comment: "")) {
                        TNSettingsToggleRow(title: NSLocalizedString("widget.calendar", comment: ""), isOn: $calendarEnabled,
                                           icon: "calendar", iconColor: redS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.weather", comment: ""), isOn: $weatherEnabled,
                                           icon: "cloud.sun.fill", iconColor: blueS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.pomodoro", comment: ""), isOn: $pomodoroEnabled,
                                           icon: "timer", iconColor: orangeS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.clipboard", comment: ""), isOn: $clipboardEnabled,
                                           icon: "clipboard.fill", iconColor: Color(red: 0.557, green: 0.557, blue: 0.576))
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.youtube", comment: ""), isOn: $youtubeEnabled,
                                           icon: "play.rectangle.fill", iconColor: redS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.battery", comment: ""), isOn: $batteryWidgetEnabled,
                                           icon: "battery.100percent", iconColor: Color(hex: "34D399"))
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.shortcuts", comment: ""), isOn: $shortcutsWidgetEnabled,
                                           icon: "wand.and.stars", iconColor: Color(hex: "BF5AF2"))
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.activityFeed", comment: ""), isOn: $notificationsWidgetEnabled,
                                           icon: "bell.badge", iconColor: Color(hex: "F472B6"))
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.quickCapture", comment: ""), isOn: $quickCaptureEnabled,
                                           icon: "pencil.and.list.clipboard", iconColor: Color(hex: "2DD4BF"))
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("widget.lyrics", comment: ""), isOn: $lyricsEnabled,
                                           icon: "music.note.list", iconColor: Color(hex: "1DB954"))
                    }

                    // SECTION 5B: INTELLIGENCE
                    SettingsSectionNew(title: NSLocalizedString("settings.section.intelligence", comment: "")) {
                        // On-Device AI status
                        HStack(spacing: 10) {
                            Image(systemName: "cpu")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "BF5AF2"))
                                .frame(width: 18)
                            Text(NSLocalizedString("settings.ai.onDevice", comment: ""))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(textPrimaryS)
                            Spacer()
                            if #available(macOS 26.0, *) {
                                Label(NSLocalizedString("settings.ai.available", comment: ""), systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(greenS)
                            } else {
                                Label(NSLocalizedString("settings.ai.requiresMacOS26", comment: ""), systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(orangeS)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.ai.summarization", comment: ""), isOn: $aiSummarizationEnabled,
                                           icon: "sparkles", iconColor: Color(hex: "BF5AF2"))
                        settingsDividerNew
                        SettingsAPIKeyRow(title: NSLocalizedString("settings.ai.claudeApiKey", comment: ""), key: $claudeAPIKey)
                    }

                    // SECTION 6: KEYBOARD SHORTCUTS
                    SettingsSectionNew(title: NSLocalizedString("settings.section.shortcuts", comment: "")) {
                        SettingsShortcutRow(title: NSLocalizedString("shortcut.playPause", comment: ""), shortcut: "\u{2325} Space")
                        settingsDividerNew
                        SettingsShortcutRow(title: NSLocalizedString("shortcut.previousTrack", comment: ""), shortcut: "\u{2325} \u{2190}")
                        settingsDividerNew
                        SettingsShortcutRow(title: NSLocalizedString("shortcut.nextTrack", comment: ""), shortcut: "\u{2325} \u{2192}")
                        settingsDividerNew
                        SettingsShortcutRow(title: NSLocalizedString("shortcut.volumeUpDown", comment: ""), shortcut: "\u{2325} \u{2191}\u{2193}")
                        settingsDividerNew
                        SettingsShortcutRow(title: NSLocalizedString("shortcut.openYouTube", comment: ""), shortcut: "\u{2318}\u{21E7} Y")
                    }

                    // SECTION 7: PRIVACY
                    SettingsSectionNew(title: NSLocalizedString("settings.section.privacy", comment: "")) {
                        TNSettingsToggleRow(title: NSLocalizedString("settings.privacy.clipboardMonitoring", comment: ""), isOn: $clipboardMonitoring,
                                           icon: "doc.on.clipboard", iconColor: blueS)
                        settingsDividerNew
                        CalendarAccessRow()
                        settingsDividerNew
                        TNSettingsToggleRow(title: NSLocalizedString("settings.privacy.analytics", comment: ""), isOn: $analyticsEnabled,
                                           icon: "chart.bar.fill", iconColor: Color(red: 0.557, green: 0.557, blue: 0.576))
                        settingsDividerNew
                        ResetOnboardingRow()
                        settingsDividerNew
                        ClearDataRow(action: clearAllUserData)
                    }

                    // SECTION 8: ABOUT
                    AboutSectionView(
                        appVersion: appVersion,
                        buildNumber: buildNumber,
                        blueColor: blueS,
                        orangeColor: orangeS,
                        textPrimary: textPrimaryS,
                        textSecondary: textSecondaryS,
                        textTertiary: textTertiaryS,
                        onLink: { label in
                            let urlString: String
                            switch label {
                            case NSLocalizedString("about.website", comment: ""): urlString = "https://topnotch.app"
                            case NSLocalizedString("about.support", comment: ""): urlString = "mailto:support@topnotch.app"
                            case NSLocalizedString("about.privacy", comment: ""): urlString = "https://topnotch.app/privacy"
                            default: return
                            }
                            if let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 460, minHeight: 500, idealHeight: 720, maxHeight: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(bgMainS)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.03), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(borderSubtleS, lineWidth: 0.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .preferredColorScheme(resolvedColorScheme)
    }

    private var resolvedColorScheme: ColorScheme? {
        switch themeMode {
        case "Light": return .light
        case "Dark":  return .dark
        default:      return nil  // "Auto" — follow system
        }
    }

    private var settingsDividerNew: some View {
        Rectangle()
            .fill(borderSubtleS)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func clearAllUserData() {
        let keysToReset = [
            "launchAtLogin", "expandOnHover", "autoCollapseDelay", "showInMenuBar",
            "themeMode", "accentColorIndex",
            "nowPlayingControls", "showAlbumArt", "vinylAnimation", "colorMatchApp",
            "hudDisplayMode", "showVolumeHUD", "showBrightnessHUD",
            "volumeShowPercent", "brightnessShowPercent",
            "calendarEnabled", "weatherEnabled", "pomodoroEnabled", "clipboardEnabled", "youtubeEnabled",
            "batteryWidgetEnabled", "shortcutsWidgetEnabled", "notificationsWidgetEnabled",
            "quickCaptureEnabled", "lyricsEnabled",
            "youtubeClipboardDetection", "analyticsEnabled",
            "showHapticFeedback", "showBatteryIndicator", "showLockIndicator", "chargingSoundEnabled",
            "clipboardConsentAsked",
            "weatherUnit", "weatherCity",
            "aiSummarizationEnabled",
            "onboardingCompleted",
            "videoPlayer.lastX", "videoPlayer.lastY", "videoPlayer.lastWidth", "videoPlayer.lastHeight", "videoPlayer.lastVolume",
            "yt.recentlyPlayed", "activeNotchDeckCard",
        ]
        for key in keysToReset {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // Also clear persisted store data
        ClipboardHistoryStore.shared.clearAll()
        YouTubeHistoryStore.shared.clearAll()
        QuickCaptureStore.shared.clearAll()
    }
}

// MARK: - Settings Section Container

struct SettingsSectionNew<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    // Spec: section labels #6B6B70, DM Sans 11pt 600, letterSpacing 1, UPPERCASE
    // Spec: cards cornerRadius 12, fill #16161A, stroke #2A2A2E 1pt
    private var sectionLabelColor: Color { Color(red: 0.42, green: 0.42, blue: 0.44) } // #6B6B70
    private var sectionCardBg: Color { Color(red: 0.086, green: 0.086, blue: 0.102) } // #16161A
    private var sectionStroke: Color { Color(red: 0.165, green: 0.165, blue: 0.18) } // #2A2A2E

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(sectionLabelColor)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(sectionCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(sectionStroke, lineWidth: 1)
            )
        }
    }
}

// MARK: - Toggle Row

struct TNSettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var icon: String? = nil
    var iconColor: Color = Color(red: 0.557, green: 0.557, blue: 0.576)

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color(red: 0.196, green: 0.835, blue: 0.514))
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(isHovering ? Color.white.opacity(0.04) : .clear)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Value Row

struct SettingsValueRow: View {
    let title: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = Color(red: 0.557, green: 0.557, blue: 0.576)

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.44))
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(isHovering ? Color.white.opacity(0.04) : .clear)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Segment Row

struct SettingsSegmentRow: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            HStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    Button(action: { selection = option }) {
                        Text(option)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(
                                selection == option
                                    ? Color(red: 0.98, green: 0.98, blue: 0.976)
                                    : Color(red: 0.42, green: 0.42, blue: 0.44)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(
                                        selection == option
                                            ? Color(red: 0.102, green: 0.102, blue: 0.118)
                                            : Color.clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                Capsule()
                    .fill(Color(red: 0.065, green: 0.065, blue: 0.08))
            )
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }
}

// MARK: - Language Row

struct SettingsLanguageRow: View {
    @State private var selectedLanguage: String = {
        if let override = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = override.first {
            return first
        }
        return Locale.preferredLanguages.first ?? "en"
    }()

    private let languages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "🇺🇸"),
        ("ar", "العربية", "🇸🇦"),
        ("cs", "Čeština", "🇨🇿"),
        ("da", "Dansk", "🇩🇰"),
        ("de", "Deutsch", "🇩🇪"),
        ("el", "Ελληνικά", "🇬🇷"),
        ("es", "Español", "🇪🇸"),
        ("fi", "Suomi", "🇫🇮"),
        ("fr", "Français", "🇫🇷"),
        ("he", "עברית", "🇮🇱"),
        ("hu", "Magyar", "🇭🇺"),
        ("id", "Bahasa Indonesia", "🇮🇩"),
        ("it", "Italiano", "🇮🇹"),
        ("ja", "日本語", "🇯🇵"),
        ("ko", "한국어", "🇰🇷"),
        ("ms", "Bahasa Melayu", "🇲🇾"),
        ("nb", "Norsk Bokmål", "🇳🇴"),
        ("nl", "Nederlands", "🇳🇱"),
        ("pl", "Polski", "🇵🇱"),
        ("pt-BR", "Português (Brasil)", "🇧🇷"),
        ("pt-PT", "Português (Portugal)", "🇵🇹"),
        ("ro", "Română", "🇷🇴"),
        ("ru", "Русский", "🇷🇺"),
        ("sk", "Slovenčina", "🇸🇰"),
        ("sv", "Svenska", "🇸🇪"),
        ("th", "ไทย", "🇹🇭"),
        ("tr", "Türkçe", "🇹🇷"),
        ("uk", "Українська", "🇺🇦"),
        ("vi", "Tiếng Việt", "🇻🇳"),
        ("zh-Hans", "简体中文", "🇨🇳"),
        ("zh-Hant", "繁體中文", "🇹🇼"),
    ]

    private var currentLanguageName: String {
        let current = selectedLanguage
        return languages.first(where: { current.hasPrefix($0.code) })?.name
            ?? languages.first(where: { current.hasPrefix(String($0.code.prefix(2))) })?.name
            ?? "System"
    }

    var body: some View {
        HStack {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.188, green: 0.820, blue: 0.345))
                .frame(width: 26, height: 26)
                .background(Color(red: 0.188, green: 0.820, blue: 0.345).opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(NSLocalizedString("settings.appearance.language", comment: ""))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            Menu {
                Button(action: {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    selectedLanguage = Locale.preferredLanguages.first ?? "en"
                    promptRestart()
                }) {
                    Label("System", systemImage: "gear")
                }
                Divider()
                ForEach(languages, id: \.code) { lang in
                    Button(action: {
                        UserDefaults.standard.set([lang.code], forKey: "AppleLanguages")
                        selectedLanguage = lang.code
                        promptRestart()
                    }) {
                        Text("\(lang.flag) \(lang.name)")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentLanguageName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.44))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.44))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(red: 0.065, green: 0.065, blue: 0.08)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    private func promptRestart() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("settings.language.restartTitle", comment: "")
        alert.informativeText = NSLocalizedString("settings.language.restartMessage", comment: "")
        alert.addButton(withTitle: NSLocalizedString("settings.language.restartNow", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("settings.language.later", comment: ""))
        alert.alertStyle = .informational
        if alert.runModal() == .alertFirstButtonReturn {
            let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: config)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Color Picker Row

struct SettingsColorPickerRow: View {
    let title: String
    let colors: [(String, Color)]
    @Binding var selection: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            HStack(spacing: 8) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, colorPair in
                    Button(action: { selection = index }) {
                        Circle()
                            .fill(colorPair.1)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: selection == index ? 2 : 0)
                                    .frame(width: 20, height: 20)
                            )
                            .scaleEffect(selection == index ? 1.15 : 1.0)
                            .animation(.spring(duration: 0.2), value: selection)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }
}

// MARK: - Shortcut Row

struct SettingsShortcutRow: View {
    let title: String
    let shortcut: String

    @State private var isHovering = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(red: 0.102, green: 0.102, blue: 0.118))
                )
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(isHovering ? Color.white.opacity(0.04) : .clear)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - HUD Mode Row (maps display labels to code values)

struct SettingsHUDModeRow: View {
    let title: String
    @Binding var selection: String

    private let modes: [(label: String, value: String)] = [
        ("Minimal", "minimal"),
        ("Bar", "progressBar"),
        ("Notched", "notched"),
    ]

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            HStack(spacing: 2) {
                ForEach(modes, id: \.value) { mode in
                    Button(action: { selection = mode.value }) {
                        Text(mode.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(
                                selection == mode.value
                                    ? Color(red: 0.98, green: 0.98, blue: 0.976)
                                    : Color(red: 0.42, green: 0.42, blue: 0.44)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(
                                        selection == mode.value
                                            ? Color(red: 0.102, green: 0.102, blue: 0.118)
                                            : Color.clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                Capsule()
                    .fill(Color(red: 0.065, green: 0.065, blue: 0.08))
            )
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }
}

// MARK: - Status Row

struct SettingsStatusRow: View {
    let title: String
    let status: String
    let statusColor: Color

    @State private var isHovering = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(isHovering ? Color.white.opacity(0.04) : .clear)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Clear Data Row

private struct ClearDataRow: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.91, green: 0.353, blue: 0.31))
                    .frame(width: 18)
                Text(NSLocalizedString("settings.privacy.clearAllData", comment: ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.91, green: 0.353, blue: 0.31))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(isHovering ? Color(red: 0.91, green: 0.353, blue: 0.31).opacity(0.08) : .clear)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - About Section

private struct AboutSectionView: View {
    let appVersion: String
    let buildNumber: String
    let blueColor: Color
    let orangeColor: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let onLink: (String) -> Void

    @State private var iconHovered = false
    @State private var iconAppeared = false

    var body: some View {
        VStack(spacing: 10) {
            // App icon
            Image("TopNotchLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: blueColor.opacity(0.3), radius: 12, y: 4)
            .scaleEffect(iconAppeared ? (iconHovered ? 1.06 : 1.0) : 0.7)
            .opacity(iconAppeared ? 1 : 0)
            .animation(.spring(duration: 0.5, bounce: 0.45), value: iconAppeared)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: iconHovered)
            .onHover { iconHovered = $0 }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    iconAppeared = true
                }
            }

            Text(NSLocalizedString("about.appName", comment: ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(textPrimary)

            Text("Version \(appVersion) (Build \(buildNumber))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary)

            Text(NSLocalizedString("about.madeWith", comment: ""))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textTertiary)

            HStack(spacing: 0) {
                ForEach([NSLocalizedString("about.website", comment: ""), NSLocalizedString("about.support", comment: ""), NSLocalizedString("about.privacy", comment: "")], id: \.self) { label in
                    if label != NSLocalizedString("about.website", comment: "") {
                        Text("\u{00B7}")
                            .foregroundStyle(textTertiary)
                            .padding(.horizontal, 8)
                    }
                    AboutLinkButton(label: label, color: blueColor, action: { onLink(label) })
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Stepper Row

struct SettingsStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    var icon: String? = nil
    var iconColor: Color = Color(red: 0.557, green: 0.557, blue: 0.576)

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            HStack(spacing: 0) {
                Button(action: { if value > range.lowerBound { value -= 1 } }) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(value > range.lowerBound ? Color(red: 0.98, green: 0.98, blue: 0.976) : Color(red: 0.42, green: 0.42, blue: 0.44))
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.plain)
                Text("\(value)\(unit)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
                    .frame(minWidth: 36)
                Button(action: { if value < range.upperBound { value += 1 } }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(value < range.upperBound ? Color(red: 0.98, green: 0.98, blue: 0.976) : Color(red: 0.42, green: 0.42, blue: 0.44))
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.plain)
            }
            .background(Color(red: 0.065, green: 0.065, blue: 0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(red: 0.165, green: 0.165, blue: 0.18), lineWidth: 0.5))
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }
}

// MARK: - API Key Row

struct SettingsAPIKeyRow: View {
    let title: String
    @Binding var key: String
    var placeholder: String = "sk-ant-..."

    @State private var isEditing = false
    @State private var isHovering = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "BF5AF2"))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            ZStack(alignment: .trailing) {
                if key.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.44))
                        .padding(.horizontal, 8)
                }
                SecureField("", text: $key)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
                    .focused($focused)
                    .frame(width: 160)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.065, green: 0.065, blue: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                focused ? Color(hex: "BF5AF2").opacity(0.6) : Color(red: 0.165, green: 0.165, blue: 0.18),
                                lineWidth: focused ? 1.5 : 0.5
                            )
                    )
                    .animation(.easeOut(duration: 0.15), value: focused)
            }
            if !key.isEmpty {
                Button(action: { key = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.44))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(isHovering ? Color.white.opacity(0.04) : .clear)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onChange(of: key) { _, newValue in
            KeychainHelper.save(newValue)
            NotificationCenter.default.post(name: NSNotification.Name("TopNotch.APIKeyChanged"), object: nil)
        }
    }
}

// MARK: - Reset Onboarding Row

private struct ResetOnboardingRow: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var isHovering = false

    var body: some View {
        Button(action: { onboardingCompleted = false }) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.039, green: 0.518, blue: 1.0))
                    .frame(width: 18)
                Text(NSLocalizedString("settings.privacy.showOnboarding", comment: ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.44))
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(isHovering ? Color.white.opacity(0.04) : .clear)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { isHovering = $0 }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Access Row

private struct CalendarAccessRow: View {
    @State private var statusText = "Checking..."
    @State private var statusColor = Color(red: 0.42, green: 0.42, blue: 0.44)
    @State private var isHovering = false
    private let store = EKEventStore()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.91, green: 0.353, blue: 0.31))
                .frame(width: 18)
            Text(NSLocalizedString("settings.privacy.calendarAccess", comment: ""))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.976))
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(isHovering ? Color.white.opacity(0.04) : .clear)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onAppear { refreshStatus() }
        .contentShape(Rectangle())
        .onTapGesture {
            if statusText == "Not Granted" || statusText == "Denied",
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func refreshStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            statusText = "Granted"; statusColor = Color(red: 0.196, green: 0.835, blue: 0.514)
        case .fullAccess:
            statusText = "Full Access"; statusColor = Color(red: 0.196, green: 0.835, blue: 0.514)
        case .writeOnly:
            statusText = "Write Only"; statusColor = Color(red: 1.0, green: 0.624, blue: 0.039)
        case .denied, .restricted:
            statusText = "Denied"; statusColor = Color(red: 0.91, green: 0.353, blue: 0.31)
        case .notDetermined:
            statusText = "Not Granted"; statusColor = Color(red: 0.42, green: 0.42, blue: 0.44)
        @unknown default:
            statusText = "Unknown"; statusColor = Color(red: 0.42, green: 0.42, blue: 0.44)
        }
    }
}

private struct AboutLinkButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovering ? color : color.opacity(0.75))
                .underline(isHovering)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }
}
