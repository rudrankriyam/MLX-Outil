import SwiftUI

struct ShimmerView: View {
    // Changed to use CGFloat for smoother animation
    @State private var phase: CGFloat = 0

    // Refined gradient colors for better visual effect
    let gradient = Gradient(colors: [
        .gray.opacity(0.2),
        .gray.opacity(0.4),
        .gray.opacity(0.5),
        .gray.opacity(0.4),
        .gray.opacity(0.2)
    ])

    var body: some View {
        GeometryReader { geometry in
            // Base layer
            Color(.systemGray6)
                .overlay(
                    // Shimmer layer
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                        .frame(width: geometry.size.width * 3)
                        .offset(x: -geometry.size.width + (phase * geometry.size.width * 3))
                )
                .mask(RoundedRectangle(cornerRadius: 8))
                // Continuous animation with smooth transition
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

// Extension remains the same
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
            .background(Color(.systemBackground))
            .shimmer(isLoading: true)
            .padding()
    }
}

// End of file
