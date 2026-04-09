import SwiftUI

struct ShimmerModifier: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection

    let active: Bool
    let animation: Animation
    let gradient: Gradient
    let bandSize: CGFloat

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { proxy in
                        shimmerOverlay(size: proxy.size)
                    }
                    .allowsHitTesting(false)
                    .mask(content)
                }
            }
            .onAppear {
                guard active else { return }
                phase = -1
                withAnimation(animation) {
                    phase = 2
                }
            }
            .onChange(of: active) { _, isActive in
                if isActive {
                    phase = -1
                    withAnimation(animation) {
                        phase = 2
                    }
                }
            }
    }

    @ViewBuilder
    private func shimmerOverlay(size: CGSize) -> some View {
        let width = max(size.width, 1)
        let isRTL = layoutDirection == .rightToLeft
        let adjustedPhase = isRTL ? (1 - phase) : phase

        LinearGradient(
            gradient: gradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: width * max(bandSize, 0.1), height: size.height * 1.6)
        .rotationEffect(.degrees(18))
        .offset(x: adjustedPhase * width * 1.8 - (width * 0.9))
    }
}

extension View {
    func shimmering(
        active: Bool = true,
        animation: Animation = .linear(duration: 1.4).repeatForever(autoreverses: false),
        gradient: Gradient = Gradient(colors: [
            Color.white.opacity(0.0),
            Color.white.opacity(0.45),
            Color.white.opacity(0.0)
        ]),
        bandSize: CGFloat = 0.28
    ) -> some View {
        modifier(
            ShimmerModifier(
                active: active,
                animation: animation,
                gradient: gradient,
                bandSize: bandSize
            )
        )
    }
}
