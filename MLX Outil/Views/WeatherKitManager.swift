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
    }
    
    // Fetch weather for a specific city
    func fetchWeather(forCity city: String) async throws -> WeatherData {
        // First, try to get coordinates for the city
        let coordinates = try await getCoordinates(for: city)
        
        // Then fetch weather using these coordinates
        return try await fetchWeather(for: coordinates)
    }
    
    private func getCoordinates(for city: String) async throws -> CLLocation {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(city)
        
        guard let location = placemarks.first?.location else {
            throw WeatherKitError.locationNotFound
        }
        
        return location
    }
    
    // Fetch weather for current location
    func fetchWeatherForCurrentLocation() async throws -> WeatherData {
        guard let location = locationManager.location else {
            throw WeatherKitError.locationNotFound
        }
        
        return try await fetchWeather(for: location)
    }
    
    private func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        do {
            let weather = try await weatherService.weather(for: location)
            
            return WeatherData(
                temperature: weather.currentWeather.temperature.value,
                condition: weather.currentWeather.condition.description,
                humidity: weather.currentWeather.humidity,
                windSpeed: weather.currentWeather.wind.speed.value
            )
        } catch {
            throw WeatherKitError.weatherDataUnavailable
        }
    }
    
    // Setup location manager
    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
}
