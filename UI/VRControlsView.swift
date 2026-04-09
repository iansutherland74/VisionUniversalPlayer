import SwiftUI

struct VRControlsView: View {
    @ObservedObject var playerModel: PlayerViewModel
    @AppStorage("immersive.controls.distance") private var controlsDistance = 0.9
    @AppStorage("immersive.controls.height") private var controlsHeight = -0.28
    @AppStorage("immersive.controls.tilt") private var controlsTilt = -18.0
    @AppStorage("immersive.debug.bounds") private var showBoundsGuides = false
    @AppStorage("immersive.debug.bounds.scale") private var boundsGuideScale = 1.0
    @AppStorage("immersive.effects.shaderPulse") private var shaderPulseEnabled = true
    @AppStorage("immersive.effects.shaderPulseSpeed") private var shaderPulseSpeed = 1.2
    @AppStorage("immersive.display.autoRotate") private var displayAutoRotateEnabled = false
    @AppStorage("immersive.display.autoRotateSpeed") private var displayAutoRotateSpeed = 18.0
    @AppStorage("immersive.debug.realityCheck") private var showRealityCheckPanel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VR/3D")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Mode", selection: Binding(
                get: { playerModel.selectedMode },
                set: { playerModel.switchMode($0) }
            )) {
                ForEach(PlayerViewModel.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("2D -> 3D Conversion", isOn: $playerModel.enable2Dto3DConversion)
                .font(.caption)

            Toggle("Show Bounds Guides", isOn: $showBoundsGuides)
                .font(.caption)

            if showBoundsGuides {
                compactControlRow(
                    title: "Bounds Scale",
                    value: $boundsGuideScale,
                    range: 0.6...1.8,
                    accentColor: .green,
                    format: "%.2fx"
                )
            }

            Toggle("Shader Pulse", isOn: $shaderPulseEnabled)
                .font(.caption)

            Toggle("Display Auto-Rotate", isOn: $displayAutoRotateEnabled)
                .font(.caption)

            if displayAutoRotateEnabled {
                compactControlRow(
                    title: "Spin Speed",
                    value: $displayAutoRotateSpeed,
                    range: 4...80,
                    accentColor: .orange,
                    format: "%.0f°/s"
                )
            }

            Toggle("Reality Check Snapshot", isOn: $showRealityCheckPanel)
                .font(.caption)

            if shaderPulseEnabled {
                compactControlRow(
                    title: "Pulse Speed",
                    value: $shaderPulseSpeed,
                    range: 0.2...3.0,
                    accentColor: .purple,
                    format: "%.2fx"
                )
            }

            if playerModel.enable2Dto3DConversion {
                VStack(spacing: 8) {
                    compactControlRow(
                        title: "Depth",
                        value: $playerModel.depthStrength,
                        range: 0.3...2.5,
                        accentColor: .mint,
                        format: "%.2fx"
                    )
                    compactControlRow(
                        title: "Convergence",
                        value: $playerModel.convergence,
                        range: 0.1...2.0,
                        accentColor: .cyan,
                        format: "%.2f"
                    )
                }
            }

            if let currentMedia = playerModel.currentMedia,
               currentMedia.resolvedFramePacking != FramePacking.none {
                VStack(spacing: 8) {
                    compactControlRow(
                        title: "Baseline",
                        value: $playerModel.stereoBaseline,
                        range: 40...80,
                        accentColor: .orange,
                        format: "%.0f mm"
                    )
                    compactControlRow(
                        title: "Horiz. Disparity",
                        value: $playerModel.horizontalDisparity,
                        range: -1.0...1.0,
                        accentColor: .pink,
                        format: "%+.2f"
                    )
                }
            }

            VStack(spacing: 8) {
                compactControlRow(
                    title: "Dock Distance",
                    value: $controlsDistance,
                    range: 0.6...1.4,
                    accentColor: .teal,
                    format: "%.2f m"
                )
                compactControlRow(
                    title: "Dock Height",
                    value: $controlsHeight,
                    range: -0.55...0.05,
                    accentColor: .blue,
                    format: "%+.2f m"
                )
                compactControlRow(
                    title: "Dock Tilt",
                    value: $controlsTilt,
                    range: -35...5,
                    accentColor: .indigo,
                    format: "%.0f°"
                )

                Button("Reset Dock Position") {
                    resetDockPlacement()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }

            if showRealityCheckPanel, let snapshot = playerModel.immersiveSnapshot {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reality Check")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Mode")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshot.mode)
                            .font(.caption2.monospaced())
                    }

                    HStack {
                        Text("Surface")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshot.renderSurface)
                            .font(.caption2.monospaced())
                    }

                    HStack {
                        Text("Entities")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("content \(snapshot.modeEntityChildren) • controls \(snapshot.controlsEntityChildren)")
                            .font(.caption2.monospaced())
                    }

                    HStack {
                        Text("Content")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f %.2f %.2f", snapshot.contentX, snapshot.contentY, snapshot.contentZ))
                            .font(.caption2.monospaced())
                    }

                    HStack {
                        Text("Controls")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f %.2f %.2f", snapshot.controlsX, snapshot.controlsY, snapshot.controlsZ))
                            .font(.caption2.monospaced())
                    }

                    if let hx = snapshot.headX, let hy = snapshot.headY, let hz = snapshot.headZ {
                        HStack {
                            Text("Head")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f %.2f %.2f", hx, hy, hz))
                                .font(.caption2.monospaced())
                        }
                    }

                    HStack {
                        Text("Bounds")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshot.boundsGuidesEnabled ? "On" : "Off")
                            .font(.caption2.monospaced())
                    }
                }
                .padding(8)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func compactControlRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        accentColor: Color,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            CompactValueSlider(
                value: value,
                range: range,
                accentColor: accentColor,
                valueLabel: { String(format: format, $0) }
            )
        }
    }

    private func compactControlRow(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        accentColor: Color,
        format: String
    ) -> some View {
        compactControlRow(
            title: title,
            value: Binding<Double>(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Float($0) }
            ),
            range: Double(range.lowerBound)...Double(range.upperBound),
            accentColor: accentColor,
            format: format
        )
    }

    private func resetDockPlacement() {
        controlsDistance = playerModel.selectedMode == .vr360 ? 1.0 : 0.9
        controlsHeight = playerModel.selectedMode == .vr360 ? -0.32 : -0.28
        controlsTilt = -18.0
    }
}

#Preview {
    VRControlsView(playerModel: PlayerViewModel())
        .padding()
}
