import SwiftUI

struct LipSyncCalibrationView: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lip-Sync Calibration")
                .font(.headline)

            Text("Use this offset when the picture consistently leads or trails dialog across the current output path.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Calibration")
                Spacer()
                Text(String(format: "%+.0f ms", playerViewModel.audioEngine.lipSyncCalibrationMS))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { playerViewModel.audioEngine.lipSyncCalibrationMS },
                    set: { playerViewModel.setLipSyncCalibrationMS($0) }
                ),
                in: -250...250,
                step: 5
            )

            Text("Effective path correction: \(String(format: "%+.0f ms", playerViewModel.audioEngine.audioSyncOffsetMS + playerViewModel.audioEngine.lipSyncCalibrationMS))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
