import SwiftUI

struct AudioSpatialControls: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Enable Spatial Audio", isOn: Binding(
                get: { playerViewModel.audioEngine.spatializer.isEnabled },
                set: { playerViewModel.setSpatialAudioEnabled($0) }
            ))

            Toggle("Head Tracking", isOn: Binding(
                get: { playerViewModel.audioEngine.spatializer.headTrackingEnabled },
                set: { playerViewModel.setHeadTrackingEnabled($0) }
            ))
            .disabled(!playerViewModel.audioEngine.spatializer.isEnabled)

            labeledSlider(
                title: "Room Size",
                value: Binding(
                    get: { Double(playerViewModel.audioEngine.spatializer.roomSize) },
                    set: { playerViewModel.setSpatialRoomSize(Float($0)) }
                ),
                range: 0...1,
                valueLabel: String(format: "%.0f%%", playerViewModel.audioEngine.spatializer.roomSize * 100)
            )

            labeledSlider(
                title: "Azimuth",
                value: Binding(
                    get: { Double(playerViewModel.audioEngine.spatializer.listenerAzimuth) },
                    set: { playerViewModel.setAudioFieldAzimuth(Float($0)) }
                ),
                range: -180...180,
                valueLabel: String(format: "%.0f°", playerViewModel.audioEngine.spatializer.listenerAzimuth)
            )

            labeledSlider(
                title: "Elevation",
                value: Binding(
                    get: { Double(playerViewModel.audioEngine.spatializer.listenerElevation) },
                    set: { playerViewModel.setAudioFieldElevation(Float($0)) }
                ),
                range: -90...90,
                valueLabel: String(format: "%.0f°", playerViewModel.audioEngine.spatializer.listenerElevation)
            )

            labeledSlider(
                title: "Width",
                value: Binding(
                    get: { Double(playerViewModel.audioEngine.spatializer.wideness) },
                    set: { playerViewModel.setSpatialWidening(Float($0)) }
                ),
                range: 0...1,
                valueLabel: String(format: "%.0f%%", playerViewModel.audioEngine.spatializer.wideness * 100)
            )
        }
    }

    private func labeledSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, valueLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
