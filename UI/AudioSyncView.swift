import SwiftUI

struct AudioSyncView: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Sync")
                .font(.headline)

            Text("Shift audio earlier or later to align network, HDMI, or Bluetooth latency.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Offset")
                Spacer()
                Text(String(format: "%+.0f ms", playerViewModel.audioEngine.audioSyncOffsetMS))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { playerViewModel.audioEngine.audioSyncOffsetMS },
                    set: { playerViewModel.setAudioSyncOffsetMS($0) }
                ),
                in: -250...250,
                step: 5
            )

            HStack(spacing: 12) {
                Button("-25 ms") {
                    playerViewModel.setAudioSyncOffsetMS(playerViewModel.audioEngine.audioSyncOffsetMS - 25)
                }
                Button("Reset") {
                    playerViewModel.setAudioSyncOffsetMS(0)
                }
                Button("+25 ms") {
                    playerViewModel.setAudioSyncOffsetMS(playerViewModel.audioEngine.audioSyncOffsetMS + 25)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
