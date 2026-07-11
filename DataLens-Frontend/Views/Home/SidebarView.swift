import SwiftUI

/// SidebarView represents the navigation panel on the left of the main NavigationSplitView
struct SidebarView: View {
    @ObservedObject var viewModel: NavigationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding Logo & Header
            HStack(spacing: 10) {
                Image(systemName: "square.fill.and.line.down.and.arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.success)
                
                Text(AppConstants.General.appName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            
            // Navigation Links Stack
            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarItemButton(
                        item: item,
                        isSelected: viewModel.selectedItem == item
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.navigate(to: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
        .background(AppColors.sidebar)
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
                    .fill(isSelected ? AppColors.accent : Color.clear)
                    .frame(width: 3, height: 16)
                    .cornerRadius(1.5)
                
                // Icon representation
                Image(systemName: item.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.textPrimary : (isHovered ? AppColors.textPrimary : AppColors.textSecondary))
                    .frame(width: 20, alignment: .center)
                
                // Label title
                Text(item.title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected ? AppColors.textPrimary : (isHovered ? AppColors.textPrimary : AppColors.textSecondary))
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.trailing, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                        ? AppColors.accent.opacity(0.2)
                        : (isHovered ? Color.white.opacity(0.04) : Color.clear)
                    )
            )
            .contentShape(Rectangle()) // Makes the whole area click-sensitive
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
