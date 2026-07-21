import SwiftUI

/// ChartsView represents the main workspace for data visualization.
/// It features a sidebar for selecting chart types, and a main canvas area
/// with toolbar selectors (X/Y axes, title, theme, auto-sort) and the active chart.
struct ChartsView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @EnvironmentObject var toastManager: ToastManager
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    @StateObject private var chartViewModel: ChartViewModel
    @State private var highlightedSeries: Set<String> = []
    
    init(navigationViewModel: NavigationViewModel, dataViewModel: DataViewModel) {
        self.navigationViewModel = navigationViewModel
        self._chartViewModel = StateObject(wrappedValue: ChartViewModel(dataViewModel: dataViewModel))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            
            // MARK: - Left Panel: Chart Selector (240pt)
            VStack(alignment: .leading, spacing: 0) {
                Text("Chart Library")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                Divider()
                    .background(ColorPalette.border)
                    
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ChartTypeSection(
                            title: "Basic Charts",
                            types: [.bar, .horizontalBar, .line, .area, .pie, .donut],
                            selectedType: $chartViewModel.chartConfig.chartType
                        )
                        
                        ChartTypeSection(
                            title: "Statistical Charts",
                            types: [.scatter, .bubble, .histogram, .boxPlot],
                            selectedType: $chartViewModel.chartConfig.chartType
                        )
                        
                        ChartTypeSection(
                            title: "Advanced Charts",
                            types: [.heatmap, .treemap, .waterfall, .funnel, .gauge],
                            selectedType: $chartViewModel.chartConfig.chartType
                        )
                    }
                    .padding(16)
                }
            }
            .frame(width: 240)
            .background(ColorPalette.sidebar)
            .overlay(
                Rectangle()
                    .fill(ColorPalette.border)
                    .frame(width: 1),
                alignment: .trailing
            )
            
            // MARK: - Right Panel: Toolbar and Canvas
            VStack(spacing: 0) {
                // Toolbar
                ChartsToolbar(chartViewModel: chartViewModel)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(ColorPalette.sidebar.opacity(0.6))
                    .overlay(
                        VStack { Spacer(); Rectangle().fill(ColorPalette.border).frame(height: 1) }
                    )
                
                // Canvas Area
                ZStack {
                    ColorPalette.background
                        .edgesIgnoringSafeArea(.all)
                    
                    if dataViewModel.currentDataSet == nil {
                        EmptyStateView(
                            iconName: "square.and.arrow.down",
                            title: Constants.EmptyStates.noDataTitle,
                            subtitle: Constants.EmptyStates.noDataSubtitle,
                            actionButtonTitle: "Import Data",
                            action: {
                                withAnimation {
                                    navigationViewModel.navigate(to: .importData)
                                }
                            }
                        )
                    } else {
                        // Interactive Chart Container
                        ChartContainer(
                            title: chartViewModel.chartConfig.title,
                            config: chartViewModel.chartConfig,
                            seriesList: chartViewModel.chartData.seriesNames,
                            colors: chartViewModel.chartConfig.colorTheme.colors,
                            isEmpty: chartViewModel.chartData.isEmpty,
                            isLoading: chartViewModel.isLoading,
                            highlightedSeries: $highlightedSeries,
                            onExport: {
                                chartViewModel.exportChart(view: currentChartView)
                            }
                        ) {
                            currentChartView
                        }
                        .padding(16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Bind the view model's toast notifier to our shared toast manager
            chartViewModel.onShowToast = { msg, type in
                toastManager.show(message: msg, type: type)
            }
            
            // Run aggregation if dataset is already loaded
            if let dataset = dataViewModel.currentDataSet {
                chartViewModel.prepareChartData(dataset: dataset, config: chartViewModel.chartConfig)
            }
        }
        .onChange(of: chartViewModel.chartConfig.chartType) { newType in
            // Keep selected chart type state updated in sync with config changes
            chartViewModel.selectedChartType = newType
            if let dataset = dataViewModel.currentDataSet {
                chartViewModel.prepareChartData(dataset: dataset, config: chartViewModel.chartConfig)
            }
        }
    }
    
    // MARK: - Current Chart Dispatcher View
    
    @ViewBuilder
    private var currentChartView: some View {
        switch chartViewModel.chartConfig.chartType {
        case .bar:
            BarChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries
            )
        case .horizontalBar:
            HorizontalBarChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries
            )
        case .line:
            LineChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
        case .area:
            AreaChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
        case .pie:
            PieChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
        case .donut:
            DonutChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
        default:
            EmptyStateView(
                iconName: chartViewModel.chartConfig.chartType.iconName,
                title: "\(chartViewModel.chartConfig.chartType.rawValue) Chart",
                subtitle: "Visualization layout is coming soon. Test with Bar, Horizontal Bar, Line, Area, Pie, or Donut chart options."
            )
        }
    }
}

// MARK: - Chart Selector Section Group

