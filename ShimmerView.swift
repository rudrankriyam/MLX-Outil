import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    let gradient = Gradient(colors: [
        .gray.opacity(0.2),
        .gray.opacity(0.4),
        .gray.opacity(0.5),
        .gray.opacity(0.4),
        .gray.opacity(0.2)
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
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                        .frame(width: geometry.size.width * 3)
                        .offset(x: -geometry.size.width + (phase * geometry.size.width * 3))
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

#Preview {
    VStack(spacing: 20) {
        ShimmerView()
            .frame(height: 60)
            .padding()

        Text("Loading Content")
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
            .shimmer(isLoading: true)
            .padding()
    }
}
