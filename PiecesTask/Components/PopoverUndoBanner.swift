import SwiftUI

struct PopoverUndoBanner: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button("Undo", action: onUndo)
                .font(.caption2)
                .fontWeight(.semibold)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(PopoverGlassStyle.usesLiquidGlass ? 0.08 : 0.06))
    }
}
