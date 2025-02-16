import Foundation

enum ToolCallType: String, Codable {
  case getWorkoutSummary = "get_workout_summary"
  case getWeatherData = "get_weather_data"
  case searchDuckDuckGo = "search_duckduckgo"
}

struct ToolCall: Codable {
  let name: ToolCallType
  let arguments: Arguments

  enum Arguments: Codable {
    case workout
    case weather(WeatherArguments)
    case search(SearchArguments)

    enum CodingKeys: String, CodingKey {
      case location
      case query
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)

      if let location = try? container.decode(String.self, forKey: .location) {
        self = .weather(WeatherArguments(location: location))
      } else if let query = try? container.decode(String.self, forKey: .query) {
        self = .search(SearchArguments(query: query))
      } else {
        self = .workout
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .workout:
        break
      case .weather(let args):
        try container.encode(args.location, forKey: .location)
      case .search(let args):
        try container.encode(args.query, forKey: .query)
      }
    }
  }
}

struct WeatherArguments: Codable {
  let location: String
}

struct SearchArguments: Codable {
  let query: String
}

class ToolCallHandler {
  private let healthManager: HealthKitManager
  private let weatherManager: WeatherKitManager
  private let searchManager = DuckDuckGoManager.shared
  private let loadingManager = LoadingManager.shared
  private var toolCallBuffer: String = ""
  private var isCollectingToolCall = false
  private let decoder = JSONDecoder()

  init(healthManager: HealthKitManager, weatherManager: WeatherKitManager) {
    self.healthManager = healthManager
    self.weatherManager = weatherManager
  }

  func processLLMOutput(_ text: String) async throws -> String? {
    var tokenText = text
    if tokenText.hasPrefix("<tool_call>") {
      tokenText = tokenText.replacingOccurrences(
        of: "<tool_call>", with: "")
    }

    toolCallBuffer += tokenText

    if toolCallBuffer.contains("</tool_call>") {
      toolCallBuffer = toolCallBuffer.replacingOccurrences(
        of: "</tool_call>", with: "")
      let jsonString = toolCallBuffer.trimmingCharacters(
        in: .whitespacesAndNewlines)

      let result = try await handleToolCall(jsonString)
      toolCallBuffer = ""
      return result
    }
    return nil
  }

  private func handleToolCall(_ jsonString: String) async throws -> String {
    guard let data = jsonString.data(using: .utf8) else {
      throw ToolCallError.invalidJSON
    }

    let toolCall = try decoder.decode(ToolCall.self, from: data)

    switch (toolCall.name, toolCall.arguments) {
    case (.getWorkoutSummary, .workout):
      return try await fetchWorkoutData()

    case (.getWeatherData, .weather(let args)):
      return try await fetchWeatherData(for: args.location)

    case (.searchDuckDuckGo, .search(let args)):
      return try await performSearch(for: args.query)

    default:
      throw ToolCallError.invalidArguments
    }
  }

  private func fetchWorkoutData() async throws -> String {
    let workouts = try await healthManager.fetchWorkouts(for: .week(Date()))
    if workouts.isEmpty {
      return "No workouts found for this week."
    }
    return OutputFormatter.formatWeeklyWorkoutSummary(
      workouts, using: healthManager)
  }

  private func fetchWeatherData(for location: String) async throws -> String {
    loadingManager.startLoading(
      message: "Fetching weather data for \(location)...")

    do {
      let weather = try await weatherManager.fetchWeather(
        forCity: location)
      loadingManager.stopLoading()
      return OutputFormatter.formatWeatherData(weather)
    } catch {
      loadingManager.stopLoading()
      throw error
    }
  }

  private func performSearch(for query: String) async throws -> String {
    loadingManager.startLoading(
      message: "Searching DuckDuckGo for \(query)...")

    do {
      let results = try await searchManager.search(query: query)
      loadingManager.stopLoading()
      return results
    } catch {
      loadingManager.stopLoading()
      throw error
    }
  }
}

enum ToolCallError: Error {
  case invalidJSON
  case invalidArguments
  case unknownTool(String)
}
