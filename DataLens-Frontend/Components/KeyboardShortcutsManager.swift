import SwiftUI
import AppKit

// MARK: - KeyboardShortcutsManager

/// Registers all app-wide keyboard shortcuts using NSEvent local monitor.
/// Publishes `showShortcutsPanel` which triggers the shortcuts overlay.
@MainActor
final class KeyboardShortcutsManager: ObservableObject {

    // MARK: Published

    @Published var showShortcutsPanel: Bool = false

    // Navigation callbacks — set by ContentView
    var onNavigate: ((SidebarItem) -> Void)?
    var onNewDashboard: (() -> Void)?
    var onOpenDashboard: (() -> Void)?
    var onSaveDashboard: (() -> Void)?
    var onExport: (() -> Void)?
    var onFocusSearch: (() -> Void)?
    var onClosePanel: (() -> Void)?

    // MARK: Private

    private var monitor: Any?

    // MARK: - Setup

    func startListening() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event: event)
        }
    }

    func stopListening() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    // MARK: - Event Handler

    private func handle(event: NSEvent) -> NSEvent? {
        let cmd   = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        let key   = event.charactersIgnoringModifiers ?? ""

        // Show shortcuts panel: ? (no modifiers)
        if key == "?" && !cmd {
            Task { @MainActor in self.showShortcutsPanel = true }
            return nil
        }

        // Escape: close shortcuts panel / close open panel
        if event.keyCode == 53 {   // 53 = Escape
            if showShortcutsPanel {
                Task { @MainActor in self.showShortcutsPanel = false }
                return nil
            }
            onClosePanel?()
            return nil
        }

        // Command shortcuts
        if cmd {
            switch key {
            case "n":
                onNewDashboard?()
                return nil
            case "o":
                onOpenDashboard?()
                return nil
            case "s":
                onSaveDashboard?()
                return nil
            case "e":
                onExport?()
                return nil
            case "f":
                onFocusSearch?()
                return nil
            case "1":
                Task { @MainActor in self.onNavigate?(.home) }
                return nil
            case "2":
                Task { @MainActor in self.onNavigate?(.importData) }
                return nil
            case "3":
                Task { @MainActor in self.onNavigate?(.dashboard) }
                return nil
            case "4":
                Task { @MainActor in self.onNavigate?(.charts) }
                return nil
            case "5":
                Task { @MainActor in self.onNavigate?(.aiInsights) }
                return nil
            case "6":
                Task { @MainActor in self.onNavigate?(.export) }
                return nil
            case ",":
                Task { @MainActor in self.onNavigate?(.settings) }
                return nil
            case "z":
                if shift {
                    // Redo — let system handle
                    return event
                }
                // Undo — let system handle
                return event
            default:
                break
            }
        }

        return event
    }
}

// MARK: - ShortcutsOverlayView

/// Linear-style keyboard shortcuts reference panel.
/// Triggered by pressing `?`. Dismissed by Escape or clicking outside.
struct ShortcutsOverlayView: View {

