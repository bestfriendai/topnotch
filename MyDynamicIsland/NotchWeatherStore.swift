import Combine
import OSLog
import SwiftUI

// MARK: - Weather Store

@MainActor
final class NotchWeatherStore: ObservableObject {
    @Published var cityName = "San Francisco"
    @Published var temperatureText = "--°"
    @Published var conditionText = "Enter a city to load weather"
    @Published var symbolName = "cloud.sun.fill"
    @Published var isLoading = false
    @Published var highTemp: String?
    @Published var lowTemp: String?
    @Published var weatherCode: Int = -1
    @Published var forecastDays: [ForecastDay] = []
    @Published var hoursByDay: [String: [HourlyEntry]] = [:]
    @AppStorage("weatherUnit") private var weatherUnit = "celsius"

    private var lastLoadedCity = ""

    struct ForecastDay: Identifiable {
        let id = UUID()
        let dayLabel: String
        let emoji: String
        let temp: String        // high temp display value
        let highTemp: String    // "72°"
        let lowTemp: String     // "58°"
        let weatherCode: Int
        let dateKey: String     // "yyyy-MM-dd" for hourly lookup
    }

    struct HourlyEntry: Identifiable {
        let id = UUID()
        let hour: String        // "3pm", "12am"
        let temp: String        // "72°"
        let weatherCode: Int
        var emoji: String { NotchWeatherStore.weatherEmoji(for: weatherCode) }
    }

    var hasWeather: Bool {
        temperatureText != "--°"
    }

    func load(city: String, force: Bool = false) async {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else {
            temperatureText = "--°"
            conditionText = "Enter a city to load weather"
            symbolName = "cloud.sun.fill"
            return
        }

        if !force && trimmedCity.caseInsensitiveCompare(lastLoadedCity) == .orderedSame {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let encodedCity = trimmedCity.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedCity
            guard let geocodeURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCity)&count=1&language=en&format=json") else {
                conditionText = "Invalid city name"
                temperatureText = "--°"
                return
            }
            let (geocodeData, _) = try await URLSession.shared.data(from: geocodeURL)
            let geocodeResponse = try JSONDecoder().decode(OpenMeteoGeocodeResponse.self, from: geocodeData)

            guard let result = geocodeResponse.results?.first else {
                conditionText = "City not found"
                temperatureText = "--°"
                symbolName = "mappin.slash"
                return
            }

            cityName = [result.name, result.admin1, result.country]
                .compactMap { $0 }
                .joined(separator: ", ")

            let unitParam = weatherUnit == "fahrenheit" ? "&temperature_unit=fahrenheit" : ""
            guard let weatherURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(result.latitude)&longitude=\(result.longitude)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&hourly=temperature_2m,weather_code\(unitParam)&timezone=auto&forecast_days=7") else {
                conditionText = "Weather unavailable"
                temperatureText = "--°"
                return
            }
            let (weatherData, _) = try await URLSession.shared.data(from: weatherURL)
            let weatherResponse = try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: weatherData)

            temperatureText = "\(Int(weatherResponse.current.temperature_2m.rounded()))°"
            conditionText = Self.conditionDescription(for: weatherResponse.current.weather_code)
            symbolName = Self.symbolName(for: weatherResponse.current.weather_code)
            weatherCode = weatherResponse.current.weather_code

            if let daily = weatherResponse.daily,
               let maxTemps = daily.temperature_2m_max, let maxT = maxTemps.first,
               let minTemps = daily.temperature_2m_min, let minT = minTemps.first {
                highTemp = "\(Int(maxT.rounded()))°"
                lowTemp = "\(Int(minT.rounded()))°"
            }

            // Build 7-day forecast
            if let daily = weatherResponse.daily,
               let maxTemps = daily.temperature_2m_max,
               let minTemps = daily.temperature_2m_min,
               let times = daily.time,
               let codes = daily.weather_code {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let dayFmt = DateFormatter()
                dayFmt.dateFormat = "EEE"
                var days: [ForecastDay] = []
                let count = min(7, min(maxTemps.count, times.count))
                for i in 0..<count {
                    let label: String
                    if let d = df.date(from: times[i]) {
                        label = i == 0 ? "TODAY" : dayFmt.string(from: d).uppercased()
                    } else {
                        label = "--"
                    }
                    let code = i < codes.count ? codes[i] : -1
                    let emoji = Self.weatherEmoji(for: code)
                    let maxTStr = "\(Int(maxTemps[i].rounded()))°"
                    let minTStr = i < minTemps.count ? "\(Int(minTemps[i].rounded()))°" : "--"
                    days.append(ForecastDay(
                        dayLabel: label,
                        emoji: emoji,
                        temp: maxTStr,
                        highTemp: maxTStr,
                        lowTemp: minTStr,
                        weatherCode: code,
                        dateKey: times[i]
                    ))
                }
                forecastDays = days
            }

            // Build hourly data grouped by day
            if let hourly = weatherResponse.hourly,
               let times = hourly.time,
               let temps = hourly.temperature_2m,
               let codes = hourly.weather_code {
                let isoFmt = DateFormatter()
                isoFmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
                isoFmt.locale = Locale(identifier: "en_US_POSIX")
                let hourDisplayFmt = DateFormatter()
                hourDisplayFmt.dateFormat = "ha"
                hourDisplayFmt.locale = Locale(identifier: "en_US")
                var byDay: [String: [HourlyEntry]] = [:]
                let entryCount = min(times.count, min(temps.count, codes.count))
                for i in 0..<entryCount {
                    let timeStr = times[i]
                    let dateKey = String(timeStr.prefix(10))
                    let hourLabel: String
                    if let date = isoFmt.date(from: timeStr) {
                        hourLabel = hourDisplayFmt.string(from: date).lowercased()
                    } else {
                        hourLabel = "--"
                    }
                    let entry = HourlyEntry(
                        hour: hourLabel,
                        temp: "\(Int(temps[i].rounded()))°",
                        weatherCode: codes[i]
                    )
                    byDay[dateKey, default: []].append(entry)
                }
                hoursByDay = byDay
            }

            lastLoadedCity = trimmedCity
        } catch {
            AppLogger.weather.error("Weather fetch failed: \(error.localizedDescription, privacy: .public)")
            conditionText = "Weather unavailable"
            temperatureText = "--°"
            symbolName = "wifi.exclamationmark"
        }
    }

    private static func conditionDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 65, 66, 67: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Conditions updating"
        }
    }

    private static func symbolName(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func weatherEmoji(for code: Int) -> String {
        switch code {
        case 0: return "\u{2600}\u{FE0F}"
        case 1, 2, 3: return "\u{26C5}"
        case 45, 48: return "\u{1F32B}\u{FE0F}"
        case 51, 53, 55, 56, 57: return "\u{1F326}\u{FE0F}"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "\u{1F327}\u{FE0F}"
        case 71, 73, 75, 77, 85, 86: return "\u{2744}\u{FE0F}"
        case 95, 96, 99: return "\u{26C8}\u{FE0F}"
        default: return "\u{2601}\u{FE0F}"
        }
    }
}

