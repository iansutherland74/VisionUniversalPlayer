import SwiftUI

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @State private var searchText = ""
    @State private var selectedCategory: EmojiPickerCategory = .media

    private let columns = Array(repeating: GridItem(.flexible(minimum: 28, maximum: 44), spacing: 10), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search emoji", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EmojiPickerCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category.label)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredEmojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(selectedEmoji == emoji ? Color.accentColor.opacity(0.18) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var filteredEmojis: [String] {
        let emojis = selectedCategory.emojis
        guard searchText.isEmpty == false else { return emojis }
        let query = searchText.lowercased()
        return emojis.filter { emoji in
            EmojiPickerCategory.allCases
                .first(where: { $0.emojis.contains(emoji) })?
                .keywords(for: emoji)
                .contains(where: { $0.contains(query) }) ?? false
        }
    }
}

enum EmojiPickerCategory: String, CaseIterable, Identifiable {
    case media
    case smileys
    case nature
    case travel
    case symbols

    var id: String { rawValue }

    var label: String {
        switch self {
        case .media: return "📺 Media"
        case .smileys: return "😀 Faces"
        case .nature: return "🌍 Nature"
        case .travel: return "🚀 Travel"
        case .symbols: return "⭐ Symbols"
        }
    }

    var emojis: [String] {
        switch self {
        case .media:
            return ["📺", "🎬", "🎞️", "🎥", "📡", "🛰️", "📻", "🎙️", "🎧", "🎵", "🎶", "📼", "💿", "🖥️", "📱", "🕹️", "🎮", "📰", "📚", "🗂️"]
        case .smileys:
            return ["😀", "😎", "🤩", "🥳", "🫡", "🤖", "🧠", "👀", "👍", "👏", "🙌", "🔥", "✨", "💡", "🎉", "💯"]
        case .nature:
            return ["🌍", "🌎", "🌏", "🌊", "☀️", "🌤️", "⛅️", "🌙", "⭐", "🌟", "⚡", "🌈", "🌴", "🍀", "🌲", "🪐"]
        case .travel:
            return ["🚀", "✈️", "🚁", "🚄", "🚢", "🛸", "🧭", "🗺️", "🏝️", "🏙️", "🌐", "📍", "🛜", "🔭"]
        case .symbols:
            return ["⭐", "🌟", "💫", "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "🔔", "✅", "❇️", "⚙️", "🔒", "🆕", "🆒", "🔷"]
        }
    }

    func keywords(for emoji: String) -> [String] {
        switch emoji {
        case "📺": return ["tv", "television", "media"]
        case "🎬": return ["movie", "film", "media"]
        case "📡": return ["satellite", "broadcast", "iptv"]
        case "🛰️": return ["satellite", "space", "broadcast"]
        case "📻": return ["radio", "audio"]
        case "🎧": return ["headphones", "audio", "music"]
        case "🎵", "🎶": return ["music", "audio"]
        case "📰": return ["news", "paper"]
        case "🌐": return ["web", "internet", "global"]
        case "📍": return ["location", "pin"]
        case "⚙️": return ["settings", "gear"]
        case "⭐", "🌟", "💫": return ["star", "favorite", "featured"]
        case "🚀": return ["rocket", "launch", "fast"]
        default:
            return [emoji]
        }
    }
}
