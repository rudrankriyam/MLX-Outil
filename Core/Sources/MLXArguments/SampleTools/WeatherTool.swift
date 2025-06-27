import Foundation

/// Weather tool type
public enum WeatherToolType: String, ToolCallTypeProtocol, Sendable {
    case getWeatherData = "get_weather_data"
    
    public var displayName: String {
        switch self {
        case .getWeatherData:
            return "Get Weather Data"
        }
    }
    
    public var description: String {
        switch self {
        case .getWeatherData:
            return "Gets weather data for a specified location"
        }
    }
}



/// Arguments for weather tools
public struct WeatherArguments: ArgumentProtocol {
    public typealias ToolType = WeatherToolType
    
    public let toolType: WeatherToolType
    public let location: String
    
    public init(toolType: WeatherToolType = .getWeatherData, location: String) {
        self.toolType = toolType
        self.location = location
    }
}

/// Protocol for weather services
public protocol WeatherServiceProtocol: Sendable {
    func fetchWeather(for location: String) async throws -> String
}

/// Weather tool handler
public final class WeatherToolHandler: ToolRegistry.ToolHandlerProtocol {
    private let weatherService: any WeatherServiceProtocol
    
    public init(weatherService: any WeatherServiceProtocol) {
        self.weatherService = weatherService
    }
    
    public func handle(json: Data) async throws -> String {
        let decoder = JSONDecoder()
        let arguments = try decoder.decode(WeatherArguments.self, from: json)
        
        return try await weatherService.fetchWeather(for: arguments.location)
    }
}
