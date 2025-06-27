import XCTest
@testable import MLXTools

final class MLXToolsTests: XCTestCase {
    
    func testWeatherDataEquatable() {
        let weather1 = WeatherData(
            temperature: 20.0,
            condition: "Sunny",
            humidity: 0.5,
            windSpeed: 10.0,
            feelsLike: 18.0,
            uvIndex: 5,
            visibility: 10000,
            pressure: 1013,
            precipitationChance: 0.1
        )
        
        let weather2 = WeatherData(
            temperature: 20.0,
            condition: "Sunny",
            humidity: 0.5,
            windSpeed: 10.0,
            feelsLike: 18.0,
            uvIndex: 5,
            visibility: 10000,
            pressure: 1013,
            precipitationChance: 0.1
        )
        
        XCTAssertEqual(weather1, weather2)
    }
    
    func testToolInputTypes() {
        let weatherInput = WeatherInput(location: "New York, NY")
        XCTAssertEqual(weatherInput.location, "New York, NY")
        
        let searchInput = SearchInput(query: "Swift programming")
        XCTAssertEqual(searchInput.query, "Swift programming")
        
        let _ = EmptyInput() // Just verify it can be created
    }
    
    func testToolOutputTypes() {
        let workoutOutput = WorkoutOutput(summary: "Test workout summary")
        XCTAssertEqual(workoutOutput.summary, "Test workout summary")
        
        let searchOutput = SearchOutput(results: "Test search results")
        XCTAssertEqual(searchOutput.results, "Test search results")
    }
    
    @MainActor
    func testFormatDuration() {
        let duration: TimeInterval = 3661 // 1 hour, 1 minute, 1 second
        let formatted = OutputFormatter.formatDuration(duration)
        XCTAssertTrue(formatted.contains("1"))
        XCTAssertTrue(formatted.contains("h") || formatted.contains("hr"))
    }
    
    @MainActor
    func testFormatDistance() {
        let distance: Double = 5432.1 // meters
        let formatted = OutputFormatter.formatDistance(distance)
        XCTAssertEqual(formatted, "5.43 km")
    }
}