import SwiftUI

/// Ollama summary chip — one tiny line; tap to expand the task list only.
struct FollowUpSummaryPanel: View {
    let brief: String?
    let followUpTitles: [String]
    let isExpanded: Bool
    let isExpandable: Bool
    let error: String?
    let isLoading: Bool
    let onToggleExpand: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 6 : 0) {
            headerRow

            if isLoading {
                loadingRow
            } else if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let brief {
                summaryBody(brief: brief)
            }
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, 5)
        .popoverSummaryGlass()
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: isLoading)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: isExpanded)
    }

    private var headerRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundStyle(.purple.opacity(0.85))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, isActive: isLoading && !reduceMotion)

            if !isLoading, brief == nil, error == nil {
                Text("AI summary")
                    .font(.caption2)
                    .foregroundStyle(Color.primary.opacity(0.38))
            }

            Spacer(minLength: 0)

            if brief != nil || error != nil {
                Button {
                    PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.gentle) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
                .buttonStyle(.borderless)
                .help("Close summary")
            }
        }
    }

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("One sec…")
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.42))
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func summaryBody(brief: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                guard isExpandable else { return }
                PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.gentle) {
                    onToggleExpand()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(brief)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.68))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isExpandable {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.primary.opacity(0.32))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isExpandable)
            .help(isExpandable ? (isExpanded ? "Hide list" : "Show all tasks") : brief)

            if isExpanded, !followUpTitles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(followUpTitles, id: \.self) { title in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(Color.primary.opacity(0.22))
                                .frame(width: 4, height: 4)
                                .padding(.top, 5)
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(Color.primary.opacity(0.52))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 1)
    }
}
