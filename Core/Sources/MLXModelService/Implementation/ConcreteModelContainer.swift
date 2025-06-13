import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

final class ConcreteModelContainer: CoreModelContainer, @unchecked Sendable {
    private var lock = NSLock()
    private(set) var onProgress: String = ""
    private let modelConfiguration: ModelConfiguration
    private let generateParameters: GenerateParameters

    init(
        modelConfiguration: ModelConfiguration,
        generateParameters: GenerateParameters
    ) {
        self.modelConfiguration = modelConfiguration
        self.generateParameters = generateParameters
    }

    func generate(
        messages: OutilMessage,
        tools: [Tool]?,
        onProgress: @escaping OnProgress
    ) async throws -> ContainerResult {
        let context = try await loadModel(configuration: modelConfiguration)

        let input = try await context.processor.prepare(
            input: .init(messages: messages, tools: tools)
        )

        return try MLXLMCommon.generate(
            input: input,
            parameters: generateParameters,
            context: context
        ) { [unowned self] tokens in
            if tokens.count % 1 == 0 {
                self.lock.lock()
                defer { self.lock.unlock() }
                let text = context.tokenizer.decode(tokens: tokens)
                Task { @MainActor in
                    onProgress(text)
                }
            }
            return .more
        }
    }
}
