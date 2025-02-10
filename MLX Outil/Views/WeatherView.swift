import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon
import MarkdownUI

struct WeatherView: View {
    @Environment(UnifiedEvaluator.self) private var evaluator
  @StateObject private var loadingManager = LoadingManager.shared
  @State private var prompt = "How's the weather today in Gurgaon and what should I wear?"

  private let backgroundColor = Color(.systemBackground)
  private let secondaryBackground = Color(.secondarySystemBackground)
  private let accentColor = Color.accentColor

  var body: some View {
    NavigationStack {
      ZStack {
        VStack(alignment: .leading, spacing: 16) {
          outputView
          promptInputView
        }

        if loadingManager.isLoading {
          LoadingView()
        }
      }
      #if os(visionOS)
        .padding(40)
      #else
        .padding()
      #endif
      .navigationTitle("Weather")
      .background(backgroundColor)
    }
  }

  private var outputView: some View {
    ScrollView(.vertical) {
      ScrollViewReader { sp in
        Group {
          Markdown(evaluator.output)
            .textSelection(.enabled)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(secondaryBackground)
            .cornerRadius(12)
        }
        .onChange(of: evaluator.output) { _, _ in
          sp.scrollTo("bottom")
        }

        Spacer()
          .frame(width: 1, height: 1)
          .id("bottom")
      }
    }
    .background(backgroundColor)
  }

  private var promptInputView: some View {
    HStack(spacing: 12) {
      TextField(
        "Ask about weather and clothing suggestions...",
        text: $prompt,
        axis: .vertical
      )
      .lineLimit(1...4)
      .textFieldStyle(.plain)
      .onSubmit(generate)
      .disabled(evaluator.running)
      #if os(visionOS)
        .textFieldStyle(.roundedBorder)
      #endif

      Button(action: generate) {
        Image(systemName: evaluator.running ? "stop.circle.fill" : "arrow.up.circle.fill")
          .resizable()
          .frame(width: 30, height: 30)
          .foregroundColor(evaluator.running ? .red : accentColor)
      }
      .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .animation(.easeInOut, value: evaluator.running)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(secondaryBackground)
    .cornerRadius(16)
    .padding(.horizontal)
  }

  private func generate() {
    Task {
      loadingManager.startLoading(message: "Checking weather conditions...")
      await evaluator.generate(prompt: prompt)
      loadingManager.stopLoading()
    }
  }
}
