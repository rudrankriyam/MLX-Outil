import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom

@MainActor
class ModelService {
    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    private var loadState = LoadState.idle
    private let modelConfiguration: ModelConfiguration
    private let generateParameters: GenerateParameters

    init(
        modelConfiguration: ModelConfiguration,
        generateParameters: GenerateParameters
    ) {
        self.modelConfiguration = modelConfiguration
        self.generateParameters = generateParameters
    }

    func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { [modelConfiguration] progress in
                Task { @MainActor in
                    print(
                        "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                    )
                }
            }
            let numParams = await modelContainer.perform { context in
                context.model.numParameters()
            }

            print(
                "Loaded \(modelConfiguration.id). Weights: \(numParams / (1024*1024))M"
            )
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    func generate(
        messages: [[String: String]],
        tools: [[String: any Sendable]]? = nil,
        onTokens: @escaping (String) -> Void
    ) async throws -> MLXLMCommon.GenerateResult {
        let modelContainer = try await load()

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        return try await modelContainer.perform { context in
            let input = try await context.processor.prepare(
                input: .init(messages: messages, tools: tools)
            )

            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParameters,
                context: context
            ) { tokens in
                if tokens.count % 2 == 0 {
                    let text = context.tokenizer.decode(tokens: tokens)
                    Task { @MainActor in
                        onTokens(text)
                    }
                }
                return .more
            }
        }
    }
}
