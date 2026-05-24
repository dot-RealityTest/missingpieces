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

// MARK: - Settings

enum SettingsTheme {
    static let label = Color.primary.opacity(0.52)
    static let secondaryLabel = Color.primary.opacity(0.38)
    static let value = Color.primary.opacity(0.62)
}

struct SettingsGlassSection<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .popoverListPanel()
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

// MARK: - Popover section accents

/// Soft pastel tints for grouped follow-up sections (row icons only).
enum SectionAccentPalette {
    static let pastels: [Color] = [
        Color(red: 0.50, green: 0.64, blue: 0.88),
        Color(red: 0.64, green: 0.56, blue: 0.86),
        Color(red: 0.46, green: 0.74, blue: 0.74),
    ]

    static func color(sectionIndex: Int) -> Color {
        pastels[sectionIndex % pastels.count]
    }
}
