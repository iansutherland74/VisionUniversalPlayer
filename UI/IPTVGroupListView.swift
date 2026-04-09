import SwiftUI

struct IPTVGroupListView: View {
    @ObservedObject var store: IPTVStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedGroup?.id },
            set: { id in
                store.selectedGroup = store.groups.first(where: { $0.id == id })
            }
        )) {
            ForEach(store.groups) { group in
                HStack {
                    Text(group.name)
                    Spacer()
                    Text("\(group.channels.count)")
                        .foregroundStyle(.secondary)
                }
                .tag(group.id)
            }
        }
    }
}
