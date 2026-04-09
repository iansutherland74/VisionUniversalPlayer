import SwiftUI

/// Apple TV–inspired IPTV home screen with channels as horizontal carousel.
struct AppleTVIPTVHomeView: View {
    @StateObject private var iptvManager = IPTVManager()
    @State private var selectedCategory = "All"
    let categories = ["All", "Sports", "News", "Movies", "Music", "Kids"]
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.blue.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("IPTV")
                        .font(.system(size: 32, weight: .bold))
                    
                    // Category tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: { selectedCategory = category }) {
                                    Text(category)
                                        .font(.headline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedCategory == category ?
                                            Color.blue :
                                            Color.white.opacity(0.1)
                                        )
                                        .foregroundStyle(selectedCategory == category ? .black : .white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 24)
                
                // Now Playing Featured Section
                if let featured = iptvManager.channels.first {
                    AppleTVIPTVFeaturedView(channel: featured)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                }
                
                // Channel carousels
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        // Live Now
                        channelSection(
                            title: "Live Now",
                            channels: Array(iptvManager.channels.filter { $0.isLive }.prefix(6))
                        )
                        
                        // Recommended
                        channelSection(
                            title: "Recommended for You",
                            channels: Array(iptvManager.channels.filter { $0.isRecommended }.prefix(6))
                        )
                        
                        // Category-specific
                        channelSection(
                            title: selectedCategory,
                            channels: Array(iptvManager.channels.filter { $0.category == selectedCategory }.prefix(6))
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .foregroundStyle(.white)
        }
    }
    
    @ViewBuilder
    private func channelSection(title: String, channels: [DemoIPTVChannel]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(channels, id: \.id) { channel in
                        AppleTVChannelCard(channel: channel)
                            .frame(width: 160, height: 120)
                    }
                }
            }
        }
    }
}

/// Single IPTV channel card with large logo and hover effects.
struct AppleTVChannelCard: View {
    let channel: DemoIPTVChannel
    @State private var isHovering = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Channel logo/image
            AsyncImage(url: URL(string: channel.logoURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.3))
                
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                
                case .failure:
                    Image(systemName: "tv")
                        .font(.system(size: 48))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.3))
                
                @unknown default:
                    EmptyView()
                }
            }
            
            // Live indicator + channel info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if channel.isLive {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.red)
                        Text("LIVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                
                Text(channel.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                
                if let program = channel.currentProgram {
                    Text(program)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Hover overlay
            if isHovering {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 3)
                    .transition(.scale.animation(.easeOut(duration: 0.2)))
            }
        }
        .cornerRadius(12)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .shadow(color: isHovering ? Color.blue.opacity(0.5) : Color.black.opacity(0.3), radius: isHovering ? 12 : 6)
        .scaleEffect(isHovering ? 1.05 : 1.0)
    }
}

/// Featured channel view with EPG timeline and program info.
struct AppleTVIPTVFeaturedView: View {
    let channel: DemoIPTVChannel
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Large channel logo
            AsyncImage(url: URL(string: channel.logoURL)) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 20)
                        .brightness(-0.3)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    // Channel logo (smaller)
                    AsyncImage(url: URL(string: channel.logoURL)) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(channel.name)
                            .font(.title2.weight(.bold))
                        
                        if let program = channel.currentProgram {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                Text("Now: \(program)")
                                    .font(.callout)
                                    .lineLimit(1)
                            }
                        }
                        
                        if let nextProgram = channel.nextProgram {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("Next: \(nextProgram)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Watch Now")
                        }
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Remind")
                        }
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            }
            .padding(24)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 240)
        .cornerRadius(16)
    }
}

/// Model for IPTV channel with EPG data.
struct DemoIPTVChannel: Identifiable {
    let id = UUID()
    let name: String
    let logoURL: String
    let isLive: Bool
    let isRecommended: Bool
    let category: String
    let currentProgram: String?
    let nextProgram: String?
}

/// Mock IPTV manager for demo purposes.
class IPTVManager: ObservableObject {
    @Published var channels: [DemoIPTVChannel] = [
        DemoIPTVChannel(
            name: "News 24",
            logoURL: "https://via.placeholder.com/160x120?text=News24",
            isLive: true,
            isRecommended: true,
            category: "News",
            currentProgram: "Breaking News Report",
            nextProgram: "World Update"
        ),
        DemoIPTVChannel(
            name: "Sports HD",
            logoURL: "https://via.placeholder.com/160x120?text=SportsHD",
            isLive: true,
            isRecommended: true,
            category: "Sports",
            currentProgram: "Live Soccer Match",
            nextProgram: "Tennis Championship"
        ),
        DemoIPTVChannel(
            name: "Movie Classics",
            logoURL: "https://via.placeholder.com/160x120?text=Movies",
            isLive: false,
            isRecommended: true,
            category: "Movies",
            currentProgram: "Casablanca",
            nextProgram: "Breakfast at Tiffany's"
        ),
        DemoIPTVChannel(
            name: "Music Premium",
            logoURL: "https://via.placeholder.com/160x120?text=Music",
            isLive: false,
            isRecommended: false,
            category: "Music",
            currentProgram: "Top 40 Countdown",
            nextProgram: "Jazz Standards"
        ),
        DemoIPTVChannel(
            name: "Kids Zone",
            logoURL: "https://via.placeholder.com/160x120?text=Kids",
            isLive: true,
            isRecommended: true,
            category: "Kids",
            currentProgram: "Cartoon Adventures",
            nextProgram: "Educational Show"
        ),
        DemoIPTVChannel(
            name: "Documentary",
            logoURL: "https://via.placeholder.com/160x120?text=Docs",
            isLive: false,
            isRecommended: false,
            category: "Movies",
            currentProgram: "Planet Earth",
            nextProgram: "Ocean Life"
        ),
    ]
}

#Preview {
    AppleTVIPTVHomeView()
        .background(Color.black)
}
