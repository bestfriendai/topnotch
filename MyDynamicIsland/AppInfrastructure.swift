import Foundation
import OSLog

// MARK: - App-wide Logging

/// Centralized OSLog categories for structured, filterable logging across Top Notch.
/// Use in Console.app with subsystem: "com.topnotch.app" to filter per category.
enum AppLogger {
    static let lifecycle  = Logger(subsystem: "com.topnotch.app", category: "lifecycle")
    static let permissions = Logger(subsystem: "com.topnotch.app", category: "permissions")
    static let notch      = Logger(subsystem: "com.topnotch.app", category: "notch")
    static let youtube    = Logger(subsystem: "com.topnotch.app", category: "youtube")
    static let media      = Logger(subsystem: "com.topnotch.app", category: "media")
    static let battery    = Logger(subsystem: "com.topnotch.app", category: "battery")
    static let clipboard  = Logger(subsystem: "com.topnotch.app", category: "clipboard")
    static let weather    = Logger(subsystem: "com.topnotch.app", category: "weather")
}

// MARK: - Weather Load State

/// Explicit state machine for the weather data fetch cycle.
/// Drives UI to show the correct empty/error/loading/loaded surface at every stage.
enum WeatherLoadState: Equatable {
    case idle
    case loading
    case loaded(WeatherViewData)
    case permissionDenied
    case offline
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var isError: Bool {
        switch self {
        case .permissionDenied, .offline, .failed: return true
        default: return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .permissionDenied: return "Location access is required to show weather. Tap to open Settings."
        case .offline:          return "No internet connection. Weather will refresh when you're back online."
        case .failed(let msg):  return msg
        default:                return nil
        }
    }
}

/// Lightweight view-model data for the weather card.
/// Kept as a plain struct so it is cheaply Equatable and diffable.
struct WeatherViewData: Equatable {
    var city: String
    var temperature: String    // e.g. "18°C" or "64°F"
    var conditionIcon: String  // SF Symbol name
    var conditionLabel: String // e.g. "Partly Cloudy"
    var humidity: String       // e.g. "72%"
    var high: String
    var low: String
    var lastUpdated: Date
}

// MARK: - Notch Accent Colors

/// Semantic accent colors per feature domain, used across cards, icons, and highlights.
enum TopNotchAccent {
    case media
    case weather
    case youtube
    case utility
    case battery
    case pomodoro

    var colorName: String {
        switch self {
        case .media:    return "green"
        case .weather:  return "blue"
        case .youtube:  return "red"
        case .utility:  return "white"
        case .battery:  return "yellow"
        case .pomodoro: return "orange"
        }
    }
}
