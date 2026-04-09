import SwiftUI

#if os(visionOS)
struct SpatialQuickActionsOrnament: View {
    let showControls: Bool
    let showHUD: Bool
    let immersiveButtonTitle: String
    let isImmersiveTransitioning: Bool
    let onToggleControls: () -> Void
    let onToggleHUD: () -> Void
    let onToggleImmersive: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ornamentButton(
                title: showControls ? "Hide Controls" : "Show Controls",
                systemImage: showControls ? "slider.horizontal.3.circle.fill" : "slider.horizontal.3",
                action: onToggleControls
            )

            ornamentButton(
                title: showHUD ? "Hide HUD" : "Show HUD",
                systemImage: showHUD ? "waveform.path.ecg.rectangle.fill" : "waveform.path.ecg.rectangle",
                action: onToggleHUD
            )

            ornamentButton(
                title: immersiveButtonTitle,
                systemImage: "visionpro",
                action: onToggleImmersive,
                isDisabled: isImmersiveTransitioning
            )
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 8)
    }

    private func ornamentButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void,
        isDisabled: Bool = false
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? .white.opacity(0.45) : .white.opacity(0.95))
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .disabled(isDisabled)
    }
}
#endif
