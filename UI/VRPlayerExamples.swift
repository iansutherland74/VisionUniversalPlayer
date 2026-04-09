import SwiftUI

struct PlayerScreenWithVRExample: View {
    @StateObject private var model = PlayerViewModel()
    @State private var selectedItem: MediaItem = TestMediaPack.allMedia.first ?? MediaItem.samples[0]

    var body: some View {
        VStack(spacing: 12) {
            Picker("Sample", selection: Binding(
                get: { selectedItem.id },
                set: { id in
                    if let item = TestMediaPack.allMedia.first(where: { $0.id == id }) {
                        selectedItem = item
                        Task {
                            await model.playMedia(item)
                        }
                    }
                }
            )) {
                ForEach(TestMediaPack.allMedia) { item in
                    Text(item.title).tag(item.id)
                }
            }
            .pickerStyle(.menu)

            VRControlsView(playerModel: model)

            PlayerScreen(item: selectedItem, playerViewModel: model)
        }
        .task {
            await model.playMedia(selectedItem)
        }
    }
}

#Preview {
    PlayerScreenWithVRExample()
}
