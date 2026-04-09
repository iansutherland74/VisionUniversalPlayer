import SwiftUI

struct QueueManagerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(playerViewModel.queueItems.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        if playerViewModel.queueNowPlayingIndex == index {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .lineLimit(1)
                            Text(item.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Play") {
                            Task {
                                await playerViewModel.playQueueItem(at: index)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Play Next") {
                            playerViewModel.moveQueueItemNext(at: index)
                        }
                        .tint(.blue)

                        Button("Delete", role: .destructive) {
                            playerViewModel.removeQueueItems(at: IndexSet(integer: index))
                        }
                    }
                }
                .onMove(perform: playerViewModel.moveQueueItems)
                .onDelete(perform: playerViewModel.removeQueueItems)
            }
            .overlay {
                if playerViewModel.queueItems.isEmpty {
                    ContentUnavailableView("Queue Empty", systemImage: "list.bullet.rectangle", description: Text("Start playback from a row or favorites shelf to build a queue."))
                }
            }
            .navigationTitle("Playlist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .disabled(playerViewModel.queueItems.isEmpty)
                }
            }
        }
    }
}

#Preview {
    QueueManagerView(playerViewModel: PlayerViewModel())
}
