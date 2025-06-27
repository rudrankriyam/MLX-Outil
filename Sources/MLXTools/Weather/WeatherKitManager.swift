import CoreLocation
import Foundation
import WeatherKit

public enum WeatherKitError: Error {
    case locationNotFound
    case weatherDataUnavailable
    case unauthorized
}

public struct WeatherData: Sendable, Codable {
    public let temperature: Double
    public let condition: String
    public let humidity: Double
    public let windSpeed: Double
    public let feelsLike: Double
    public let uvIndex: Int
    public let visibility: Double
    public let pressure: Double
    public let precipitationChance: Double
}

public class WeatherKitManager {
    public static let shared = WeatherKitManager()

    // WeatherService instance for fetching weather data
    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()

    public init() {}


    // Add Logger enum
    private enum Logger {
        static func log(_ message: String, type: String = "INFO") {
            let timestamp = DateFormatter.localizedString(
                from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[WeatherKit][\(type)] [\(timestamp)]: \(message)")
        }
    }

    // Fetch weather for a specific city
    public func fetchWeather(forCity city: String) async throws -> WeatherData {
        Logger.log("Starting weather fetch for city: \(city)")

        do {
            Logger.log("Geocoding city: \(city)")
            let coordinates = try await getCoordinates(for: city)
            Logger.log(
                "Successfully geocoded \(city) to coordinates: \(coordinates.coordinate.latitude), \(coordinates.coordinate.longitude)"
            )

            let weather = try await fetchWeather(for: coordinates)
            Logger.log("Successfully fetched weather data for \(city)")
            return weather
        } catch {
            Logger.log(
                "Failed to fetch weather for \(city): \(error)", type: "ERROR")
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
    public func fetchWeatherForCurrentLocation() async throws -> WeatherData {
        Logger.log("Attempting to fetch weather for current location")

        guard let location = locationManager.location else {
            Logger.log("Current location not available", type: "ERROR")
            throw WeatherKitError.locationNotFound
        }

        Logger.log(
            "Current location obtained: \(location.coordinate.latitude), \(location.coordinate.longitude)"
        )
        return try await fetchWeather(for: location)
    }

    private let openMeteoBaseURL = "https://api.open-meteo.com/v1/forecast"

    private struct OpenMeteoResponse: Codable {
        let current: CurrentWeather

        struct CurrentWeather: Codable {
            let temperature: Double
            let windspeed: Double
            let relativehumidity: Double
            let apparentTemperature: Double
            let precipitation: Double
            let pressure: Double

            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
                case windspeed = "windspeed_10m"
                case relativehumidity = "relative_humidity_2m"
                case apparentTemperature = "apparent_temperature"
                case precipitation
                case pressure = "surface_pressure"
            }
        }
    }

    private func fetchWeatherFromOpenMeteo(for location: CLLocation)
        async throws -> WeatherData
    {
        Logger.log(
            "Falling back to OpenMeteo for location: \(location.coordinate.latitude), \(location.coordinate.longitude)"
        )

        let urlString =
            "\(openMeteoBaseURL)?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,surface_pressure,precipitation,windspeed_10m"

        guard let url = URL(string: urlString) else {
            throw WeatherKitError.weatherDataUnavailable
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(
                OpenMeteoResponse.self, from: data)

            return WeatherData(
                temperature: response.current.temperature,
                condition: "Not available",
                humidity: response.current.relativehumidity / 100.0,
                windSpeed: response.current.windspeed,
                feelsLike: response.current.apparentTemperature,
                uvIndex: 0,
                visibility: 0,
                pressure: response.current.pressure,
                precipitationChance: response.current.precipitation
            )
        } catch {
            Logger.log("OpenMeteo request failed: \(error)", type: "ERROR")
            throw WeatherKitError.weatherDataUnavailable
        }
    }

    private func fetchWeather(for location: CLLocation) async throws
        -> WeatherData
    {
        Logger.log(
            "Starting weather service request for location: \(location.coordinate.latitude), \(location.coordinate.longitude)"
        )

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
                precipitationChance: weather.hourlyForecast.first?
                    .precipitationChance ?? 0.0
            )

            Logger.log("Weather data processed successfully: \(weatherData)")
            return weatherData
        } catch {
            Logger.log(
                "WeatherKit request failed, attempting OpenMeteo fallback: \(error)",
                type: "WARNING")
            return try await fetchWeatherFromOpenMeteo(for: location)
        }
    }

    // Setup location manager
    public func requestLocationAuthorization() {
        Logger.log("Requesting location authorization")
        locationManager.requestWhenInUseAuthorization()
        Logger.log(
            "Location authorization status: \(locationManager.authorizationStatus.rawValue)"
        )
    }
}

// Add CustomStringConvertible conformance to WeatherData for better logging
extension WeatherData: CustomStringConvertible {
    public var description: String {
        return """
            Temperature: \(temperature)°C, 
            Feels Like: \(feelsLike)°C, 
            Condition: \(condition), 
            Humidity: \(humidity * 100)%, 
            Wind Speed: \(windSpeed) km/h
            """
    }
}