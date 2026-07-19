import SwiftUI

/// ChartContainer wraps visualization components in a card with a header,
/// share export actions, a layout state manager, legends, and brand watermarks.
struct ChartContainer<Content: View>: View {
    let title: String
    let config: ChartConfig
    let seriesList: [String]
    let colors: [Color]
    let isEmpty: Bool
    let isLoading: Bool
    @Binding var highlightedSeries: Set<String>
    let onExport: () -> Void
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Title & Export Share Button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: config.chartType.iconName)
                        .font(.system(size: 13))
                        .foregroundColor(ColorPalette.success)
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: onExport) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .bold))
                        Text("Export")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(ColorPalette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorPalette.accent.opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
                .help("Export Chart to PNG image")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ColorPalette.sidebar.opacity(0.4))
            .overlay(
                VStack { Spacer(); Rectangle().fill(ColorPalette.border).frame(height: 1) }
            )
            
            // Visualization Content Canvas
            ZStack {
                ColorPalette.background.opacity(0.2)
                
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.success))
                        Text("Aggregating dataset metrics...")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEmpty {
                    EmptyStateView(
                        iconName: "chart.bar.xaxis",
                        title: Constants.EmptyStates.noChartsTitle,
                        subtitle: "Configure the X-Axis and Y-Axis columns in the top toolbar to map chart items."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // Resizable chart canvas fills frame
                        content()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(16)
                        
                        if config.showLegend && !seriesList.isEmpty {
                            LegendView(
                                seriesList: seriesList,
                                colors: colors,
                                highlightedSeries: $highlightedSeries
                            )
                        }
                    }
                }
                
                // Branding watermark in the bottom-right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("DataLens")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(ColorPalette.textSecondary.opacity(0.12))
                            .padding(12)
                    }
                }
            }
        }
        .background(ColorPalette.cardGradient)
        .cornerRadius(Constants.Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(ColorPalette.border, lineWidth: 1)
        )
    }
}
