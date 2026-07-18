import SwiftUI

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
            
            Divider()
                .background(ColorPalette.border)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            // Navigation Links Stack
            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarItemButton(
                        item: item,
                        isSelected: viewModel.selectedItem == item
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
                    // Settings action trigger placeholder
                }
                SidebarBottomButton(iconName: "questionmark.circle.fill", title: Constants.Sidebar.help) {
                    // Help action trigger placeholder
                }
                
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
}

/// A custom, highly responsive button for each navigation item in the Sidebar
struct SidebarItemButton: View {
    let item: SidebarItem
    let isSelected: Bool
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
            }
            .padding(.vertical, 8)
            .padding(.leading, 8) // subtle left padding for nav items
            .padding(.trailing, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                        ? ColorPalette.accent.opacity(0.15)
                        : (isHovered ? ColorPalette.accent.opacity(0.08) : Color.clear)
                    )
            )
            .contentShape(Rectangle()) // Makes the whole area click-sensitive
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                isHovered = hovering
            }
        }
    }
}

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
