//
//  WeatherStore.swift
//  CalenderApp
//
//  Fetches current conditions and a daily forecast from WeatherKit, anchored to
//  the user's location. Everything degrades gracefully: if WeatherKit isn't
//  entitled or location is denied, `now`/`daily` simply stay empty and the UI
//  hides its weather affordances.
//
//  REQUIRES the "WeatherKit" capability on the app target (paid Apple Developer
//  account) and an NSLocationWhenInUseUsageDescription (added via build setting).
//

import Foundation
import WeatherKit

/// A snapshot of current conditions.
struct WeatherNow: Sendable {
    let temperature: Measurement<UnitTemperature>
    let symbolName: String
    let condition: String

    var temperatureText: String { WeatherFormat.temperature(temperature) }
}

/// One day's high/low forecast.
struct DayForecast: Identifiable, Sendable {
    let date: Date
    let symbolName: String
    let high: Measurement<UnitTemperature>
    let low: Measurement<UnitTemperature>

    var id: Date { date }
    var highText: String { WeatherFormat.temperature(high) }
    var lowText: String { WeatherFormat.temperature(low) }
}

import CoreLocation

@MainActor
@Observable
final class WeatherStore {
    private(set) var now: WeatherNow?
    private(set) var daily: [DayForecast] = []
    private(set) var cityName: String = "Sylhet"
    private(set) var sunriseText: String = "06:07"
    private(set) var sunsetText: String = "17:59"

    private var lastFetch: Date?
    private let minInterval: TimeInterval = 30 * 60

    /// Fetches weather for the current location, throttled to twice an hour.
    func refresh() async {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < minInterval { return }
        guard let location = await LocationProvider.current() else { return }
        
        // Reverse-geocode to get the city name
        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
           let city = placemarks.first?.locality {
            cityName = city
        }

        guard let weather = try? await WeatherKit.WeatherService.shared.weather(for: location)
        else { return }

        lastFetch = Date()
        now = WeatherNow(
            temperature: weather.currentWeather.temperature,
            symbolName: weather.currentWeather.symbolName,
            condition: weather.currentWeather.condition.description
        )
        daily = weather.dailyForecast.forecast.prefix(10).map {
            DayForecast(date: $0.date, symbolName: $0.symbolName,
                        high: $0.highTemperature, low: $0.lowTemperature)
        }
        
        // Parse sunrise and sunset from forecast sun dates
        if let todayWeather = weather.dailyForecast.forecast.first {
            let sun = todayWeather.sun
            let f = DateFormatter()
            f.timeStyle = .short
            if let rise = sun.sunrise { sunriseText = f.string(from: rise) }
            if let set = sun.sunset { sunsetText = f.string(from: set) }
        }
    }

    /// The forecast for a given calendar day, if within range.
    func forecast(on date: Date) -> DayForecast? {
        daily.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

/// Locale-aware temperature formatting (°C or °F by region), rounded to whole degrees.
enum WeatherFormat {
    static func temperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let unit: UnitTemperature = Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
        let value = Int(measurement.converted(to: unit).value.rounded())
        return "\(value)°"
    }
}
