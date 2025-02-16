import MarkdownUI
import SwiftUI

struct SearchView: View {
  @Environment(LLMManager.self) private var evaluator
  @StateObject private var loadingManager = LoadingManager.shared
  @State private var prompt = "What is the capital of France?"

  #if os(macOS)
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    private let secondaryBackground = Color(NSColor.controlBackgroundColor)
  #else
    private let backgroundColor = Color(.systemBackground)
    private let secondaryBackground = Color(.secondarySystemBackground)
  #endif
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
      .navigationTitle("Search")
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
        "Ask anything you want to search...",
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
        Image(
          systemName: evaluator.running
            ? "stop.circle.fill" : "arrow.up.circle.fill"
        )
        .resizable()
        .frame(width: 30, height: 30)
        .foregroundColor(evaluator.running ? .red : accentColor)
      }
      .disabled(
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      )
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
      await evaluator.generate(prompt: prompt)
    }
  }
}
