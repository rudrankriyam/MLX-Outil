import Foundation
import WeatherKit
import CoreLocation

class WeatherKitManager {
    // Singleton instance
    static let shared = WeatherKitManager()

    // WeatherService instance for fetching weather data
    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()

    private init() {}

    // Error types for weather-related operations
    enum WeatherKitError: Error {
        case locationNotFound
        case weatherDataUnavailable
        case unauthorized
    }

    // Weather data model to hold the fetched information
    struct WeatherData {
        let temperature: Double
        let condition: String
        let humidity: Double
        let windSpeed: Double
        let feelsLike: Double
        let uvIndex: Int
        let visibility: Double
        let pressure: Double
        let precipitationChance: Double
    }

    // Add Logger enum
    private enum Logger {
        static func log(_ message: String, type: String = "INFO") {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[WeatherKit][\(type)] [\(timestamp)]: \(message)")
        }
    }

    // Fetch weather for a specific city
    func fetchWeather(forCity city: String) async throws -> WeatherData {
        Logger.log("Starting weather fetch for city: \(city)")

        do {
            Logger.log("Geocoding city: \(city)")
            let coordinates = try await getCoordinates(for: city)
            Logger.log("Successfully geocoded \(city) to coordinates: \(coordinates.coordinate.latitude), \(coordinates.coordinate.longitude)")

            let weather = try await fetchWeather(for: coordinates)
            Logger.log("Successfully fetched weather data for \(city)")
            return weather
        } catch {
            Logger.log("Failed to fetch weather for \(city): \(error)", type: "ERROR")
            throw error
        }
    }

    private func getCoordinates(for city: String) async throws -> CLLocation {
        Logger.log("Starting geocoding for city: \(city)")
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(city)
            guard let location = placemarks.first?.location else {
                Logger.log("No location found for city: \(city)", type: "ERROR")
                throw WeatherKitError.locationNotFound
            }
            Logger.log("Geocoding successful for \(city)")
            return location
        } catch {
            Logger.log("Geocoding failed for \(city): \(error)", type: "ERROR")
            throw WeatherKitError.locationNotFound
        }
    }

    // Fetch weather for current location
    func fetchWeatherForCurrentLocation() async throws -> WeatherData {
        Logger.log("Attempting to fetch weather for current location")

        guard let location = locationManager.location else {
            Logger.log("Current location not available", type: "ERROR")
            throw WeatherKitError.locationNotFound
        }

        Logger.log("Current location obtained: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        return try await fetchWeather(for: location)
    }

    private func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        Logger.log("Starting weather service request for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        do {
            let weather = try await weatherService.weather(for: location)
            Logger.log("Weather service request successful")

            let weatherData = WeatherData(
                temperature: weather.currentWeather.temperature.value,
                condition: weather.currentWeather.condition.description,
                humidity: weather.currentWeather.humidity,
                windSpeed: weather.currentWeather.wind.speed.value,
                feelsLike: weather.currentWeather.apparentTemperature.value,
                uvIndex: weather.currentWeather.uvIndex.value,
                visibility: weather.currentWeather.visibility.value,
                pressure: weather.currentWeather.pressure.value,
                precipitationChance: weather.hourlyForecast.first?.precipitationChance ?? 0.0
            )

            Logger.log("Weather data processed successfully: \(weatherData)")
            return weatherData
        } catch {
            Logger.log("Weather service request failed: \(error)", type: "ERROR")
            throw WeatherKitError.weatherDataUnavailable
        }
    }

    // Setup location manager
    func requestLocationAuthorization() {
        Logger.log("Requesting location authorization")
        locationManager.requestWhenInUseAuthorization()
        Logger.log("Location authorization status: \(locationManager.authorizationStatus.rawValue)")
    }
}

// Add CustomStringConvertible conformance to WeatherData for better logging
extension WeatherKitManager.WeatherData: CustomStringConvertible {
    var description: String {
        return """
        Temperature: \(temperature)°C, 
        Feels Like: \(feelsLike)°C, 
        Condition: \(condition), 
        Humidity: \(humidity * 100)%, 
        Wind Speed: \(windSpeed) km/h
        """
    }
}
