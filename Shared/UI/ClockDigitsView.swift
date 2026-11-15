import SwiftUI

/// "12:34:56" ＋ 琥珀色で小さめの ".78"
struct ClockDigitsView: View {
    let parts: ClockParts
    var size: CGFloat
    var showsFraction = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.main)
                .font(.system(size: size, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.text)
            if showsFraction {
                Text(parts.fraction)
                    .font(.system(size: size * 0.64, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.accent)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(parts.hour)時\(parts.minute)分\(parts.second)秒")
    }
}
