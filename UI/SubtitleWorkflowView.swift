import SwiftUI

struct SubtitleWorkflowView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var subtitleURLString: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Subtitle URL", text: $subtitleURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Import Subtitle") {
                    Task {
                        await playerViewModel.importSubtitles(fromURLString: subtitleURLString)
                    }
                }
                .disabled(subtitleURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !playerViewModel.subtitleImportStatusMessage.isEmpty {
                    Text(playerViewModel.subtitleImportStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Subtitle Workflow")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SubtitleWorkflowView(playerViewModel: PlayerViewModel())
}
