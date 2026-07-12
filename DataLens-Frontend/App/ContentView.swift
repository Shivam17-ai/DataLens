import SwiftUI

/// ContentView defines the main NavigationSplitView layout of the DataLens application
struct ContentView: View {
    @StateObject private var navigationViewModel = NavigationViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: navigationViewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            Group {
                switch navigationViewModel.selectedItem {
                case .home:
                    HomeView(navigationViewModel: navigationViewModel)
                case .importData:
                    ImportView(navigationViewModel: navigationViewModel)
                case .dashboard:
                    PlaceholderDetailView(title: AppConstants.Sidebar.dashboard)
                case .charts:
                    PlaceholderDetailView(title: AppConstants.Sidebar.charts)
                case .aiInsights:
                    PlaceholderDetailView(title: AppConstants.Sidebar.aiInsights)
                case .export:
                    PlaceholderDetailView(title: AppConstants.Sidebar.export)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

/// A standard, premium dark metallic placeholder view for routes that are planned in subsequent days
struct PlaceholderDetailView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.dashed.and.paperclip")
                .font(.system(size: 48))
                .foregroundColor(AppColors.accent)
                .shadow(color: AppColors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text(title + AppConstants.Placeholders.screenTitleSuffix)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text(AppConstants.Placeholders.descriptionPrefix + title + ".\n" + AppConstants.Placeholders.comingSoon)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}
