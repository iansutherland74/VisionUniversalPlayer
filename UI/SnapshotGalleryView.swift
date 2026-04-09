import SwiftUI

struct SnapshotGalleryView: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            Group {
                if playerViewModel.snapshotFiles.isEmpty {
                    ContentUnavailableView("No Snapshots", systemImage: "photo")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(playerViewModel.snapshotFiles, id: \.self) { fileURL in
                                snapshotRow(fileURL)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Snapshots")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh") {
                        playerViewModel.refreshSnapshotGallery()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", role: .destructive) {
                        playerViewModel.clearSnapshots()
                    }
                    .disabled(playerViewModel.snapshotFiles.isEmpty)
                }
            }
        }
        .onAppear {
            playerViewModel.refreshSnapshotGallery()
        }
    }

    private func snapshotRow(_ fileURL: URL) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: fileURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 140, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(fileURL.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(fileURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(role: .destructive) {
                playerViewModel.deleteSnapshot(at: fileURL)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    SnapshotGalleryView(playerViewModel: PlayerViewModel())
}
