import SwiftUI

// MARK: - Sheet chrome

struct SheetHeader: View {
    let title: String
    let subtitle: String?
    var onClose: () -> Void

    init(_ title: String, subtitle: String? = nil, onClose: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

struct SheetFooter: View {
    let primaryTitle: String
    let isPrimaryDisabled: Bool
    var onCancel: () -> Void
    var onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button(primaryTitle, action: onPrimary)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isPrimaryDisabled)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Form

struct FormField<Content: View>: View {
    let label: String
    let icon: String?
    @ViewBuilder var content: Content

    init(_ label: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            } icon: {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
            }
            content
        }
    }
}

struct FormCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

// MARK: - Pieces

struct RefreshPiecesButton: View {
    let isLoading: Bool
    let isEnabled: Bool
    var label: String = "Refresh"
    var style: Style = .bordered
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Style {
        case bordered
        case toolbar
        case prominent
    }

    var body: some View {
        Group {
            switch style {
            case .toolbar:
                Button(action: action) {
                    refreshIcon
                }
                .popoverToolbarButtonStyle()
                .help("Check again")
            case .bordered:
                Button(action: action) {
                    Label {
                        Text(label)
                    } icon: {
                        refreshIcon
                    }
                }
                .buttonStyle(.bordered)
            case .prominent:
                Button(action: action) {
                    Label {
                        Text(label)
                    } icon: {
                        refreshIcon
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
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
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

struct SettingsTestButton: View {
    let title: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text(title)
                Spacer(minLength: 0)
                if isRunning {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isRunning)
    }
}
