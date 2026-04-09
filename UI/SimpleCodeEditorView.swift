import SwiftUI

struct SimpleCodeEditorView: View {
    @Binding var text: String
    var placeholder: String

    private var lineCount: Int {
        max(text.components(separatedBy: "\n").count, 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(1...lineCount, id: \.self) { line in
                        Text("\(line)")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
            .frame(width: 44)
            .background(Color.secondary.opacity(0.08))

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}
