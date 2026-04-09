import SwiftUI

/// Apple TV–style media detail view with large artwork, metadata, and playback actions.
struct AppleTVDetailView: View {
    let item: MediaItem
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background poster with blur
            AsyncImage(url: item.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .blur(radius: 40)
                default:
                    Color.gray.opacity(0.3)
                        .ignoresSafeArea()
                }
            }

            LinearGradient(
                colors: [.clear, Color(UIColor.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Poster + Actions
                    HStack(spacing: 24) {
                        AsyncImage(url: item.thumbnailURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 140, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 12)

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .lineLimit(3)

                                HStack(spacing: 12) {
                                    badgeView("HD")
                                    badgeView(item.codec.rawValue.uppercased())
                                    if item.vrFormat.isImmersive {
                                        badgeView("VR")
                                    }
                                }
                            }

                            Spacer()

                            actionButtonRow(item: item, playerViewModel: playerViewModel)
                        }
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(height: 210)
                    .padding(24)

                    divider

                    // Metadata
                    VStack(alignment: .leading, spacing: 20) {
                        Text("About").font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            metadataRow("Description", value: item.description)
                            if let duration = item.duration {
                                metadataRow("Duration", value: formatDuration(duration))
                            }
                            metadataRow("Format", value: formatVRFormat(item.vrFormat))
                            metadataRow("Codec", value: item.codec.rawValue.uppercased())
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                    divider

                    // Audio & Video Formats
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Audio & Video").font(.headline)

                        HStack(spacing: 16) {
                            ForEach(["Stereo", "Surround", "Atmos"], id: \.self) { format in
                                badgeView(format)
                            }
                            Spacer()
                        }

                        HStack(spacing: 16) {
                            ForEach(["HD", "4K", "HDR"], id: \.self) { format in
                                badgeView(format)
                            }
                            Spacer()
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                    Color.clear.frame(height: 100)
                }
                .padding(.vertical, 24)
            }

            // Top back button
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Material.thick)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    Spacer()
                }
                .padding(24)

                Spacer()
            }
        }
        .foregroundStyle(.white)
    }

    private var divider: some View {
        Divider().opacity(0.2)
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15), in: Capsule())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }

    private func formatVRFormat(_ format: VRFormat) -> String {
        switch format {
        case .flat2D: return "2D Flat"
        case .sideBySide3D: return "3D Side-by-Side"
        case .topBottom3D: return "3D Top-Bottom"
        case .mono180: return "180° Mono VR"
        case .stereo180SBS: return "180° Stereo VR"
        case .stereo180TAB: return "180° Stereo VR"
        case .mono360: return "360° Mono VR"
        case .stereo360SBS: return "360° Stereo VR"
        case .stereo360TAB: return "360° Stereo VR"
        }
    }
}

/// Action buttons: Play, Add to Up Next, Audio/Subtitles, More Info.
private func actionButtonRow(item: MediaItem, playerViewModel: PlayerViewModel) -> some View {
    VStack(spacing: 10) {
        Button(action: {
            Task {
                await playerViewModel.playMedia(item)
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Play")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundStyle(.black)
            .font(.headline)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)

        HStack(spacing: 10) {
            Button(action: {
                playerViewModel.appendToQueue(item)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text("Up Next")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .font(.subheadline.weight(.semibold))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                    Text("Audio")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .font(.subheadline.weight(.semibold))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    AppleTVDetailView(item: MediaItem.samples[0], playerViewModel: PlayerViewModel())
}
