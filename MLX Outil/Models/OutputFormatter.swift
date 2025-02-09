//
//  OutputFormatter.swift
//  MLX Outil
//
//  Created by Rudrank Riyam on 2/9/25.
//

import Foundation

final class OutputFormatter {
    static func formatWeatherData(_ weather: WeatherKitManager.WeatherData) -> String {
        String(format: Constants.Weather.formatString,
               weather.temperature,
               weather.feelsLike,
               weather.condition,
               weather.humidity * 100,
               weather.windSpeed,
               weather.uvIndex,
               weather.visibility / 1000,
               weather.pressure,
               weather.precipitationChance * 100)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "N/A"
    }

    static func formatDistance(_ distance: Double) -> String {
        let kilometers = distance / 1000
        return String(format: "%.2f km", kilometers)
    }
}

