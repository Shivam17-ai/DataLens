import SwiftUI

// MARK: - SidebarView

/// SidebarView represents the navigation panel on the left of the main NavigationSplitView.
struct SidebarView: View {
    @ObservedObject var viewModel: NavigationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding Logo & Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "square.fill.and.line.down.and.arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ColorPalette.success)
                    
                    Text(Constants.App.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Spacer()
                }
                
                Text("Version \(Constants.App.version)")
                    .font(.system(size: 10))
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .accessibilityElement(children: .combine)
            
            Divider()
                .background(ColorPalette.border)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            // Navigation Links Stack
            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
                    SidebarItemButton(
                        item: item,
                        isSelected: viewModel.selectedItem == item,
                        shortcutHint: shortcutHint(for: item)
                    ) {
                        withAnimation(.easeInOut(duration: Constants.Animation.standard)) {
                            viewModel.navigate(to: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            Divider()
                .background(ColorPalette.border)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            // Bottom of sidebar utilities
            VStack(alignment: .leading, spacing: 12) {
                SidebarBottomButton(iconName: "gearshape.fill", title: Constants.Sidebar.settings) {
                    withAnimation(.easeInOut(duration: Constants.Animation.standard)) {
                        viewModel.navigate(to: .settings)
                    }
                }
                .accessibilityLabel("Open Settings screen")
                .accessibilityHint("Keyboard shortcut command comma")
                
                SidebarBottomButton(iconName: "questionmark.circle.fill", title: Constants.Sidebar.help) {
                    // Help trigger
                    if let url = URL(string: Constants.App.githubURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .accessibilityLabel("Open Help documentation")
                
                Text("\(Constants.App.name) v\(Constants.App.version) (\(Constants.App.buildNumber))")
                    .font(.system(size: 9))
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
        .background(ColorPalette.sidebar)
    }
    
    private func shortcutHint(for item: SidebarItem) -> String? {
        switch item {
        case .home:       return "⌘1"
        case .importData: return "⌘2"
        case .dashboard:  return "⌘3"
        case .charts:     return "⌘4"
        case .aiInsights: return "⌘5"
        case .export:     return "⌘6"
        default:          return nil
        }
    }
}

// MARK: - SidebarItemButton

/// A custom, highly responsive button for each navigation item in the Sidebar
struct SidebarItemButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let shortcutHint: String?
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Left border accent strip
                Rectangle()
                    .fill(isSelected ? ColorPalette.accent : Color.clear)
                    .frame(width: 3, height: 16)
                    .cornerRadius(1.5)
                
                // Icon representation
                Image(systemName: item.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? ColorPalette.success : (isHovered ? ColorPalette.textPrimary : ColorPalette.textSecondary))
                    .frame(width: 20, alignment: .center)
                
                // Label title
                Text(item.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : (isHovered ? ColorPalette.textPrimary : ColorPalette.textSecondary))
                
                Spacer()
                
                // Keyboard shortcut hint
                if let hint = shortcutHint {
                    Text(hint)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(ColorPalette.background.opacity(0.4))
                        .cornerRadius(3)
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 8)
            .padding(.trailing, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                        ? ColorPalette.accent.opacity(0.15)
                        : (isHovered ? ColorPalette.accent.opacity(0.08) : Color.clear)
                    )
            )
            .focusBorder(isFocused: isSelected, radius: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("Go to \(item.title)")
        .accessibilityHint(shortcutHint != nil ? "Keyboard shortcut \(shortcutHint!)" : "")
    }
}

// MARK: - SidebarBottomButton

/// SidebarBottomButton presents gear settings and help buttons at the footer
struct SidebarBottomButton: View {
    let iconName: String
    let title: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? ColorPalette.success : ColorPalette.textSecondary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? ColorPalette.textPrimary : ColorPalette.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                isHovered = h
            }
        }
    }
}
