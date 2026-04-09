import SwiftUI

struct WaveformProgressView: View {
    let progress: Double
    let seed: String
    var barCount: Int = 44

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let count = max(barCount, 8)
            let spacing = width * 0.004
            let totalSpacing = spacing * CGFloat(count - 1)
            let barWidth = max((width - totalSpacing) / CGFloat(count), 1)
            let clampedProgress = max(0, min(progress, 1))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    let normalizedHeight = barHeight(for: index, seed: seed)
                    let filledThreshold = Double(index + 1) / Double(count)
                    let isFilled = filledThreshold <= clampedProgress

                    RoundedRectangle(cornerRadius: barWidth * 0.42)
                        .fill(isFilled ? Color.cyan : Color.white.opacity(0.2))
                        .frame(width: barWidth, height: max(height * normalizedHeight, 2))
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(width: width, height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func barHeight(for index: Int, seed: String) -> CGFloat {
        var hash = UInt64(bitPattern: Int64(seed.hashValue ^ (index &* 1_103_515_245)))
        hash ^= hash >> 33
        hash &*= 0xff51afd7ed558ccd
        hash ^= hash >> 33
        hash &*= 0xc4ceb9fe1a85ec53
        hash ^= hash >> 33

        let unit = Double(hash % 10_000) / 10_000.0
        let shaped = 0.18 + (unit * 0.82)
        return CGFloat(shaped)
    }
}
