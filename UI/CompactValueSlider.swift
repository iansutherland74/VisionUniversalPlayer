import SwiftUI

struct CompactValueSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var accentColor: Color = .cyan
    var trackHeight: CGFloat = 28
    var showScale = true
    var valueLabel: ((Double) -> String)? = nil

    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let normalizedValue = normalized(value)
            let width = max(proxy.size.width, 1)
            let leadingWidth = width * normalizedValue

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: trackHeight)

                if showScale {
                    scaleMarks
                        .padding(.horizontal, 12)
                }

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.92), accentColor.opacity(0.42)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(leadingWidth, 24), height: trackHeight)
                    .overlay(alignment: .trailing) {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(isDragging ? 0.98 : 0.92))
                            .frame(width: isDragging ? 14 : 12, height: isDragging ? trackHeight - 4 : trackHeight - 8)
                            .padding(.trailing, 4)
                            .shadow(color: accentColor.opacity(0.35), radius: 8, y: 0)
                    }

                if let valueLabel {
                    Text(valueLabel(value))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.34), in: Capsule())
                        .offset(x: labelOffset(width: width, normalized: normalizedValue), y: -trackHeight * 0.9)
                        .opacity(isDragging ? 1 : 0.85)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        updateValue(at: gesture.location.x, width: width)
                    }
                    .onEnded { gesture in
                        updateValue(at: gesture.location.x, width: width)
                        isDragging = false
                    }
            )
        }
        .frame(height: trackHeight + 10)
    }

    private var scaleMarks: some View {
        HStack(spacing: 0) {
            ForEach(0..<13, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.28 : 0.14))
                    .frame(width: 1, height: index.isMultiple(of: 3) ? 9 : 5)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: trackHeight)
    }

    private func updateValue(at locationX: CGFloat, width: CGFloat) {
        let progress = min(max(locationX / width, 0), 1)
        let rawValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(progress)
        if let step, step > 0 {
            let steppedValue = (rawValue / step).rounded() * step
            value = min(max(steppedValue, range.lowerBound), range.upperBound)
        } else {
            value = rawValue
        }
    }

    private func normalized(_ currentValue: Double) -> Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        let clamped = min(max(currentValue, range.lowerBound), range.upperBound)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func labelOffset(width: CGFloat, normalized: Double) -> CGFloat {
        let rawOffset = (width * normalized) - (width / 2)
        return min(max(rawOffset, -width / 2 + 32), width / 2 - 32)
    }
}

#Preview {
    VStack(spacing: 24) {
        CompactValueSlider(value: .constant(0.35), range: 0...1)
            .frame(height: 40)

        CompactValueSlider(
            value: .constant(1.2),
            range: 0.3...2.5,
            accentColor: .mint,
            valueLabel: { String(format: "%.2fx", $0) }
        )
        .frame(height: 40)
    }
    .padding()
    .background(Color.black)
}
