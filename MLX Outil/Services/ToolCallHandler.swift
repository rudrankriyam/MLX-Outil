import Foundation

class ToolCallHandler {
    private let healthManager: HealthKitManager
    private let weatherManager: WeatherKitManager
    private var toolCallBuffer: String = ""

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
        guard let data = jsonString.data(using: .utf8),
            let toolCall = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let name = toolCall["name"] as? String
        else {
            throw ToolCallError.invalidJSON
        }

        switch name {
        case "get_workout_summary":
            return try await fetchWorkoutData()
        case "get_weather_data":
            guard let arguments = toolCall["arguments"] as? [String: Any],
                let city = arguments["city"] as? String
            else {
                throw ToolCallError.invalidArguments
            }
            return try await fetchWeatherData(for: city)
        default:
            throw ToolCallError.unknownTool(name)
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

    private func fetchWeatherData(for city: String) async throws -> String {
        let weather = try await weatherManager.fetchWeather(forCity: city)
        return OutputFormatter.formatWeatherData(weather)
    }
}

enum ToolCallError: Error {
    case invalidJSON
    case invalidArguments
    case unknownTool(String)
}
