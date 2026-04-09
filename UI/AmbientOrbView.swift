import SwiftUI

struct AmbientOrbConfiguration {
    var colors: [Color] = [Color(red: 0.18, green: 0.62, blue: 0.98), Color(red: 0.02, green: 0.93, blue: 0.78), Color(red: 0.55, green: 0.86, blue: 1.0)]
    var glowColor: Color = .white
    var particleColor: Color = .white
    var coreGlowIntensity: Double = 1.0
    var showParticles = true
    var showShadow = true
    var speed: Double = 1.0

    static let oceanic = AmbientOrbConfiguration()

    static let sunrise = AmbientOrbConfiguration(
        colors: [Color(red: 0.98, green: 0.44, blue: 0.24), Color(red: 0.98, green: 0.72, blue: 0.26), Color(red: 1.0, green: 0.38, blue: 0.54)],
        glowColor: Color(red: 1.0, green: 0.93, blue: 0.82),
        particleColor: Color(red: 1.0, green: 0.92, blue: 0.72),
        coreGlowIntensity: 0.9,
        showParticles: true,
        showShadow: true,
        speed: 0.82
    )
}

struct AmbientOrbView: View {
    var configuration: AmbientOrbConfiguration = .oceanic
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 36.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate * configuration.speed

            ZStack {
                if configuration.showShadow {
                    Circle()
                        .fill(configuration.colors[0].opacity(0.2))
                        .blur(radius: 40)
                        .scaleEffect(1.18)
                        .offset(y: 18)
                }

                orbBody(time: t)

                if configuration.showParticles {
                    particleLayer(time: t)
                        .mask(Circle().scale(1.05))
                }
            }
            .drawingGroup()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func orbBody(time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            configuration.glowColor.opacity(0.28 * configuration.coreGlowIntensity),
                            configuration.colors[1].opacity(0.24),
                            configuration.colors[0].opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .scaleEffect(1.22)
                .blur(radius: 10)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            configuration.colors[0],
                            configuration.colors[1],
                            configuration.colors[2]
                        ],
                        startPoint: UnitPoint(x: 0.18, y: 0.12),
                        endPoint: UnitPoint(x: 0.84, y: 0.92)
                    )
                )
                .overlay {
                    blobLayer(time: time)
                        .blendMode(.screen)
                        .mask(Circle())
                }
                .overlay {
                    Circle()
                        .strokeBorder(configuration.glowColor.opacity(0.22), lineWidth: 1)
                        .blur(radius: 0.4)
                }
                .overlay {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    configuration.glowColor.opacity(0.72 * configuration.coreGlowIntensity),
                                    configuration.glowColor.opacity(0.05),
                                    .clear
                                ],
                                center: UnitPoint(x: 0.42, y: 0.38),
                                startRadius: 2,
                                endRadius: 44
                            )
                        )
                        .blur(radius: 6)
                        .scaleEffect(0.58)
                        .offset(x: -10, y: -12)
                }
                .overlay {
                    Circle()
                        .fill(.white.opacity(0.16))
                        .blur(radius: 12)
                        .scaleEffect(0.16)
                        .offset(x: -26, y: -30)
                }
        }
    }

    private func blobLayer(time: TimeInterval) -> some View {
        ZStack {
            movingBlob(
                color: configuration.colors[2].opacity(0.38),
                size: CGSize(width: 96, height: 112),
                x: cos(time * 0.7) * 22,
                y: sin(time * 0.9) * 18,
                blur: 20,
                rotation: Angle.degrees(sin(time * 0.5) * 30)
            )

            movingBlob(
                color: configuration.glowColor.opacity(0.18),
                size: CGSize(width: 84, height: 76),
                x: sin(time * 1.1) * -18,
                y: cos(time * 0.8) * 16,
                blur: 16,
                rotation: Angle.degrees(cos(time * 0.55) * 24)
            )

            movingBlob(
                color: configuration.colors[0].opacity(0.26),
                size: CGSize(width: 72, height: 92),
                x: cos(time * 1.24) * -14,
                y: sin(time * 0.65) * -20,
                blur: 18,
                rotation: Angle.degrees(sin(time * 0.92) * -28)
            )
        }
    }

    private func movingBlob(
        color: Color,
        size: CGSize,
        x: Double,
        y: Double,
        blur: CGFloat,
        rotation: Angle
    ) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: size.width, height: size.height)
            .rotationEffect(rotation)
            .offset(x: x, y: y)
            .blur(radius: blur)
    }

    private func particleLayer(time: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                let phase = time * (0.52 + Double(index) * 0.037)
                let angle = phase + Double(index) * 0.78
                let radius = 26 + sin(phase * 1.6) * 12 + Double(index % 3) * 7
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                let opacity = 0.18 + (0.34 * ((sin(phase * 2.2) + 1) / 2))
                let size = 2.0 + (Double(index % 4) * 0.7)

                Circle()
                    .fill(configuration.particleColor.opacity(opacity))
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.3)
                    .offset(x: x, y: y)
            }
        }
    }
}
