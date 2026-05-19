import SwiftUI

/// Ollama-generated summary shown above the follow-up list (full text, no ellipsis).
struct FollowUpSummaryPanel: View {
    let summary: String?
    let error: String?
    let isLoading: Bool
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, isActive: isLoading && !reduceMotion)

                Text("AI summary")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer(minLength: 0)

                if summary != nil || error != nil {
                    Button {
                        PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.gentle) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("Close summary")
                }
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Asking Ollama…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else if let summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, 5)
        .popoverSummaryGlass()
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: isLoading)
    }
}
