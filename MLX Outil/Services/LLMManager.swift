import HealthKit
import MLXModelService
import SwiftUI

@MainActor
@Observable
class LLMManager {

    var running = false
    var output = ""
    var modelInfo = ""
    var stat = ""

    var toolCallState: ToolCallParsingState = .idle

    private let modelService: CoreModelContainer
    private let toolCallHandler: ToolCallHandler

    init() {
        let modelService = CoreModelService()
        self.modelService = modelService.provideModelContainer()

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
            let messages: OutilMessage = [
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
                    Task { @MainActor in
                        self?.output = text
                    }
                }
            }

            if includingTools {
                let data = try await toolCallHandler.processLLMOutput(
                    result.output)
                await continueConversation(with: data, for: prompt)
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
