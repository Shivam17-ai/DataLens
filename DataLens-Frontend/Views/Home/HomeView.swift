import SwiftUI

/// HomeView — the animated, premium landing screen of DataLens
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var dataViewModel: DataViewModel
    
    // Staggered card animation state
    @State private var cardsAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // MARK: – Hero Header
                HeroHeaderView(navigationViewModel: navigationViewModel)
                
                // MARK: – Stats Section
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppConstants.Stats.sectionHeader)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        let statItems: [(String, String, String, Color, Double)] = [
                            (AppConstants.Stats.totalDatasets,        "\(viewModel.totalDatasets)",       AppConstants.Icons.importData, ColorPalette.success, 0.0),
                            (AppConstants.Stats.totalCharts,          "\(viewModel.totalCharts)",         AppConstants.Icons.charts,     ColorPalette.accent,  0.1),
                            (AppConstants.Stats.dashboardsCreated,    "\(viewModel.dashboardsCreated)",   AppConstants.Icons.dashboard,  ColorPalette.warning, 0.2),
                            (AppConstants.Stats.aiInsightsGenerated,  "\(viewModel.aiInsightsGenerated)", AppConstants.Icons.aiInsights, ColorPalette.success, 0.3)
                        ]
                        ForEach(statItems, id: \.0) { title, value, icon, color, delay in
                            StatCardView(
                                title: title,
                                value: value,
                                iconName: icon,
                                accentColor: color
                            )
                            .opacity(cardsAppeared ? 1 : 0)
                            .offset(y: cardsAppeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75).delay(delay),
                                value: cardsAppeared
                            )
                        }
                    }
                }
                .padding(Constants.Layout.outerPadding)
                .onAppear { cardsAppeared = true }
                
                Divider()
                    .background(ColorPalette.border)
                    .padding(.horizontal, Constants.Layout.outerPadding)
                
                // MARK: – Quick Actions
                QuickActionsSection(navigationViewModel: navigationViewModel)
                    .padding(Constants.Layout.outerPadding)
                
                Divider()
                    .background(ColorPalette.border)
                    .padding(.horizontal, Constants.Layout.outerPadding)
                
                // MARK: – Recent Files
                RecentFilesSection(navigationViewModel: navigationViewModel)
                    .padding(Constants.Layout.outerPadding)
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}

// MARK: - Hero Header

struct HeroHeaderView: View {
    @ObservedObject var navigationViewModel: NavigationViewModel
    @State private var gradientAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    ColorPalette.accent.opacity(0.55),
                    ColorPalette.background
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "square.fill.and.line.down.and.arrow.up")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(ColorPalette.success)
                    
                    Text(Constants.App.name)
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundColor(ColorPalette.textPrimary)
                }
                
                Text(Constants.App.tagline)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(ColorPalette.textSecondary)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: Constants.Animation.standard)) {
                        navigationViewModel.navigate(to: .importData)
                    }
                }) {
                    Text(Constants.App.getStartedButton)
                        .padding(.horizontal, 24)
                }
                .primaryStyle()
                .padding(.top, 8)
            }
            .padding(.vertical, 48)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @ObservedObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var dataViewModel: DataViewModel
    
    let actions: [(String, String, Color, () -> Void)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
            
            HStack(spacing: 16) {
                QuickActionButton(icon: "doc.text.fill", label: "Import CSV", color: ColorPalette.success) {
                    navigationViewModel.navigate(to: .importData)
                }
                QuickActionButton(icon: "tablecells.fill", label: "Import Excel", color: Color(hex: "#34D399")) {
                    navigationViewModel.navigate(to: .importData)
                }
                QuickActionButton(icon: "chart.bar.fill", label: "View Charts", color: ColorPalette.accent) {
                    navigationViewModel.navigate(to: .charts)
                }
                QuickActionButton(icon: "rectangle.3.group.fill", label: "Dashboard", color: ColorPalette.warning) {
                    navigationViewModel.navigate(to: .dashboard)
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isHovered ? 0.25 : 0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(isHovered ? ColorPalette.cards : ColorPalette.sidebar)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(isHovered ? color.opacity(0.6) : ColorPalette.border, lineWidth: 1)
            )
            .offset(y: isHovered ? -3 : 0)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: Constants.Animation.instant)) { isHovered = h }
        }
    }
}

// MARK: - Recent Files Section

struct RecentFilesSection: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Files")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                if !dataViewModel.recentFiles.isEmpty {
                    BadgeView(style: .count(dataViewModel.recentFiles.count), color: ColorPalette.success)
                }
            }
            
            if dataViewModel.recentFiles.isEmpty {
                EmptyStateView(
                    iconName: "doc.badge.clock",
                    title: "No Recent Files",
                    subtitle: "Files you import will appear here for quick access.",
                    actionButtonTitle: "Import a File",
                    action: { navigationViewModel.navigate(to: .importData) }
                )
                .frame(height: 200)
                .background(ColorPalette.cards.opacity(0.5))
                .cornerRadius(Constants.Layout.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                        .stroke(ColorPalette.border, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(dataViewModel.recentFiles) { file in
                        RecentFileRow(file: file) {
                            dataViewModel.importFile(url: file.fileURL)
                            navigationViewModel.navigate(to: .importData)
                        }
                    }
                }
            }
        }
    }
}

struct RecentFileRow: View {
    let file: RecentFile
    let action: () -> Void
    @State private var isHovered = false
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // File type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(file.fileType == .csv ? ColorPalette.success.opacity(0.15) : Color(hex: "#34D399").opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: file.fileType.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(file.fileType == .csv ? ColorPalette.success : Color(hex: "#34D399"))
                }
                
                // File info
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)
                        .lineLimit(1)
                    Text("\(file.rowCount.formatted()) rows  ·  \(dateFormatter.string(from: file.importDate))")
                        .font(.system(size: 11))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                Spacer()
                
                // Type badge
                BadgeView(style: .label(file.fileType.rawValue),
                          color: file.fileType == .csv ? ColorPalette.success : Color(hex: "#34D399"))
                
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14))
                    .foregroundColor(isHovered ? ColorPalette.success : ColorPalette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? ColorPalette.cards : ColorPalette.sidebar)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? ColorPalette.accent.opacity(0.6) : ColorPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: Constants.Animation.instant)) { isHovered = h }
        }
    }
}

// MARK: - Stat Card

struct StatCardView: View {
    let title: String
    let value: String
    let iconName: String
    let accentColor: Color
    
    var body: some View {
        CardView {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }
        }
    }
}
