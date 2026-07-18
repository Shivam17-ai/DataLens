import SwiftUI

/// ContentView defines the main NavigationSplitView layout of the DataLens application
struct ContentView: View {
    @StateObject private var navigationViewModel = NavigationViewModel()
    
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    var body: some View {
        ZStack {
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
            
            // App wide Toast overlays
            ToastOverlayContainer()
            
            // Full screen onboarding blocker overlay
            if !hasCompletedOnboarding {
                Color.black.opacity(0.65)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                OnboardingView()
                    .frame(width: 600, height: 450)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 12)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }
}

/// A standard, premium dark metallic placeholder view for routes that are planned in subsequent days
struct PlaceholderDetailView: View {
    let title: String
    
    var body: some View {
        let (icon, subtitle) = placeholderInfo(for: title)
        EmptyStateView(
            iconName: icon,
            title: title + AppConstants.Placeholders.screenTitleSuffix,
            subtitle: subtitle
        )
    }
    
    private func placeholderInfo(for title: String) -> (String, String) {
        switch title {
        case AppConstants.Sidebar.charts:
            return ("chart.bar.fill", Constants.EmptyStates.noChartsSubtitle)
        case AppConstants.Sidebar.dashboard:
            return ("rectangle.3.group.fill", Constants.EmptyStates.noDashboardsSubtitle)
        default:
            return ("rectangle.dashed.and.paperclip", AppConstants.Placeholders.comingSoon)
        }
    }
}
