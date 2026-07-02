import XCTest
@testable import MLXTools

final class WeatherDataTests: XCTestCase {
  @MainActor
  func testWeatherFormatterCapsPrecipitationChanceAtOneHundredPercent() {
    let weather = WeatherData(
      temperature: 18.0,
      condition: "Rain",
      humidity: 0.82,
      windSpeed: 12.0,
      feelsLike: 16.5,
      uvIndex: 1,
      visibility: 8_000,
      pressure: 1_011,
      precipitationChance: 2.5
    )

    let output = OutputFormatter.formatWeatherData(weather)

    XCTAssertTrue(output.contains("Precipitation Chance:"))
    XCTAssertFalse(output.contains("250%"))
  }

  func testWeatherDataAcceptsPercentageStylePrecipitationValues() {
    let weather = WeatherData(
      temperature: 20.0,
      condition: "Cloudy",
      humidity: 0.5,
      windSpeed: 4.0,
      feelsLike: 20.0,
      uvIndex: 2,
      visibility: 10_000,
      pressure: 1_018,
      precipitationChance: 25.0
    )

    XCTAssertEqual(weather.precipitationChance, 0.25)
    XCTAssertEqual(WeatherData.normalizedProbability(2.5), 0.025, accuracy: 0.0001)
  }

  func testOpenMeteoPercentageProbabilityUsesPercentScale() {
    XCTAssertEqual(
      WeatherData.normalizedPercentageProbability(1.0),
      0.01,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      WeatherData.normalizedPercentageProbability(250.0),
      1.0,
      accuracy: 0.0001
    )
  }
}
