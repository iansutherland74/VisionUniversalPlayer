import SwiftUI

struct PlaybackAdvisorLogView: View {
    let segments: [AdvisorySegment]
    let partialText: String
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Advisor Log", systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                Button("Clear") {
                    onClear()
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.85))
            }

            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(segments) { segment in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(segment.text)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.95))

                                    Text(segment.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

                                Spacer(minLength: 32)
                            }
                            .id(segment.id)
                        }

                        if !partialText.isEmpty {
                            HStack {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.mini)
                                    Text(partialText)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))

                                Spacer(minLength: 32)
                            }
                            .id("partial")
                        }
                    }
                }
                .onChange(of: segments.count) { _, _ in
                    if let last = segments.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            reader.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: partialText) { _, _ in
                    if !partialText.isEmpty {
                        withAnimation(.easeOut(duration: 0.2)) {
                            reader.scrollTo("partial", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: 160)
        }
        .padding(10)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}
