import SwiftUI

/// HomeView represents the main overview landing screen of the DataLens application
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    @State private var isButtonHovered = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                // Header (Centered Logo text + Tagline)
                VStack(spacing: 8) {
                    Text(AppConstants.General.appName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(AppConstants.General.tagline)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 60)
                
                // Section and Stat Cards Grid
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppConstants.Stats.sectionHeader)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 24)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        StatCardView(
                            title: AppConstants.Stats.totalDatasets,
                            value: "\(viewModel.totalDatasets)",
                            iconName: AppConstants.Icons.importData,
                            accentColor: AppColors.success
                        )
                        
                        StatCardView(
                            title: AppConstants.Stats.totalCharts,
                            value: "\(viewModel.totalCharts)",
                            iconName: AppConstants.Icons.charts,
                            accentColor: AppColors.success
                        )
                        
                        StatCardView(
                            title: AppConstants.Stats.dashboardsCreated,
                            value: "\(viewModel.dashboardsCreated)",
                            iconName: AppConstants.Icons.dashboard,
                            accentColor: AppColors.success
                        )
                        
                        StatCardView(
                            title: AppConstants.Stats.aiInsightsGenerated,
                            value: "\(viewModel.aiInsightsGenerated)",
                            iconName: AppConstants.Icons.aiInsights,
                            accentColor: AppColors.success
                        )
                    }
                    .padding(.horizontal, 24)
                }
                
                // Get Started Action Button
                Button(action: {
                    viewModel.getStarted {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navigationViewModel.navigate(to: .importData)
                        }
                    }
                }) {
                    Text(AppConstants.General.getStartedButton)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isButtonHovered ? AppColors.accent.opacity(0.8) : AppColors.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: AppColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isButtonHovered = hovering
                    }
                }
                .padding(.top, 24)
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

/// Helper view for displaying individual statistic metric card
struct StatCardView: View {
    let title: String
    let value: String
    let iconName: String
    let accentColor: Color
    
    @State private var isHovered = false
    
    var body: some View {
        CardView(padding: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                // SF Symbol icon matching metric
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(width: 24, height: 24)
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
