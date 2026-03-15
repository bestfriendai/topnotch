import Foundation

enum AppBuildVariant: String {
    case direct
    case appStore

    static let current: AppBuildVariant = {
        #if APP_STORE_BUILD
        return .appStore
        #else
        return .direct
        #endif
    }()

    var supportsPrivateSystemIntegrations: Bool {
        self == .direct
    }

    var supportsAdvancedMediaControls: Bool {
        self == .direct
    }

    var supportsGlobalKeyboardShortcuts: Bool {
        self == .direct
    }

    var supportsInterceptedBrightnessHUD: Bool {
        self == .direct
    }

    var supportsLockScreenIndicators: Bool {
        self == .direct
    }

    var releaseChannelName: String {
        switch self {
        case .direct:
            return "Direct"
        case .appStore:
            return "App Store"
        }
    }
}