private struct OpenMeteoGeocodeResponse: Decodable {
    let results: [OpenMeteoGeocodeResult]?
}

private struct OpenMeteoGeocodeResult: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let admin1: String?
    let country: String?
}

private struct OpenMeteoWeatherResponse: Decodable {
    let current: OpenMeteoCurrentWeather
    let daily: OpenMeteoDailyWeather?
    let hourly: OpenMeteoHourlyWeather?
}

private struct OpenMeteoCurrentWeather: Decodable {
    let temperature_2m: Double
    let weather_code: Int
}

private struct OpenMeteoDailyWeather: Decodable {
    let temperature_2m_max: [Double]?
    let temperature_2m_min: [Double]?
    let weather_code: [Int]?
    let time: [String]?
}

private struct OpenMeteoHourlyWeather: Decodable {
    let time: [String]?
    let temperature_2m: [Double]?
    let weather_code: [Int]?
}

// MARK: - Animated Weather Particles

struct WeatherParticleView: View {
    let weatherCode: Int

    @State private var particles: [WeatherParticle] = []
    @State private var animationTimer: Timer?

    private var particleConfig: (emoji: String, count: Int, speed: ClosedRange<Double>)? {
        switch weatherCode {
        case 51, 53, 55, 56, 57: return ("\u{1F4A7}", 6, 1.5...2.5) // drizzle
        case 61, 63, 65, 66, 67, 80, 81, 82: return ("\u{1F327}", 8, 1.0...2.0) // rain
        case 71, 73, 75, 77, 85, 86: return ("\u{2744}\u{FE0F}", 7, 2.0...3.5) // snow
        case 95, 96, 99: return ("\u{26A1}", 4, 0.8...1.5) // thunderstorm
        case 0: return ("\u{2728}", 3, 3.0...5.0) // clear - subtle sparkles
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.symbol)
                        .font(.system(size: particle.size))
                        .opacity(particle.opacity)
                        .position(x: particle.x * geo.size.width, y: particle.y * geo.size.height)
                        .blur(radius: particle.blur)
                }
            }
        }
        .clipped()
        .onAppear { startParticles() }
        .onDisappear { stopParticles() }
        .onChange(of: weatherCode) { _, _ in
            particles.removeAll()
            startParticles()
        }
    }

    private func startParticles() {
        guard let config = particleConfig else { return }
        // Seed initial particles
        for _ in 0..<config.count {
            particles.append(WeatherParticle(
                symbol: config.emoji,
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 6...10),
                opacity: Double.random(in: 0.15...0.4),
                speed: Double.random(in: config.speed),
                blur: CGFloat.random(in: 0...1)
            ))
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                for i in particles.indices {
                    particles[i].y += CGFloat(0.1 / particles[i].speed)
                    // Gentle horizontal drift
                    particles[i].x += CGFloat.random(in: -0.003...0.003)
                    // Reset when off-screen
                    if particles[i].y > 1.1 {
                        particles[i].y = -0.1
                        particles[i].x = CGFloat.random(in: 0...1)
                        particles[i].opacity = Double.random(in: 0.15...0.4)
                    }
                }
            }
        }
    }

    private func stopParticles() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

struct WeatherParticle: Identifiable {
    let id = UUID()
    var symbol: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var blur: CGFloat
}

// MARK: - Lightweight weather particle (used in focused weather card)

struct WeatherParticleLite: View {
    let weatherCode: Int

    private var emoji: String? {
        switch weatherCode {
        case 61, 63, 65, 80, 81, 82: return "\u{1F327}"
        case 71, 73, 75, 85, 86: return "\u{2744}\u{FE0F}"
        case 95, 96, 99: return "\u{26A1}"
        case 0: return "\u{2728}"
        default: return nil
        }
    }

    @State private var opacity: Double = 0
    var body: some View {
        if let e = emoji {
            HStack {
                Spacer()
                Text(e)
                    .font(.system(size: 48))
                    .opacity(opacity * 0.15)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { opacity = 1 } }
        }
    }
}
