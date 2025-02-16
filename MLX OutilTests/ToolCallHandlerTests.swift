import HealthKit
import XCTest

@testable import MLX_Outil

final class ToolCallHandlerTests: XCTestCase {
    var toolCallHandler: ToolCallHandler!
    fileprivate var mockHealthManager: MockHealthKitManager!
    fileprivate var mockWeatherManager: MockWeatherKitManager!

    override func setUp() {
        super.setUp()
        mockHealthManager = MockHealthKitManager(isAuthorized: true)
        mockWeatherManager = MockWeatherKitManager(isAuthorized: true)
        toolCallHandler = ToolCallHandler(
            healthManager: mockHealthManager,
            weatherManager: mockWeatherManager
        )
    }

    override func tearDown() {
        toolCallHandler = nil
        mockHealthManager = nil
        mockWeatherManager = nil
        super.tearDown()
    }

    func testValidWeatherToolCall() async throws {
        // Given
        let validToolCall = """
            {
                "name": "get_weather_data",
                "arguments": {
                    "location": "New York, NY"
                }
            }
            """

        mockWeatherManager.mockWeatherData = WeatherKitManager.WeatherData(
            temperature: 20.0,
            condition: "Sunny",
            humidity: 0.45,
            windSpeed: 10.0,
            feelsLike: 22.0,
            uvIndex: 5,
            visibility: 10000,
            pressure: 1013,
            precipitationChance: 0.1
        )

        // When
        let result = try await toolCallHandler.processLLMOutput(
            "<tool_call>\(validToolCall)</tool_call>")

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("Current Weather:") ?? false)
        XCTAssertTrue(result?.contains("Temperature: 20.0°C") ?? false)
        XCTAssertTrue(result?.contains("Condition: Sunny") ?? false)
        XCTAssertTrue(result?.contains("Humidity: 45%") ?? false)
        XCTAssertTrue(result?.contains("Wind Speed: 10.0 km/h") ?? false)
    }

    func testInvalidJSON() async {
        // Given
        let invalidJSON = "<tool_call>{invalid json}</tool_call>"

        // When/Then
        do {
            _ = try await toolCallHandler.processLLMOutput(invalidJSON)
            XCTFail("Expected error for invalid JSON")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testPartialToolCall() async throws {
        // Given
        let partialToolCall = "<tool_call>{\"name\": \"get_weather_data\""

        // When
        let result = try await toolCallHandler.processLLMOutput(partialToolCall)

        // Then
        XCTAssertNil(result, "Partial tool call should return nil")
    }

    func testInvalidToolName() async {
        // Given
        let invalidToolCall = """
            {
                "name": "invalid_tool",
                "arguments": {
                    "location": "New York"
                }
            }
            """

        // When/Then
        do {
            _ = try await toolCallHandler.processLLMOutput(
                "<tool_call>\(invalidToolCall)</tool_call>")
            XCTFail("Expected error for invalid tool name")
        } catch let decodingError as DecodingError {
            // The ToolCallType enum will fail to decode with an invalid name
            switch decodingError {
            case .dataCorrupted, .typeMismatch:
                // Test passes as we expect a decoding error for invalid enum case
                break
            default:
                XCTFail(
                    "Expected decoding error for invalid tool name but got \(decodingError)"
                )
            }
        } catch {
            XCTFail("Expected DecodingError but got \(error)")
        }
    }
}

// MARK: - Mock Classes
private class MockHealthKitManager: HealthKitManager {
    var isAuthorized: Bool

    init(isAuthorized: Bool) {
        self.isAuthorized = isAuthorized
        super.init()
    }

    override func requestAuthorization() async throws {}

    func fetchWorkouts(for dateRange: ClosedRange<Date>) async throws
        -> [HKWorkout]
    {
        return []
    }
}

private class MockWeatherKitManager: WeatherKitManager {
    var mockWeatherData: WeatherData?
    var isAuthorized: Bool

    init(isAuthorized: Bool) {
        self.isAuthorized = isAuthorized
    }

    override func fetchWeather(forCity location: String) async throws
        -> WeatherData
    {
        guard let mockWeatherData else {
            throw WeatherKitError.locationNotFound
        }
        return mockWeatherData
    }
}
