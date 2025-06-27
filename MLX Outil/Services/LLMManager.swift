import HealthKit
import SwiftUI
import MLXLMCommon
import MLXLLM
import MLX

@MainActor
@Observable
class LLMManager {

    var running = false
    var output = ""
    var modelInfo = ""
    var stat = ""

    var toolCallState: ToolCallParsingState = .idle

    private let toolCallHandler: ToolCallHandler

    init() {
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

    private let modelConfiguration = LLMRegistry.qwen3_1_7b_4bit

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
                "description":
                    "Get current weather data for a specific location",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "location": [
                            "type": "string",
                            "description":
                                "The city and state, e.g. New Delhi, Delhi",
                        ]
                    ],
                    "required": ["location"],
                ],
            ],
        ],
        [
            "type": "function",
            "function": [
                "name": "search_duckduckgo",
                "description": "Search DuckDuckGo for information on a topic",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "The search query to look up",
                        ]
                    ],
                    "required": ["query"],
                ],
            ],
        ],
    ]

    func generate(prompt: String, includingTools: Bool = true) async {
        guard !running else { return }

        running = true
        self.output = ""

        do {
            let messages: [Chat.Message] = [
                .system(Constants.systemPrompt),
                .user(prompt)
            ]

            let userInput = UserInput(
                chat: messages,
                tools: [weatherTool.schema]
            )

            do {
                let modelContainer = try await load()

                // each time you generate you will get something new
                MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

                try await modelContainer.perform { (context: ModelContext) -> Void in
                    let lmInput = try await context.processor.prepare(input: userInput)
                    let stream = try MLXLMCommon.generate(
                        input: lmInput, parameters: .init(), context: context)

                    for await batch in stream {
                        if await !output.isEmpty {
                            Task { @MainActor [batch] in
                                self.output += batch.chunk ?? ""
                            }
                        }
                    }
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

        func load() async throws -> ModelContainer {
            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration) { _ in }

            return modelContainer
        }
    }
}

public struct WeatherInput: Codable, Sendable {
    let location: String
}

struct WeatherResponse: Codable, Sendable {
    let content: String
}

public let weatherTool = Tool<WeatherInput, WeatherData>(
    name: "get_weather_data",
    description: "Gets weather data for a specified location",
    parameters: [
        .required(
            "location", type: .string, description: "The city and state, e.g. New Delhi, Delhi"
        ),
    ]
) { input in
    let weatherService = WeatherKitManager()
    let response = try await weatherService.fetchWeather(forCity: input.location)
    return response
}
