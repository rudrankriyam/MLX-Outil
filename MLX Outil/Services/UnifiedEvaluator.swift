import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Metal
import Tokenizers
import WeatherKit
import CoreLocation
import HealthKit

@MainActor
class UnifiedEvaluator: ObservableObject {

    @Published var running = false
    @Published var output = ""
    var modelInfo = ""
    var stat = ""

    var toolCallState: ToolCallParsingState = .idle
    var loadState = LoadState.idle

    private let modelService: ModelService
    private let toolCallHandler: ToolCallHandler
    
    init() {
        self.modelService = ModelService(
            modelConfiguration: ModelRegistry.qwen2_5_1_5b,
            generateParameters: GenerateParameters(temperature: 0.5)
        )
        self.toolCallHandler = ToolCallHandler(
            healthManager: HealthKitManager.shared,
            weatherManager: WeatherKitManager.shared
        )
    }

    // Health-specific properties
    private let healthManager = HealthKitManager.shared

    // Weather-specific properties
    private let weatherManager = WeatherKitManager.shared

    private var toolCallBuffer: String = ""

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    static let availableTools: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "get_workout_summary",
                "description": "Get a summary of workouts for this week",
                "parameters": [
                    "type": "object",
                    "properties": [:],
                    "required": [],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "get_weather_data",
                "description": "Get current weather data for a specific city",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "city": [
                            "type": "string",
                            "description": "The name of the city"
                        ]
                    ],
                    "required": ["city"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    ]

    // Call this method with every incoming token.
    func processLLMOutput(_ text: String) async {
        // Remove any leading <tool_call> marker from the incoming token.
        var tokenText = text
        if tokenText.hasPrefix("<tool_call>") {
            tokenText = tokenText.replacingOccurrences(of: "<tool_call>", with: "")
        }

        // Append the cleaned token to the buffer.
        toolCallBuffer += tokenText

        // Check if the buffer now contains the closing tag.
        if toolCallBuffer.contains("</tool_call>") {
            // Remove the closing tag.
            toolCallBuffer = toolCallBuffer.replacingOccurrences(of: "</tool_call>", with: "")

            // The buffer should now contain the complete JSON.
            let jsonString = toolCallBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Final JSON String: \(jsonString)")

            // Process the complete JSON.
            await handleToolCall(jsonString)

            // Clear the buffer for the next tool call.
            toolCallBuffer = ""
        }
    }

    @MainActor
    func handleToolCall(_ jsonString: String) async {
        guard let data = jsonString.data(using: .utf8) else {
            print("Failed to create data from JSON string")
            return
        }

        do {
            // Parse the JSON into a dictionary.
            if let toolCall = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = toolCall["name"] as? String {
                print("Successfully parsed tool call with name: \(name)")
                switch name {
                case "get_workout_summary":
                    let workoutSummary = try await fetchWorkoutData()
                    await continueConversation(with: workoutSummary, for: "Workout Summary")
                case "get_weather_data":
                    if let arguments = toolCall["arguments"] as? [String: Any],
                       let city = arguments["city"] as? String {
                        let weatherData = try await fetchWeatherData(for: city)
                        await continueConversation(with: weatherData, for: city)
                    }
                default:
                    print("Unknown tool call: \(name)")
                }
            }
        } catch {
            print("Error parsing tool call JSON: \(error)")
            self.output += "\nError parsing tool call: \(error.localizedDescription)\n"
        }
    }

    func fetchWorkoutData() async throws -> String {
        let workouts = try await healthManager.fetchWorkouts(for: .week(Date()))
        if workouts.isEmpty {
            return "No workouts found for this week."
        }
        return formatWeeklyWorkoutSummary(workouts)
    }

    func fetchWeatherData(for city: String) async throws -> String {
        do {
            let weather = try await weatherManager.fetchWeather(forCity: city)
            return OutputFormatter.formatWeatherData(weather)
        } catch {
            return "Unable to fetch weather data for \(city). Please try again."
        }
    }

    private func formatWeeklyWorkoutSummary(_ workouts: [HKWorkout]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"

        var workoutsByDay: [String: [HKWorkout]] = [:]
        for workout in workouts {
            let dayName = dateFormatter.string(from: workout.startDate)
            workoutsByDay[dayName, default: []].append(workout)
        }

        let calendar = Calendar.current
        let sortedDays = workoutsByDay.keys.sorted { day1, day2 in
            let index1 = calendar.component(
                .weekday, from: dateFormatter.date(from: day1) ?? Date())
            let index2 = calendar.component(
                .weekday, from: dateFormatter.date(from: day2) ?? Date())
            return index1 < index2
        }

        var summary = "Workout Summary for this week:"
        for day in sortedDays {
            summary += "\n\n📅 \(day):"
            for workout in workoutsByDay[day] ?? [] {
                let metrics = healthManager.getWorkoutMetrics(workout)
                summary +=
                "\n- \(OutputFormatter.formatDuration(metrics.duration)), \(Int(metrics.calories)) kcal, \(OutputFormatter.formatDistance(metrics.distance))"
            }
        }

        return summary
    }

    func generate(prompt: String, includingTools: Bool = true) async {
        guard !running else { return }

        running = true
        self.output = ""

        print("Generating with prompt: \(prompt)")

        do {
            let modelContainer = try await modelService.load()

            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let result = try await modelContainer.perform { context in
                let messages = [
                    ["role": "system", "content": Constants.systemPrompt],
                    ["role": "user", "content": prompt],
                ]

                let input = try await context.processor.prepare(
                    input: .init(
                        messages: messages,
                        tools: includingTools ? Self.availableTools : nil
                    )
                )

                return try MLXLMCommon.generate(
                    input: input, parameters: GenerateParameters(temperature: 0.5),
                    context: context
                ) { tokens in
                    if tokens.count % 2 == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            if includingTools {
                                print("Text: \(text)")
                            } else {
                                self.output = text
                            }
                        }
                    }
                    return .more
                }
            }
            print("Generated: \(result.output)")
            if includingTools {
                await processLLMOutput(result.output)
            }
        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }

    func continueConversation(with data: String, for context: String) async {
        let followUpPrompt = "The \(context) data is: \(data). Now you are an expert. Please explain the data and provide recommendations based on this information."
        running = false
        await generate(prompt: followUpPrompt, includingTools: false)
    }
}
