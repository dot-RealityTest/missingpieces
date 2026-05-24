import SwiftUI

// MARK: - Pieces

struct RefreshPiecesButton: View {
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            refreshIcon
        }
        .popoverToolbarButtonStyle()
        .help("Check again")
        .disabled(!isEnabled || isLoading)
    }

    @ViewBuilder
    private var refreshIcon: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "arrow.clockwise")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .contentTransition(.symbolEffect(.replace))
        .symbolEffect(.pulse, isActive: isLoading && !reduceMotion)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.quick), value: isLoading)
    }
}

struct SettingsNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Connectivity (Settings)

struct ConnectivityServiceCard: View {
    let name: String
    let systemImage: String
    let isConnected: Bool
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isConnected ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(SettingsTheme.value)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(SettingsTheme.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            ConnectivityStatusPill(isConnected: isConnected)
        }
    }
}

struct ConnectivityStatusPill: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.orange)
                .frame(width: 5, height: 5)
            Text(isConnected ? "On" : "Off")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }
}

struct ConnectivityTestResultView: View {
    let result: ServiceConnectivityResult?
    var compact: Bool = false

    var body: some View {
        if let result {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: result.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(result.isConnected ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(compact ? 1 : 2)
                    if let detail = result.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 2 : 4)
                            .textSelection(.enabled)
                    }
                    if !compact {
                        Text(result.testedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(compact ? 6 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(result.isConnected ? 0.04 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

// MARK: - Settings (glass theme)

enum SettingsTheme {
    static let label = Color.primary.opacity(0.52)
    static let secondaryLabel = Color.primary.opacity(0.38)
    static let value = Color.primary.opacity(0.62)
}

struct SettingsGlassSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary.opacity(0.42))
                    .padding(.leading, 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .popoverListPanel()
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(SettingsTheme.label)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

struct SettingsPickerRow<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(SettingsTheme.label)
            Spacer(minLength: 8)
            Picker("", selection: $selection, content: content)
                .labelsHidden()
                .frame(maxWidth: 180)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

struct SettingsLabeledRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(SettingsTheme.label)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

struct SettingsActionRow: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                }
                Text(title)
                    .font(.system(size: 12.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(SettingsTheme.label)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

struct SettingsSectionDivider: View {
    var body: some View {
        PopoverGlassStyle.sectionDivider
            .frame(height: 0.5)
            .padding(.leading, 10)
    }
}

struct SettingsTestButton: View {
    let title: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                Text(title)
                    .font(.caption)
                Spacer(minLength: 0)
                if isRunning {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .foregroundStyle(SettingsTheme.label)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
    }
}

// MARK: - Popover section accents

/// Soft pastel tints for grouped follow-up sections (headers + row icons).
enum SectionAccentPalette {
    static let pastels: [Color] = [
        Color(red: 0.50, green: 0.64, blue: 0.88), // periwinkle
        Color(red: 0.64, green: 0.56, blue: 0.86), // lilac
        Color(red: 0.46, green: 0.74, blue: 0.74), // seafoam
        Color(red: 0.90, green: 0.64, blue: 0.58), // peach
        Color(red: 0.54, green: 0.76, blue: 0.60), // sage
        Color(red: 0.88, green: 0.60, blue: 0.70), // rose
        Color(red: 0.90, green: 0.76, blue: 0.50), // butter
        Color(red: 0.56, green: 0.60, blue: 0.84), // dusty indigo
    ]

    static func color(sectionIndex: Int) -> Color {
        guard !pastels.isEmpty else { return .secondary }
        let index = ((sectionIndex % pastels.count) + pastels.count) % pastels.count
        return pastels[index]
    }
}