struct ChartTypeSection: View {
    let title: String
    let types: [ChartType]
    @Binding var selectedType: ChartType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.leading, 4)
            
            VStack(spacing: 4) {
                ForEach(types) { type in
                    Button(action: {
                        withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                            selectedType = type
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 12))
                                .frame(width: 16)
                            Text(type.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(selectedType == type ? .white : ColorPalette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedType == type ? ColorPalette.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Charts Toolbar Configurator

struct ChartsToolbar: View {
    @ObservedObject var chartViewModel: ChartViewModel
    @EnvironmentObject var dataViewModel: DataViewModel
    
    private var isLineOrArea: Bool {
        chartViewModel.chartConfig.chartType == .line || chartViewModel.chartConfig.chartType == .area
    }
    
    private var isPieOrDonut: Bool {
        chartViewModel.chartConfig.chartType == .pie || chartViewModel.chartConfig.chartType == .donut
    }
    
    var body: some View {
        let columns = dataViewModel.currentDataSet?.visibleColumns ?? []
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Chart Title Input
                ToolbarField(label: "Chart Title") {
                    TextField("Untitled Chart", text: $chartViewModel.chartConfig.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorPalette.cards)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                        .frame(width: 160)
                }
                
                ToolbarDivider()
                
                // X-Axis Selector
                ToolbarField(label: "X-Axis (Categories)") {
                    Picker("", selection: $chartViewModel.chartConfig.xAxisColumn) {
                        Text("Select Column").tag(String?.none)
                        ForEach(columns) { col in
                            Text(col.name).tag(String?.some(col.name))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)
                }
                
                // Y-Axis Selector
                ToolbarField(label: "Y-Axis (Numeric)") {
                    Picker("", selection: $chartViewModel.chartConfig.yAxisColumn) {
                        Text("Select Column").tag(String?.none)
                        ForEach(columns) { col in
                            Text(col.name).tag(String?.some(col.name))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)
                }
                
                // Color Theme Picker
                ToolbarField(label: "Theme") {
                    Picker("", selection: $chartViewModel.chartConfig.colorTheme) {
                        ForEach(ColorTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 110)
                }
                
                ToolbarDivider()
                
                // ── Line / Area only controls ──────────────────────────
                if isLineOrArea {
                    // Interpolation mode toggle
                    ToolbarField(label: "Line Style") {
                        Picker("", selection: $chartViewModel.chartConfig.interpolationMode) {
                            ForEach(LineInterpolation.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                    }
                    
                    // Series grouping column (multi-series breakdown)
                    ToolbarField(label: "Group By") {
                        Picker("", selection: $chartViewModel.chartConfig.seriesColumn) {
                            Text("None").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    // Reference lines toggle
                    ToolbarField(label: "Ref. Lines") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showReferenceLines)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Area-only controls ─────────────────────────────────
                if chartViewModel.chartConfig.chartType == .area {
                    ToolbarDivider()
                    
                    ToolbarField(label: "Stack Mode") {
                        Picker("", selection: $chartViewModel.chartConfig.stackMode) {
                            ForEach(AreaStackMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    ToolbarField(label: "Baseline") {
                        Picker("", selection: $chartViewModel.chartConfig.baselineMode) {
                            ForEach(AreaBaseline.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
                
                // ── Pie / Donut only controls ──────────────────────────
                if isPieOrDonut {
                    // Sort order configuration
                    ToolbarField(label: "Sort Slices") {
                        Picker("", selection: $chartViewModel.chartConfig.sliceSortOrder) {
                            ForEach(SliceSortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    
                    // Max slices constraint
                    ToolbarField(label: "Max Slices") {
                        Picker("", selection: $chartViewModel.chartConfig.maxSlices) {
                            ForEach([5, 8, 12, 16, 20, 24], id: \.self) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    
                    // Filter small slices (<2%)
                    ToolbarField(label: "Group Small (<2%)") {
                        Toggle("", isOn: $chartViewModel.chartConfig.groupSmallSlices)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    // Explode all slices
                    ToolbarField(label: "Explode All") {
                        Toggle("", isOn: $chartViewModel.chartConfig.explodeAll)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    // Semi Circle mode
                    ToolbarField(label: "Semi-Circle") {
                        Toggle("", isOn: $chartViewModel.chartConfig.semiCircleMode)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    ToolbarDivider()
                    
                    // Comparison Column Selection
                    ToolbarField(label: "Compare With") {
                        Picker("", selection: $chartViewModel.chartConfig.comparisonColumn) {
                            Text("None").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                
                // ── Donut-only center text config ──────────────────────
                if chartViewModel.chartConfig.chartType == .donut {
                    ToolbarDivider()
                    
                    ToolbarField(label: "Hole Center Text") {
                        Picker("", selection: $chartViewModel.chartConfig.donutCenterText) {
                            ForEach(DonutCenterContent.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                
                // ── Bar / Horizontal Bar only controls ─────────────────
                if chartViewModel.chartConfig.chartType == .horizontalBar {
                    ToolbarField(label: "Sorting") {
                        Toggle("Rank ↓", isOn: $chartViewModel.chartConfig.autoSort)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ColorPalette.textPrimary)
                    }
                }
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 4)
        }
        // Trigger re-aggregation on any axis / config change
        .onChange(of: chartViewModel.chartConfig.xAxisColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.yAxisColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.seriesColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.colorTheme)  { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.stackMode)   { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.sliceSortOrder) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.maxSlices)   { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.groupSmallSlices) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.semiCircleMode) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.comparisonColumn) { _ in recompute() }
    }
    
    private func recompute() {
        if let dataset = dataViewModel.currentDataSet {
            chartViewModel.prepareChartData(dataset: dataset, config: chartViewModel.chartConfig)
        }
    }
}

// MARK: - Toolbar Field Helper

/// Small labelled column used inside ChartsToolbar.
private struct ToolbarField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
            content()
        }
    }
}

/// Thin vertical separator between toolbar groups.
private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(ColorPalette.border)
            .frame(width: 1, height: 36)
            .opacity(0.6)
    }
}
