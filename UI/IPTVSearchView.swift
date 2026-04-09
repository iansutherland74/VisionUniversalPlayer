import SwiftUI

struct IPTVSearchView: View {
    @ObservedObject var store: IPTVStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search channels, groups, tvg-name", text: $store.searchText)
                .textFieldStyle(.roundedBorder)

            if store.searchText.isEmpty == false {
                Text("\(store.channels.count) result(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
