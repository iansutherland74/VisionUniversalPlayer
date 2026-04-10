import SwiftUI

struct RootView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var selectedItem: MediaItem?
    @State private var showingPlayer = false
    @StateObject private var favoritesStore = MediaFavoritesStore()
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    #if os(visionOS)
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    #endif

    private var allLibraryItems: [MediaItem] {
        TestMediaPack.groupedMedia.flatMap { $0.items }
    }

    private var favoriteItems: [MediaItem] {
        favoritesStore.favorites(from: allLibraryItems)
    }

    private var playerSheetBinding: Binding<Bool> {
        #if os(visionOS)
        if supportsMultipleWindows {
            return .constant(false)
        }
        return $showingPlayer
        #else
        return $showingPlayer
        #endif
    }

    var body: some View {
        TabView {
            vodBrowser
                .tabItem {
                    Label("Library", systemImage: "film.stack")
                }

            #if os(visionOS)
            IPTVHomeView { channel in
                let media = MediaItem(
                    title: channel.name,
                    description: "IPTV live channel",
                    url: channel.streamURL,
                    sourceKind: .ffmpegContainer,
                    codec: .h264,
                    vrFormat: .flat2D,
                    thumbnailURL: channel.logoURL,
                    duration: nil
                )
                presentPlayer(media) {
                    await playerViewModel.playMedia(media)
                }
            }
            .tabItem {
                Label("IPTV", systemImage: "tv")
            }

            VisionUIRoot(playerViewModel: playerViewModel)
                .tabItem {
                    Label("Vision UI", systemImage: "sparkles.rectangle.stack")
                }
            #endif
        }
        #if os(visionOS)
        .overlay(alignment: .bottomLeading) {
            playerLaunchDebugOverlay
        }
        #endif
        .sheet(isPresented: playerSheetBinding) {
            if let selectedItem {
                NavigationStack {
                    PlayerScreen(item: selectedItem, playerViewModel: playerViewModel)
                }
            }
        }
        #if os(visionOS)
        .onChange(of: sceneCoordinator.playerWindowVisible) { _, visible in
            if visible {
                showingPlayer = false
            }
        }
        #endif
    }

    #if os(visionOS)
    private var playerLaunchDebugOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LaunchDebug")
                .font(.caption2.weight(.semibold))
            Text("item=\(sceneCoordinator.selectedPlayerItem?.title ?? "nil")")
            Text("show=\(sceneCoordinator.shouldShowPlayerWindow ? "1" : "0") visible=\(sceneCoordinator.playerWindowVisible ? "1" : "0")")
            Text("token=\(sceneCoordinator.playerWindowRequestToken.uuidString.prefix(8))")
            Text("state=\(sceneCoordinator.playerLaunchDebug)")
                .lineLimit(2)
        }
        .font(.caption2.monospaced())
        .padding(8)
        .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
        .padding(.leading, 12)
        .padding(.bottom, 12)
    }
    #endif

    private var vodBrowser: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.04, green: 0.11, blue: 0.16),
                                        Color(red: 0.04, green: 0.18, blue: 0.26),
                                        Color(red: 0.08, green: 0.32, blue: 0.34)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                            }

                        AmbientOrbView(configuration: .oceanic)
                            .frame(width: 188, height: 188)
                            .offset(x: 26, y: -18)
                            .opacity(0.95)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Universal Online Video Player")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: 440, alignment: .leading)

                            Text("HTTP, HTTPS, FTP, and WebDAV streaming with FFmpeg demuxing, VideoToolbox decode, Metal rendering, VR, 3D, YouTube routing, and IPTV source management.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.78))
                                .frame(maxWidth: 460, alignment: .leading)

                            HStack(spacing: 10) {
                                featurePill("FFmpeg")
                                featurePill("IPTV")
                                featurePill("visionOS")
                            }
                        }
                        .padding(24)
                        .padding(.trailing, 112)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 12)

                    if !favoriteItems.isEmpty {
                        FavoritesShelfRow(items: favoriteItems) { item in
                            presentPlayer(item) {
                                await playerViewModel.playQueue(favoriteItems, startingAt: item)
                            }
                        } onAddToQueue: { item in
                            playerViewModel.appendToQueue(item)
                        } onPlayNext: { item in
                            playerViewModel.insertNextInQueue(item)
                        }
                    }

                    ForEach(TestMediaPack.groupedMedia, id: \.category) { section in
                        MediaRow(title: section.category, items: section.items) { item in
                            presentPlayer(item) {
                                await playerViewModel.playQueue(section.items, startingAt: item)
                            }
                        } onAddToQueue: { item in
                            playerViewModel.appendToQueue(item)
                        } onPlayNext: { item in
                            playerViewModel.insertNextInQueue(item)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Vision Player")
        }
        .environmentObject(favoritesStore)
        .onAppear {
            playerViewModel.setFavoritePinnedItems(favoriteItems.map(\.id))
        }
        .onChange(of: favoriteItems.map(\.id)) { _, newValue in
            playerViewModel.setFavoritePinnedItems(newValue)
        }
    }

    private func featurePill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func presentPlayer(_ item: MediaItem, startPlayback: @escaping @Sendable () async -> Void) {
        DebugCategory.navigation.infoLog(
            "Play tapped in RootView",
            context: [
                "title": item.title,
                "url": item.url.absoluteString,
                "sourceKind": String(describing: item.sourceKind),
                "vrFormat": item.vrFormat.rawValue
            ]
        )

        Task {
            await startPlayback()
            sceneCoordinator.markPlayerLaunch("startPlayback completed")
            DebugCategory.navigation.infoLog(
                "RootView startPlayback completed",
                context: ["title": item.title]
            )
        }
        selectedItem = item
        #if os(visionOS)
        sceneCoordinator.selectedPlayerItem = item
        sceneCoordinator.shouldShowPlayerWindow = true
        sceneCoordinator.markPlayerLaunch("presentPlayer queued")
        requestPlayerWindowOpen(for: item)
        #else
        selectedItem = item
        showingPlayer = true
        #endif
    }

    #if os(visionOS)
    private func requestPlayerWindowOpen(for item: MediaItem) {
        let requestToken = UUID()
        sceneCoordinator.playerWindowRequestToken = requestToken

        func request(attempt: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0 : 0.25)) {
                guard self.sceneCoordinator.playerWindowRequestToken == requestToken else {
                    self.sceneCoordinator.markPlayerLaunch("stale token dropped")
                    DebugCategory.navigation.infoLog(
                        "RootView skipped stale player-window open request",
                        context: ["attempt": "\(attempt + 1)", "title": item.title]
                    )
                    return
                }

                guard self.sceneCoordinator.selectedPlayerItem?.id == item.id else {
                    self.sceneCoordinator.markPlayerLaunch("selected item mismatch")
                    DebugCategory.navigation.infoLog(
                        "RootView canceled player-window open; selected item changed",
                        context: ["attempt": "\(attempt + 1)", "title": item.title]
                    )
                    return
                }

                if self.sceneCoordinator.playerWindowVisible {
                    self.sceneCoordinator.markPlayerLaunch("player window visible")
                    self.dismissWindow(id: SceneCoordinator.mainWindowID)
                    DebugCategory.navigation.infoLog(
                        "Player window already visible",
                        context: ["attempt": "\(attempt)", "title": item.title]
                    )
                    return
                }

                self.sceneCoordinator.shouldShowPlayerWindow = true
                self.openWindow(id: SceneCoordinator.playerWindowID)
                self.sceneCoordinator.markPlayerLaunch("openWindow attempt \(attempt + 1)")
                DebugCategory.navigation.infoLog(
                    "RootView requested openWindow",
                    context: [
                        "windowID": SceneCoordinator.playerWindowID,
                        "title": item.title,
                        "attempt": "\(attempt + 1)"
                    ]
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if self.sceneCoordinator.playerWindowVisible {
                        self.sceneCoordinator.markPlayerLaunch("main dismissed after player visible")
                        self.dismissWindow(id: SceneCoordinator.mainWindowID)
                        DebugCategory.navigation.infoLog(
                            "RootView dismissed main window after player became visible",
                            context: ["title": item.title]
                        )
                    }
                }

                if attempt < 5 {
                    request(attempt: attempt + 1)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if !self.sceneCoordinator.playerWindowVisible {
                            self.sceneCoordinator.shouldShowPlayerWindow = true
                            self.openWindow(id: SceneCoordinator.playerWindowID)
                            self.sceneCoordinator.markPlayerLaunch("final open retry fired")
                            DebugCategory.navigation.errorLog(
                                "Player window failed to become visible after retries",
                                context: ["title": item.title]
                            )
                        }
                    }
                }
            }
        }

        request(attempt: 0)
    }
    #endif
}

#Preview {
    RootView(playerViewModel: PlayerViewModel())
}
