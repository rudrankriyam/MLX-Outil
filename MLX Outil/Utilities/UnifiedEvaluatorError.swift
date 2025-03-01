import Foundation

enum UnifiedEvaluatorError: LocalizedError {
    case toolCallParsingFailed(String)
    case invalidToolCall(String)

    var errorDescription: String? {
        switch self {
        case .toolCallParsingFailed(let reason):
            return "Failed to parse tool call: \(reason)"
        case .invalidToolCall(let name):
            return "Invalid tool call: \(name)"
        }
    }
}
