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

    // Privacy
    @AppStorage("youtubeClipboardDetection") private var clipboardMonitoring = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false

    // Feedback & indicators
    @AppStorage("showHapticFeedback") private var showHapticFeedback = true
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("showLockIndicator") private var showLockIndicator = true
    @AppStorage("chargingSoundEnabled") private var chargingSoundEnabled = true

    @Environment(\.dismiss) var dismiss

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
                        Text("Settings")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(textPrimaryS)
                    }
                    Text("Top Notch v\(appVersion)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(textTertiaryS)
                }
                Spacer()
                Button(action: { dismiss() }) {
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
                    SettingsSectionNew(title: "GENERAL") {
                        TNSettingsToggleRow(title: "Launch at Login", isOn: $launchAtLogin)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Hover to Expand", isOn: $hoverToExpand)
                        settingsDividerNew
                        SettingsValueRow(title: "Auto-collapse Delay", value: "\(autoCollapseDelay)s")
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Show in Menu Bar", isOn: $showInMenuBar)
                    }

                    // SECTION 2: APPEARANCE
                    SettingsSectionNew(title: "APPEARANCE") {
                        SettingsSegmentRow(title: "Theme", options: ["Auto", "Light", "Dark"], selection: $themeMode)
                        settingsDividerNew
                        SettingsColorPickerRow(title: "Accent Color", colors: accentColors, selection: $accentColorIndex)
                    }

                    // SECTION 3: MEDIA
                    SettingsSectionNew(title: "MEDIA") {
                        TNSettingsToggleRow(title: "Now Playing Controls", isOn: $nowPlayingControls)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Show Album Artwork", isOn: $showAlbumArt)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Vinyl Spin Animation", isOn: $vinylAnimation)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Color Match App", isOn: $colorMatchApp)
                    }

                    // SECTION 4: HUD REPLACEMENT
                    SettingsSectionNew(title: "HUD REPLACEMENT") {
                        TNSettingsToggleRow(title: "Replace Volume HUD", isOn: $replaceVolumeHUD)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Replace Brightness HUD", isOn: $replaceBrightnessHUD)
                        settingsDividerNew
                        SettingsHUDModeRow(title: "HUD Style", selection: $hudDisplayMode)
                    }

                    // SECTION 4B: INDICATORS & FEEDBACK
                    SettingsSectionNew(title: "INDICATORS & FEEDBACK") {
                        TNSettingsToggleRow(title: "Battery Indicator", isOn: $showBatteryIndicator)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Lock/Unlock Indicator", isOn: $showLockIndicator)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Charging Sound", isOn: $chargingSoundEnabled)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Haptic Feedback", isOn: $showHapticFeedback)
                    }

                    // SECTION 5: WIDGETS
                    SettingsSectionNew(title: "WIDGETS") {
                        TNSettingsToggleRow(title: "Calendar", isOn: $calendarEnabled)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Weather", isOn: $weatherEnabled)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Pomodoro Timer", isOn: $pomodoroEnabled)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Clipboard History", isOn: $clipboardEnabled)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "YouTube Player", isOn: $youtubeEnabled)
                    }

                    // SECTION 6: KEYBOARD SHORTCUTS
                    SettingsSectionNew(title: "KEYBOARD SHORTCUTS") {
                        SettingsShortcutRow(title: "Play / Pause", shortcut: "\u{2325} Space")
                        settingsDividerNew
                        SettingsShortcutRow(title: "Previous Track", shortcut: "\u{2325} \u{2190}")
                        settingsDividerNew
                        SettingsShortcutRow(title: "Next Track", shortcut: "\u{2325} \u{2192}")
                        settingsDividerNew
                        SettingsShortcutRow(title: "Volume Up / Down", shortcut: "\u{2325} \u{2191}\u{2193}")
                        settingsDividerNew
                        SettingsShortcutRow(title: "Open YouTube", shortcut: "\u{2318}\u{21E7} Y")
                    }

                    // SECTION 7: PRIVACY
                    SettingsSectionNew(title: "PRIVACY") {
                        TNSettingsToggleRow(title: "Clipboard Monitoring", isOn: $clipboardMonitoring)
                        settingsDividerNew
                        SettingsStatusRow(title: "Calendar Access", status: "Granted", statusColor: greenS)
                        settingsDividerNew
                        TNSettingsToggleRow(title: "Analytics", isOn: $analyticsEnabled)
                        settingsDividerNew
                        Button(action: clearAllUserData) {
                            HStack {
                                Text("Clear All Data")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(redS)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // SECTION 8: ABOUT
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [blueS.opacity(0.3), orangeS.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "sparkle")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                            )

                        Text("Top Notch")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(textPrimaryS)

                        Text("Version \(appVersion) (Build \(buildNumber))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textSecondaryS)

                        Text("Made with \u{2764}\u{FE0F} for Mac")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textTertiaryS)

                        HStack(spacing: 16) {
                            aboutLink("Website")
                            Text("\u{00B7}")
                                .foregroundStyle(textTertiaryS)
                            aboutLink("Support")
                            Text("\u{00B7}")
                                .foregroundStyle(textTertiaryS)
                            aboutLink("Privacy")
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 460, height: 640)
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
        .preferredColorScheme(.dark)
    }

    private var settingsDividerNew: some View {
        Rectangle()
            .fill(borderSubtleS)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func aboutLink(_ label: String) -> some View {
        Button(action: {
            // Open relevant URL based on label
            let urlString: String
            switch label {
            case "Website": urlString = "https://topnotch.app"
            case "Support": urlString = "mailto:support@topnotch.app"
            case "Privacy": urlString = "https://topnotch.app/privacy"
            default: return
            }
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(blueS)
        }
        .buttonStyle(.plain)
    }

    private func clearAllUserData() {
        let keysToReset = [
            "launchAtLogin", "expandOnHover", "autoCollapseDelay", "showInMenuBar",
            "themeMode", "accentColorIndex",
            "nowPlayingControls", "showAlbumArt", "vinylAnimation", "colorMatchApp",
            "hudDisplayMode", "showVolumeHUD", "showBrightnessHUD",
            "calendarEnabled", "weatherEnabled", "pomodoroEnabled", "clipboardEnabled", "youtubeEnabled",
            "youtubeClipboardDetection", "analyticsEnabled",
            "showHapticFeedback", "showBatteryIndicator", "showLockIndicator", "chargingSoundEnabled",
            "clipboardConsentAsked",
            "videoPlayer.lastX", "videoPlayer.lastY", "videoPlayer.lastWidth", "videoPlayer.lastHeight", "videoPlayer.lastVolume",
            "yt.recentlyPlayed", "activeNotchDeckCard",
        ]
        for key in keysToReset {
            UserDefaults.standard.removeObject(forKey: key)
        }
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

    var body: some View {
        HStack {
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
    }
}

// MARK: - Value Row

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
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
    }
}
