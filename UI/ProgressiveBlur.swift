import SwiftUI

enum ProgressiveBlurDirection {
    case up
    case down
    case left
    case right
}

enum ProgressiveBlurProfile {
    case soft
    case medium
    case strong

    var interpolation: CGFloat {
        switch self {
        case .soft:
            return 0.55
        case .medium:
            return 0.4
        case .strong:
            return 0.25
        }
    }

    var tintOpacity: CGFloat {
        switch self {
        case .soft:
            return 0.06
        case .medium:
            return 0.1
        case .strong:
            return 0.14
        }
    }

    var storageValue: String {
        switch self {
        case .soft:
            return "soft"
        case .medium:
            return "medium"
        case .strong:
            return "strong"
        }
    }

    init(storageValue: String) {
        switch storageValue.lowercased() {
        case "soft":
            self = .soft
        case "strong":
            self = .strong
        default:
            self = .medium
        }
    }
}

struct ProgressiveBlurModifier: ViewModifier {
    var offset: CGFloat
    var interpolation: CGFloat
    var direction: ProgressiveBlurDirection
    var noise: CGFloat
    var profile: ProgressiveBlurProfile

    func body(content: Content) -> some View {
        // Glur-inspired compatibility approach using material + directional mask.
        content
            .background(.ultraThinMaterial)
            .overlay(alignment: .center) {
                // Add a subtle texture/tint pass so the blur edge feels less flat.
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(profile.tintOpacity),
                                Color.black.opacity(profile.tintOpacity * 0.75)
                            ],
                            startPoint: gradientStartPoint,
                            endPoint: gradientEndPoint
                        )
                    )
                    .blendMode(.overlay)
                    .opacity(max(0, min(noise, 1)) * 0.25)
            }
            .mask(maskGradient)
    }

    private var maskGradient: LinearGradient {
        let clampedOffset = min(max(offset, 0), 1)
        let profileInterpolation = interpolation <= 0 ? profile.interpolation : interpolation
        let clampedInterpolation = min(max(profileInterpolation, 0.01), 1)
        let endStop = min(clampedOffset + clampedInterpolation, 1)

        let stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0),
            .init(color: .clear, location: clampedOffset),
            .init(color: .white, location: endStop),
            .init(color: .white, location: 1)
        ]

        switch direction {
        case .down:
            return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
        case .up:
            return LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
        case .left:
            return LinearGradient(stops: stops, startPoint: .trailing, endPoint: .leading)
        case .right:
            return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
        }
    }

    private var gradientStartPoint: UnitPoint {
        switch direction {
        case .down:
            return .topLeading
        case .up:
            return .bottomTrailing
        case .left:
            return .topTrailing
        case .right:
            return .topLeading
        }
    }

    private var gradientEndPoint: UnitPoint {
        switch direction {
        case .down:
            return .bottomTrailing
        case .up:
            return .topLeading
        case .left:
            return .bottomLeading
        case .right:
            return .bottomTrailing
        }
    }
}

extension View {
    func progressiveBlur(
        offset: CGFloat = 0.05,
        interpolation: CGFloat = 0.45,
        direction: ProgressiveBlurDirection = .down,
        noise: CGFloat = 0,
        profile: ProgressiveBlurProfile = .medium
    ) -> some View {
        modifier(
            ProgressiveBlurModifier(
                offset: offset,
                interpolation: interpolation,
                direction: direction,
                noise: noise,
                profile: profile
            )
        )
    }
}
