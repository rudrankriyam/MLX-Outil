import MLXLLM
import MLXLMCommon
import SwiftUI

public typealias OutilMessage = [[String: String]]

public protocol CoreModelContainer
where Self: Sendable, Self: Observable {
    typealias ContainerResult = MLXLMCommon.GenerateResult
    typealias Tool = [String: any Sendable]
    typealias OnProgress = @Sendable (String) -> Void

    var onProgress: String { get }

    func generate(
        messages: [[String: String]],
        tools: [Tool]?,
        onProgress: @escaping OnProgress
    ) async throws -> ContainerResult
}

public struct CoreModelService: Sendable {
    public init() {}

    public func provideModelContainer() -> any CoreModelContainer {
        ConcreteModelContainer(
            modelConfiguration: ModelRegistry.llama3_2_3B_4bit,
            generateParameters: GenerateParameters(temperature: 0.5)
        )
    }
}