    @ObservedObject var manager: KeyboardShortcutsManager
    @State private var searchText: String = ""
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            // Dimmed backdrop — click to dismiss
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Panel
            VStack(spacing: 0) {
                panelHeader
                searchBar
                Divider().background(ColorPalette.border)
                shortcutsList
            }
            .frame(width: 520, height: 560)
            .background(
                RoundedRectangle(cornerRadius: Constants.Radius.large)
                    .fill(ColorPalette.cards)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Radius.large)
                    .stroke(ColorPalette.border, lineWidth: 1)
            )
            .appShadow(Constants.Shadow.strong)
            .scaleEffect(appeared ? 1.0 : 0.92)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appeared)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: Header

    private var panelHeader: some View {
        HStack {
            Image(systemName: "command.square.fill")
                .foregroundColor(ColorPalette.accent)
                .font(.system(size: 18))
            Text("Keyboard Shortcuts")
                .font(Constants.Typography.headline)
                .foregroundColor(ColorPalette.textPrimary)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Constants.Spacing.md)
        .padding(.vertical, Constants.Spacing.sm + 4)
    }

    // MARK: Search Bar

    private var searchBar: some View {
        HStack(spacing: Constants.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorPalette.textSecondary)
                .font(.system(size: 13))
            TextField("Search shortcuts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(Constants.Typography.body)
                .foregroundColor(ColorPalette.textPrimary)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorPalette.textSecondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Constants.Spacing.md)
        .padding(.vertical, Constants.Spacing.sm)
        .background(ColorPalette.background.opacity(0.5))
    }

    // MARK: Shortcuts List

    private var shortcutsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if searchText.isEmpty {
                    ShortcutSection(title: "Global", icon: "globe", items: Constants.Shortcuts.Global.all)
                    ShortcutSection(title: "Charts", icon: "chart.bar.fill", items: Constants.Shortcuts.Chart.all)
                    ShortcutSection(title: "Dashboard", icon: "rectangle.3.group.fill", items: Constants.Shortcuts.Dashboard.all)
                } else {
                    let all = Constants.Shortcuts.Global.all
                              + Constants.Shortcuts.Chart.all
                              + Constants.Shortcuts.Dashboard.all
                    let filtered = all.filter { $0.0.containsIgnoringCase(searchText) }

                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundColor(ColorPalette.textSecondary.opacity(0.4))
                            Text("No shortcuts matching "\(searchText)"")
                                .font(Constants.Typography.caption)
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Constants.Spacing.xxl)
                    } else {
                        ShortcutSection(title: "Results", icon: "sparkle", items: filtered)
                    }
                }
            }
            .padding(.vertical, Constants.Spacing.sm)
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: Constants.Animation.instant)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            manager.showShortcutsPanel = false
        }
    }
}

// MARK: - Shortcut Section

private struct ShortcutSection: View {
    let title: String
    let icon: String
    let items: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: Constants.Spacing.xs + 2) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ColorPalette.accent)
                Text(title.uppercased())
                    .font(Constants.Typography.eyebrow)
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .padding(.horizontal, Constants.Spacing.md)
            .padding(.top, Constants.Spacing.md)
            .padding(.bottom, Constants.Spacing.xs)

            // Items
            VStack(spacing: 2) {
                ForEach(items, id: \.0) { description, keys in
                    ShortcutRow(description: description, keys: keys)
                }
            }
            .padding(.horizontal, Constants.Spacing.sm)
        }
    }
}

// MARK: - Shortcut Row

private struct ShortcutRow: View {
    let description: String
    let keys: String
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(description)
                .font(Constants.Typography.body)
                .foregroundColor(ColorPalette.textPrimary)
            Spacer()
            KeyBadgeView(keys: keys)
        }
        .padding(.horizontal, Constants.Spacing.sm)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Constants.Radius.small)
                .fill(isHovered ? ColorPalette.accent.opacity(0.08) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Key Badge View

/// Renders a macOS-style rounded key cap badge.
struct KeyBadgeView: View {
    let keys: String

    // Split compound shortcuts like "⌘⇧Z" into individual tokens
    private var tokens: [String] {
        // Keep each character as its own badge, but handle multi-char like "↑↓←→"
        var result: [String] = []
        var current = ""
        for char in keys {
            if char == "+" || char == "−" {
                if !current.isEmpty { result.append(current); current = "" }
                result.append(String(char))
            } else {
                current.append(char)
                if current.count == 1 {
                    result.append(current)
                    current = ""
                }
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.isEmpty ? [keys] : Array(Set(result)).sorted()  // fallback
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach([keys], id: \.self) { key in
                singleBadge(key)
            }
        }
    }

    @ViewBuilder
    private func singleBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(ColorPalette.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: Constants.Radius.small)
                    .fill(ColorPalette.background.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Radius.small)
                    .stroke(ColorPalette.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
    }
}
