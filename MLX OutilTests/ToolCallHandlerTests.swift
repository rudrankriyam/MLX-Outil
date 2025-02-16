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

    // MARK: - Weather Tool Call Tests

    func testValidWeatherToolCall() async throws {
        // Given
        let validToolCall = makeWeatherToolCall(location: "New York, NY")
        let mockWeather = WeatherKitManager.WeatherData(
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
        mockWeatherManager.mockWeatherData = mockWeather

        // When
        let result = try await toolCallHandler.processLLMOutput(
            "<tool_call>\(validToolCall)</tool_call>")

        // Then
        XCTAssertNotNil(result)
        let expectedStrings = [
            "Current Weather:",
            "Temperature: 20.0°C",
            "Condition: Sunny",
            "Humidity: 45%",
            "Wind Speed: 10.0 km/h"
        ]
        assertResultContains(result, expectedStrings)
    }

    func testWeatherToolCallWithEmptyLocation() async {
        // Given
        let invalidToolCall = makeWeatherToolCall(location: "")

        // When/Then
        await assertThrowsError(
            try await toolCallHandler.processLLMOutput(
                "<tool_call>\(invalidToolCall)</tool_call>"),
            WeatherKitError.locationNotFound
        )
    }

    // MARK: - Error Cases

    func testInvalidJSON() async {
        // Given
        let invalidJSON = "<tool_call>{invalid json}</tool_call>"

        // When/Then
        await assertThrowsError(
            try await toolCallHandler.processLLMOutput(invalidJSON)
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testPartialToolCall() async throws {
        // Given
        let partialCalls = [
            "<tool_call>",
            "<tool_call>{\"name\": \"get_weather_data\"",
            "<tool_call>{\"name\": \"get_weather_data\", \"arguments\": {"
        ]

        // When/Then
        for call in partialCalls {
            let result = try await toolCallHandler.processLLMOutput(call)
            XCTAssertNil(result, "Partial tool call should return nil: \(call)")
        }
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
        await assertThrowsError(
            try await toolCallHandler.processLLMOutput(
                "<tool_call>\(invalidToolCall)</tool_call>")
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Helper Methods

    private func makeWeatherToolCall(location: String) -> String {
        return """
            {
                "name": "get_weather_data",
                "arguments": {
                    "location": "\(location)"
                }
            }
            """
    }

    private func makeWorkoutToolCall() -> String {
        return """
            {
                "name": "get_workout_summary",
                "arguments": {}
            }
            """
    }

    private func assertResultContains(_ result: String?, _ expectedStrings: [String]) {
        guard let result else {
            XCTFail("Result should not be nil")
            return
        }

        for expected in expectedStrings {
            XCTAssertTrue(
                result.contains(expected),
                "Result should contain '\(expected)' but got: \(result)"
            )
        }
    }

    private func assertThrowsError<T>(_ expression: @autoclosure () async throws -> T,
                                     _ expectedError: Error? = nil,
                                     file: StaticString = #file,
                                     line: UInt = #line,
                                     _ errorHandler: ((Error) -> Void)? = nil) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but no error was thrown", file: file, line: line)
        } catch {
            if let expectedError = expectedError {
                XCTAssertEqual(
                    error as? WeatherKitError,
                    expectedError as? WeatherKitError,
                    file: file,
                    line: line
                )
            }
            errorHandler?(error)
        }
    }

    private func createMockWorkout(duration: TimeInterval,
                                 distance: Double,
                                 energyBurned: Double,
                                 workoutType: HKWorkoutActivityType) -> HKWorkout {
        return HKWorkout(
            activityType: workoutType,
            start: Date(),
            end: Date().addingTimeInterval(duration),
            duration: duration,
            totalEnergyBurned: HKQuantity(
                unit: .kilocalorie(),
                doubleValue: energyBurned
            ),
            totalDistance: HKQuantity(
                unit: .meter(),
                doubleValue: distance
            ),
            metadata: nil
        )
    }
}

// MARK: - Mock Classes
private class MockHealthKitManager: HealthKitManager {
    var isAuthorized: Bool
    var mockWorkouts: [HKWorkout] = []

    init(isAuthorized: Bool) {
        self.isAuthorized = isAuthorized
        super.init()
    }

    override func requestAuthorization() async throws {
        if !isAuthorized {
            throw NSError(
                domain: "com.apple.healthkit",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Authorization not determined"]
            )
        }
    }

    func fetchWorkouts(for timeRange: ClosedRange<Date>) async throws -> [HKWorkout] {
        try await requestAuthorization()
        return mockWorkouts
    }
}

private class MockWeatherKitManager: WeatherKitManager {
    var mockWeatherData: WeatherData?
    var isAuthorized: Bool

    init(isAuthorized: Bool) {
        self.isAuthorized = isAuthorized
    }

    override func fetchWeather(forCity location: String) async throws -> WeatherData {
        if location.isEmpty {
            throw WeatherKitError.locationNotFound
        }
        guard let mockWeatherData else {
            throw WeatherKitError.locationNotFound
        }
        return mockWeatherData
    }
}
