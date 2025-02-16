import SwiftUI

struct LoadingView: View {
    @StateObject private var loadingManager = LoadingManager.shared

    var body: some View {
        if loadingManager.isLoading {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    ShimmerView()
                        .frame(height: 24)

                    ShimmerView()
                        .frame(height: 100)

                    HStack(spacing: 12) {
                        ShimmerView()
                            .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 8) {
                            ShimmerView()
                                .frame(height: 20)
                                .frame(width: 120)

                            ShimmerView()
                                .frame(height: 20)
                                .frame(width: 80)
                        }
                    }
                }
                .padding(.horizontal)

                Text(loadingManager.loadingMessage)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .frame(maxWidth: 300)
            .padding(.vertical)
        }
    }
}

class LoadingManager: ObservableObject {
    static let shared = LoadingManager()

    @Published var isLoading = false
    @Published var loadingMessage = ""

    private init() {}

    func startLoading(message: String = "Loading...") {
        DispatchQueue.main.async {
            self.loadingMessage = message
            self.isLoading = true
        }
    }

    func stopLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingMessage = ""
        }
    }
}

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    let gradient = Gradient(colors: [
        .gray.opacity(0.2),
        .gray.opacity(0.4),
        .gray.opacity(0.5),
        .gray.opacity(0.4),
        .gray.opacity(0.2),
    ])

    var body: some View {
        GeometryReader { geometry in
            Group {
                #if os(macOS)
                    Color(NSColor.controlBackgroundColor)
                #else
                    Color(.systemGray6)
                #endif
            }
            .overlay(
                LinearGradient(
                    gradient: gradient, startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 3)
                .offset(
                    x: -geometry.size.width + (phase * geometry.size.width * 3))
            )
            .mask(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                withAnimation(
                    .linear(duration: 2.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
    }
}

extension View {
    func shimmer(isLoading: Bool, cornerRadius: CGFloat = 8) -> some View {
        ZStack {
            self

            if isLoading {
                ShimmerView()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
}
