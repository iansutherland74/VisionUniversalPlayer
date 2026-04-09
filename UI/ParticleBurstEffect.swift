import SwiftUI

private struct ParticleBurst: Equatable {
    struct Particle: Identifiable, Equatable {
        let id = UUID()
        let symbol: String
        let angle: Double
        let distance: CGFloat
        let scale: CGFloat
        let rotation: Double
        let delay: Double
        let duration: Double
        let opacity: Double
    }

    let particles: [Particle]
    let startedAt: Date
    let totalDuration: Double

    static func make(symbols: [String], particleCount: Int, seed: Int) -> ParticleBurst {
        let resolvedSymbols = symbols.isEmpty ? ["sparkles"] : symbols
        var generator = SeededGenerator(seed: UInt64(bitPattern: Int64(seed == 0 ? 1 : seed)))
        var particles: [Particle] = []
        particles.reserveCapacity(max(particleCount, 1))

        for index in 0..<max(particleCount, 1) {
            let angle = Double.random(in: -150...30, using: &generator)
            let distance = CGFloat.random(in: 24...78, using: &generator)
            let scale = CGFloat.random(in: 0.75...1.35, using: &generator)
            let rotation = Double.random(in: -160...160, using: &generator)
            let delay = Double.random(in: 0...0.12, using: &generator)
            let duration = Double.random(in: 0.5...0.95, using: &generator)
            let opacity = Double.random(in: 0.55...1.0, using: &generator)
            let symbol = resolvedSymbols[index % resolvedSymbols.count]

            particles.append(
                Particle(
                    symbol: symbol,
                    angle: angle,
                    distance: distance,
                    scale: scale,
                    rotation: rotation,
                    delay: delay,
                    duration: duration,
                    opacity: opacity
                )
            )
        }

        let totalDuration = particles.map { $0.delay + $0.duration }.max() ?? 0.9
        return ParticleBurst(particles: particles, startedAt: Date(), totalDuration: totalDuration)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

struct ParticleBurstEffectModifier: ViewModifier {
    let trigger: Int
    let symbols: [String]
    let tint: Color
    let particleCount: Int

    @State private var burst: ParticleBurst?

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    if let burst {
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                            let elapsed = context.date.timeIntervalSince(burst.startedAt)
                            if elapsed <= burst.totalDuration {
                                ZStack {
                                    ForEach(burst.particles) { particle in
                                        particleView(particle, elapsed: elapsed)
                                    }
                                }
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0 else { return }
                burst = ParticleBurst.make(symbols: symbols, particleCount: particleCount, seed: newValue)
            }
    }

    @ViewBuilder
    private func particleView(_ particle: ParticleBurst.Particle, elapsed: Double) -> some View {
        let localElapsed = max(elapsed - particle.delay, 0)
        let progress = min(localElapsed / particle.duration, 1)
        let easedProgress = 1 - pow(1 - progress, 3)
        let radians = particle.angle * .pi / 180
        let x = cos(radians) * particle.distance * easedProgress
        let y = sin(radians) * particle.distance * easedProgress
        let opacity = progress <= 0 ? 0 : (1 - easedProgress) * particle.opacity
        let scale = 0.7 + (particle.scale * easedProgress)

        Image(systemName: particle.symbol)
            .symbolVariant(.fill)
            .font(.system(size: 11 + (10 * particle.scale), weight: .semibold, design: .rounded))
            .foregroundStyle(
                tint.opacity(opacity),
                tint.opacity(opacity * 0.45)
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(particle.rotation * easedProgress))
            .offset(x: x, y: y)
            .opacity(opacity)
            .blur(radius: easedProgress * 0.6)
            .blendMode(.plusLighter)
    }
}

extension View {
    func particleBurstEffect(
        trigger: Int,
        symbols: [String] = ["sparkles", "star", "circle.hexagongrid"],
        tint: Color = .yellow,
        particleCount: Int = 14
    ) -> some View {
        modifier(
            ParticleBurstEffectModifier(
                trigger: trigger,
                symbols: symbols,
                tint: tint,
                particleCount: particleCount
            )
        )
    }
}
