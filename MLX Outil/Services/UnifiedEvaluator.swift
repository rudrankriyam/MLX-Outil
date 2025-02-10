import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Foundation
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

    static let availableTools: [[String: any Sendable]] = [
        [
            "type": "function",
            "function": [
                "name": "get_workout_summary",
                "description": "Get a summary of workouts for this week",
                "parameters": [
                    "type": "object",
                    "properties": [:],
                    "required": [],
                ],
            ],
        ],
        [
            "type": "function",
            "function": [
                "name": "get_weather_data",
                "description": "Get current weather data for a specific location",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "location": [
                            "type": "string",
                            "description": "The city and state, e.g. New Delhi, Delhi",
                        ]
                    ],
                    "required": ["location"],
                ],
            ],
        ],
    ]

    func fetchWorkoutData() async throws -> String {
        let workouts = try await healthManager.fetchWorkouts(for: .week(Date()))
        if workouts.isEmpty {
            return "No workouts found for this week."
        }
        return OutputFormatter.formatWeeklyWorkoutSummary(workouts, using: .shared)
    }

    func fetchWeatherData(for location: String) async throws -> String {
        do {
            let weather = try await weatherManager.fetchWeather(forCity: location)
            return OutputFormatter.formatWeatherData(weather)
        } catch {
            return "Unable to fetch weather data for \(location). Please try again."
        }
    }

    func generate(prompt: String, includingTools: Bool = true) async {
        guard !running else { return }

        running = true
        self.output = ""

        do {
            let messages: [[String: String]] = [
                ["role": "system", "content": Constants.systemPrompt],
                ["role": "user", "content": prompt],
            ]

            let result = try await modelService.generate(
                messages: messages,
                tools: includingTools ? Self.availableTools : nil
            ) { [weak self] text in
                if includingTools {
                    print("Text: \(text)")
                } else {
                    self?.output = text
                }
            }

            if includingTools,
                let data = try await toolCallHandler.processLLMOutput(
                    result.output)
            {
                await continueConversation(with: data, for: data)
            }
        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }

    func continueConversation(with data: String, for context: String) async {
        let followUpPrompt =
            "The \(context) data is: \(data). Now you are an expert. Please explain the data and provide recommendations based on this information."
        running = false
        await generate(prompt: followUpPrompt, includingTools: false)
    }
}
