import SwiftUI

/// Apple TV–style home screen with hero banner, navigation, and content carousels.
struct AppleTVStyleRootView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var selectedItem: MediaItem?
    @State private var showingPlayer = false
    @State private var currentNavTab: String = "home"
    @State private var featuredItemIndex = 0
    @StateObject private var favoritesStore = MediaFavoritesStore()

    private var allLibraryItems: [MediaItem] {
        TestMediaPack.groupedMedia.flatMap { $0.items }
    }

    private var favoriteItems: [MediaItem] {
        favoritesStore.favorites(from: allLibraryItems)
    }

    private var featuredItems: [MediaItem] {
        Array(allLibraryItems.prefix(6))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                navigationBar
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)

                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 48) {
                            heroBanner
                                .frame(height: 420)
                                .id("hero")

                            if !favoriteItems.isEmpty {
                                contentSection(
                                    title: "Continue Watching",
                                    items: Array(favoriteItems.prefix(8))
                                ) { item in
                                    selectItem(item, from: favoriteItems)
                                }
                            }

                            ForEach(TestMediaPack.groupedMedia, id: \.category) { section in
                                contentSection(
                                    title: section.category,
                                    items: section.items
                                ) { item in
                                    selectItem(item, from: section.items)
                                }
                            }

                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                    }
                }
            }
            .foregroundStyle(.white)

            if showingPlayer, let item = selectedItem {
                PlayerScreen(item: item, playerViewModel: playerViewModel)
                    .transition(.opacity)
            }
        }
        .environmentObject(favoritesStore)
        .onAppear {
            playerViewModel.setFavoritePinnedItems(favoriteItems.map(\.id))
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 24) {
            let tabs: [(key: String, label: String)] = [
                ("home", "Home"),
                ("movies", "Movies"),
                ("tv", "TV Shows"),
                ("library", "Library"),
                ("iptv", "IPTV"),
                ("settings", "Settings")
            ]
            ForEach(tabs, id: \.key) { key, label in
                navButton(label, isSelected: currentNavTab == key) {
                    currentNavTab = key
                }
            }
            Spacer()
        }
        .font(.callout.weight(.semibold))
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Material.thick)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func navButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            // Artwork background
            AsyncImage(url: featuredItems[featuredItemIndex].thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                default:
                    Color.gray.opacity(0.3)
                }
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(featuredItems[featuredItemIndex].title)
                        .font(.system(size: 42, weight: .bold, design: .default))

                    Text(featuredItems[featuredItemIndex].description)
                        .font(.headline)
                        .lineLimit(2)
                        .opacity(0.9)

                    HStack(spacing: 16) {
                        heroButton("Play", systemImage: "play.fill") {
                            selectItem(featuredItems[featuredItemIndex], from: featuredItems)
                        }

                        heroButton("More Info", systemImage: "info.circle.fill") {}
                    }
                }

                HStack(spacing: 8) {
                    ForEach(0..<featuredItems.count, id: \.self) { index in
                        Capsule()
                            .fill(index == featuredItemIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(height: 4)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    featuredItemIndex = index
                                }
                            }
                    }
                }
            }
            .padding(32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 24)
    }

    private func heroButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white)
            .foregroundStyle(.black)
            .font(.headline)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contentSection(title: String, items: [MediaItem], onSelect: @escaping (MediaItem) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items, id: \.id) { item in
                        AppleTVMediaCard(item: item) {
                            onSelect(item)
                        }
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func selectItem(_ item: MediaItem, from items: [MediaItem]) {
        selectedItem = item
        Task {
            await playerViewModel.playQueue(items, startingAt: item)
        }
        withAnimation { showingPlayer = true }
    }
}

// MARK: - Apple TV Media Card

struct AppleTVMediaCard: View {
    let item: MediaItem
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if isHovered {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Image(systemName: "film")
                            Text(item.codec.rawValue.uppercased())
                                .font(.caption2)
                        }
                        .opacity(0.8)
                    }
                    .padding(12)
                }
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.5 : 0.2), radius: isHovered ? 16 : 8)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    AppleTVStyleRootView(playerViewModel: PlayerViewModel())
}
