import SwiftUI

// MARK: - Local Quality Severity Colors
private extension Color {
    static let issueHigh = Color.red
    static let issueMedium = Color(hex: "#F59E0B")
    static let issueLow = Color(hex: "#A0A0B0")
}

// MARK: - DataProfileView

/// High-fidelity Sheet modal presenting data profiling, quality scores, column summaries, and correlation heatmaps.
struct DataProfileView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @Environment(\.dismiss) var dismiss

    @State private var activeTab: ProfileTab = .overview
    @State private var isComputing = false
    @State private var profile: FullDataProfile? = nil

    enum ProfileTab: String, CaseIterable, Identifiable {
        case overview     = "Overview"
        case columns      = "Columns"
        case correlations = "Correlations"
        
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.success)
                    Text("Data Profile & Insights")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                // Custom Tab Switcher
                HStack(spacing: 4) {
                    ForEach(ProfileTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeTab = tab
                            }
                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(activeTab == tab ? AppColors.accent : Color.clear)
                                )
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(AppColors.background)
                .cornerRadius(8)

                Spacer()

                // Close Button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(AppColors.sidebar)
            .overlay(VStack { Spacer(); Rectangle().fill(AppColors.border).frame(height: 1) })

            // Content Area
            if isComputing {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.success))
                        .scaleEffect(1.5)
                    Text("Profiling dataset and computing correlations...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
            } else if let profile = profile {
                Group {
                    switch activeTab {
                    case .overview:
                        ProfileOverviewTab(profile: profile, onSelectColumn: { colName in
                            dataViewModel.highlightedColumns = [colName]
                            dismiss()
                        })
                    case .columns:
                        ProfileColumnsTab(profile: profile)
                    case .correlations:
                        ProfileCorrelationsTab(profile: profile, onSelectCorrelation: { colA, colB in
                            dataViewModel.highlightedColumns = [colA, colB]
                            dismiss()
                        })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accent)
                    Text("No dataset loaded to profile.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
            }
        }
        .frame(minWidth: 1000, minHeight: 650)
        .onAppear {
            loadOrComputeProfile()
        }
    }

    private func loadOrComputeProfile() {
        if let cached = dataViewModel.cachedProfile {
            self.profile = cached
            return
        }

        guard let dataset = dataViewModel.currentDataSet else { return }
        isComputing = true

        Task {
            let result = await DataProfiler.profile(dataset: dataset)
            await MainActor.run {
                dataViewModel.cachedProfile = result
                self.profile = result
                self.isComputing = false
            }
        }
    }
}

// MARK: - Tab 1: Overview View

struct ProfileOverviewTab: View {
    let profile: FullDataProfile
    let onSelectColumn: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top row: Metadata Summary + Quality Score circular ring
                HStack(alignment: .top, spacing: 24) {
                    // Summary Metadata Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Dataset Summary")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                            GridRow {
                                SummaryLabel(title: "Filename", icon: "doc")
                                Text(profile.overview.filename)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                            }
                            GridRow {
                                SummaryLabel(title: "Dimensions", icon: "square.dashed")
                                Text("\(profile.overview.rowCount) Rows x \(profile.overview.columnCount) Columns")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            GridRow {
                                SummaryLabel(title: "Missing Cells", icon: "questionmark.circle")
                                Text(String(format: "%d (%.1f%%)", profile.overview.missingCount, profile.overview.missingPercentage))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(profile.overview.missingCount > 0 ? Color(hex: "#F59E0B") : AppColors.success)
                            }
                            GridRow {
                                SummaryLabel(title: "Duplicate Rows", icon: "doc.on.doc")
                                Text(String(format: "%d (%.1f%%)", profile.overview.duplicateCount, profile.overview.duplicatePercentage))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(profile.overview.duplicateCount > 0 ? Color(hex: "#F59E0B") : AppColors.success)
                            }
                            GridRow {
                                SummaryLabel(title: "Memory Size", icon: "cpu")
                                Text(profile.overview.memorySizeEstimate)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cards)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

                    // Quality Score Gauge
                    VStack(spacing: 12) {
                        Text("Data Quality Score")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        QualityScoreGaugeRing(score: profile.qualityScore.score)
                            .frame(width: 120, height: 120)

                        Spacer()

                        Text(qualityMessage(for: profile.qualityScore.score))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(qualityColor(for: profile.qualityScore.score))
                    }
                    .padding(20)
                    .frame(width: 250, height: 220)
                    .background(AppColors.cards)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                }

                // Middle Row: Donut Chart Distribution + Issues List
                HStack(alignment: .top, spacing: 24) {
                    // Column Type Distribution
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Column Type Distribution")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: 24) {
                            DonutChartView(distributions: profile.columnDistribution)
                                .frame(width: 120, height: 120)

                            VStack(alignment: .leading, spacing: 10) {
                                LegendRow(label: "Number Columns", value: profile.columnDistribution[.number, default: 0], color: AppColors.success)
                                LegendRow(label: "Text Columns", value: profile.columnDistribution[.text, default: 0], color: AppColors.accent)
                                LegendRow(label: "Date Columns", value: profile.columnDistribution[.date, default: 0], color: Color(hex: "#F59E0B"))
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cards)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

                    // Issues List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Identified Issues (\(profile.issues.count))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        if profile.issues.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.success)
                                Text("No quality issues detected! Great data consistency.")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(profile.issues) { issue in
                                        Button(action: {
                                            if let col = issue.columnName {
                                                onSelectColumn(col)
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(severityColor(issue.severity))
                                                    .frame(width: 8, height: 8)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(issue.description)
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(AppColors.textPrimary)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    if let col = issue.columnName {
                                                        Text("Click to view '\(col)' column")
                                                            .font(.system(size: 10))
                                                            .foregroundColor(AppColors.success)
                                                    }
                                                }

                                                Spacer()

                                                Text(issue.severity.rawValue)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(severityColor(issue.severity))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(severityColor(issue.severity).opacity(0.12))
                                                    .cornerRadius(4)
                                            }
                                            .padding(10)
                                            .background(AppColors.background)
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 180)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cards)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                }
            }
            .padding(24)
        }
    }

    private func severityColor(_ s: IssueSeverity) -> Color {
        switch s {
        case .high:   return .issueHigh
        case .medium: return .issueMedium
        case .low:    return .issueLow
        }
    }

    private func qualityColor(for score: Double) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return Color(hex: "#F59E0B") }
        return .issueHigh
    }

    private func qualityMessage(for score: Double) -> String {
        if score >= 80 { return "Good Quality" }
        if score >= 50 { return "Fair Quality" }
        return "Poor Quality"
    }
}

struct SummaryLabel: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Quality Score gauge ring helper

struct QualityScoreGaugeRing: View {
    let score: Double
    @State private var animatedProgress = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.border, lineWidth: 10)

            Circle()
                .trim(from: 0.0, to: animatedProgress)
                .stroke(
                    qualityColor(for: score),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(String(format: "%.0f", score))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("/ 100")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = score / 100.0
            }
        }
    }

    private func qualityColor(for score: Double) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return Color(hex: "#F59E0B") }
        return .red
    }
}

// MARK: - Donut Chart Distribution Helper

struct DonutChartView: View {
    let distributions: [ColumnType: Int]

    var body: some View {
        let total = max(1, distributions.values.reduce(0, +))
        let numRatio = Double(distributions[.number, default: 0]) / Double(total)
        let textRatio = Double(distributions[.text, default: 0]) / Double(total)
        let dateRatio = Double(distributions[.date, default: 0]) / Double(total)

        ZStack {
            Circle()
                .stroke(AppColors.border, lineWidth: 16)

            Circle()
                .trim(from: 0.0, to: numRatio)
                .stroke(AppColors.success, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: numRatio, to: numRatio + textRatio)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: numRatio + textRatio, to: 1.0)
                .stroke(Color(hex: "#F59E0B"), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct LegendRow: View {
    let label: String
    let value: Int
    let color: Color
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

// MARK: - Tab 2: Columns View

struct ProfileColumnsTab: View {
    let profile: FullDataProfile
    @State private var selectedColumnId: UUID? = nil

    private var selectedProfile: ColumnProfile? {
        profile.columnProfiles.first { $0.id == (selectedColumnId ?? profile.columnProfiles.first?.id) }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left pane: Column List (220pt)
            VStack(alignment: .leading, spacing: 10) {
                Text("Select Column")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(profile.columnProfiles) { col in
                            Button(action: { selectedColumnId = col.id }) {
                                HStack {
                                    Image(systemName: col.columnType.iconName)
                                        .font(.system(size: 10))
                                        .foregroundColor(AppColors.success)
                                        .frame(width: 14)
                                    Text(col.columnName)
                                        .font(.system(size: 12, weight: selectedProfile?.id == col.id ? .semibold : .regular))
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedProfile?.id == col.id ? AppColors.accent.opacity(0.7) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .frame(width: 220)
            .background(AppColors.sidebar)
            .overlay(Rectangle().fill(AppColors.border).frame(width: 1), alignment: .trailing)

            // Right pane: Detail Column profile
            if let col = selectedProfile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title + Type badge
                        HStack(spacing: 12) {
                            Text(col.columnName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)

                            Text(col.columnType.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.success.opacity(0.12))
                                .cornerRadius(4)
                        }

                        // Grid overview: Missing %, unique %
                        HStack(spacing: 20) {
                            DetailStatBox(title: "Missing values", value: "\(col.missingCount)", subtext: String(format: "%.1f%%", col.missingPercentage), showWarning: col.missingCount > 0)
                            DetailStatBox(title: "Unique values", value: "\(col.uniqueCount)", subtext: String(format: "%.1f%% cardinality", col.uniquePercentage), showWarning: false)
                        }

                        // Specific Profile Analytics
                        if col.columnType == .number, let num = col.numberProfile {
                            NumericProfileView(num: num)
                        } else if col.columnType == .text, let txt = col.textProfile {
                            TextProfileView(txt: txt)
                        } else if col.columnType == .date, let dat = col.dateProfile {
                            DateProfileView(dat: dat)
                        }

                        // Frequent values list
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Top 5 Most Common Values")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)

                            VStack(spacing: 10) {
                                ForEach(col.topValues) { val in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(val.value.isEmpty ? "(blank)" : val.value)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(val.value.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(String(format: "%d (%.1f%%)", val.count, val.percentage))
                                                .font(.system(size: 11))
                                                .foregroundColor(AppColors.textSecondary)
                                        }

                                        // 4pt thin bar indicator
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(AppColors.accent)
                                                .frame(width: geo.size.width * CGFloat(val.percentage / 100.0), height: 4)
                                        }
                                        .frame(height: 4)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(AppColors.cards)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
                    }
                    .padding(24)
                }
            } else {
                Spacer()
            }
        }
    }
}

struct DetailStatBox: View {
    let title: String
    let value: String
    let subtext: String
    let showWarning: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(showWarning ? Color(hex: "#F59E0B") : AppColors.textPrimary)
                Text(subtext)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cards)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
    }
}

// MARK: - Column Detail Profile sub-components

struct NumericProfileView: View {
    let num: NumberProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Aggregate values list
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    StatValueCell(label: "Mean", val: num.mean)
                    StatValueCell(label: "Median", val: num.median)
                    StatValueCell(label: "Mode", val: num.mode)
                }
                GridRow {
                    StatValueCell(label: "Min", val: num.min)
                    StatValueCell(label: "Max", val: num.max)
                    StatValueCell(label: "Range", val: num.range)
                }
                GridRow {
                    StatValueCell(label: "Std Dev", val: num.stdDev)
                    StatValueCell(label: "Variance", val: num.variance)
                    StatValueCell(label: "Outliers Count", val: Double(num.outlierCount), isInt: true, warn: num.outlierCount > 0)
                }
                GridRow {
                    StatValueCell(label: "Q1 (25%)", val: num.q1)
                    StatValueCell(label: "Q2 (50%)", val: num.q2)
                    StatValueCell(label: "Q3 (75%)", val: num.q3)
                }
                GridRow {
                    StatValueCell(label: "Skewness", val: num.skewness)
                    StatValueCell(label: "Kurtosis", val: num.kurtosis)
                }
            }
            .padding(16)
            .background(AppColors.cards)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))

            // Inline Histogram
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribution Histogram (10 bins)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)

                HStack(alignment: .bottom, spacing: 6) {
                    let maxBin = max(1, num.histogram.max() ?? 1)
                    ForEach(0..<num.histogram.count, id: \.self) { index in
                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.success)
                                        .frame(height: geo.size.height * CGFloat(Double(num.histogram[index]) / Double(maxBin)))
                                }
                            }
                            .frame(height: 80)

                            Text("\(num.histogram[index])")
                                .font(.system(size: 9))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppColors.cards)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
        }
    }
}

struct StatValueCell: View {
    let label: String
    let val: Double
    var isInt = false
    var warn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            Text(isInt ? String(format: "%.0f", val) : String(format: "%.4g", val))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(warn ? Color(hex: "#F59E0B") : AppColors.textPrimary)
        }
        .frame(minWidth: 120, alignment: .leading)
    }
}

struct TextProfileView: View {
    let txt: TextProfile
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
            GridRow {
                TextValueCell(label: "Average Text Length", value: String(format: "%.2f characters", txt.averageLength))
                TextValueCell(label: "Min Length", value: "\(txt.minLength) chars")
                TextValueCell(label: "Max Length", value: "\(txt.maxLength) chars")
            }
            GridRow {
                TextValueCell(label: "Blank/Empty cell count", value: "\(txt.emptyStringCount)", warn: txt.emptyStringCount > 0)
            }
        }
        .padding(16)
        .background(AppColors.cards)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
    }
}

struct TextValueCell: View {
    let label: String
    let value: String
    var warn = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(warn ? Color(hex: "#F59E0B") : AppColors.textPrimary)
        }
        .frame(minWidth: 150, alignment: .leading)
    }
}

struct DateProfileView: View {
    let dat: DateProfile
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    TextValueCell(label: "Earliest Date", value: formatDate(dat.earliestDate))
                    TextValueCell(label: "Latest Date", value: formatDate(dat.latestDate))
                }
                GridRow {
                    TextValueCell(label: "Date Range Span", value: String(format: "%.0f Days", dat.rangeSpanDays))
                    TextValueCell(label: "Most Common Year", value: dat.mostCommonYear.map { "\($0)" } ?? "N/A")
                    TextValueCell(label: "Most Common Month", value: dat.mostCommonMonth.map { monthName($0) } ?? "N/A")
                }
            }
            .padding(16)
            .background(AppColors.cards)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))

            // timeline density
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline Density Distribution")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)

                HStack(alignment: .bottom, spacing: 6) {
                    let maxCount = max(1, dat.timelineDensity.map { $0.count }.max() ?? 1)
                    ForEach(dat.timelineDensity) { point in
                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: "#F59E0B"))
                                        .frame(height: geo.size.height * CGFloat(Double(point.count) / Double(maxCount)))
                                }
                            }
                            .frame(height: 80)

                            Text(point.label)
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppColors.cards)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let d = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: d)
    }

    private func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        if m >= 1 && m <= 12 {
            return f.monthSymbols[m - 1]
        }
        return "N/A"
    }
}

// MARK: - Tab 3: Correlation Matrix Heatmap View

struct ProfileCorrelationsTab: View {
    let profile: FullDataProfile
    let onSelectCorrelation: (String, String) -> Void
    @State private var hoveredCell: (row: Int, col: Int)? = nil

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pearson Correlation Matrix Heatmap")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                if profile.correlations.columns.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "number.square.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Requires at least 2 numeric columns to calculate correlations.")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 250)
                } else {
                    let cols = profile.correlations.columns
                    let vals = profile.correlations.values

                    VStack(alignment: .leading, spacing: 0) {
                        // Top column labels row
                        HStack(spacing: 0) {
                            Spacer().frame(width: 140)
                            ForEach(cols, id: \.self) { cName in
                                Text(cName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(width: 52, height: 40, alignment: .center)
                                    .rotationEffect(.degrees(-45))
                                    .lineLimit(1)
                            }
                        }
                        .frame(height: 50)

                        // Rows
                        ForEach(0..<cols.count, id: \.self) { rIndex in
                            HStack(spacing: 0) {
                                // Row name label
                                Text(cols[rIndex])
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(width: 130, height: 48, alignment: .trailing)
                                    .padding(.trailing, 10)
                                    .lineLimit(1)

                                ForEach(0..<cols.count, id: \.self) { cIndex in
                                    let correlation = vals[rIndex][cIndex]
                                    
                                    // Heatmap cell
                                    Rectangle()
                                        .fill(heatmapColor(correlation))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Text(String(format: "%.2f", correlation))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(textColor(correlation))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                        )
                                        .overlay(
                                            Group {
                                                if hoveredCell?.row == rIndex && hoveredCell?.col == cIndex {
                                                    Rectangle()
                                                        .stroke(AppColors.success, lineWidth: 2)
                                                }
                                            }
                                        )
                                        .contentShape(Rectangle())
                                        .onHover { hover in
                                            if hover {
                                                hoveredCell = (rIndex, cIndex)
                                            } else if hoveredCell?.row == rIndex && hoveredCell?.col == cIndex {
                                                hoveredCell = nil
                                            }
                                        }
                                        .onTapGesture {
                                            onSelectCorrelation(cols[rIndex], cols[cIndex])
                                        }
                                        .help(correlationTooltip(rowName: cols[rIndex], colName: cols[cIndex], value: correlation))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(24)
        }
    }

    private func heatmapColor(_ correlation: Double) -> Color {
        // Strong positive (1.0): Cyan #00B4D8
        // No correlation (0.0): Dark #1A1A2E
        // Strong negative (-1.0): Deep Red
        if correlation >= 0 {
            return Color(AppColors.success).opacity(correlation)
        } else {
            return Color.red.opacity(abs(correlation))
        }
    }

    private func textColor(_ correlation: Double) -> Color {
        // Contrast helper
        if abs(correlation) > 0.4 {
            return .white
        }
        return AppColors.textSecondary
    }

    private func correlationTooltip(rowName: String, colName: String, value: Double) -> String {
        let interpret: String
        let absVal = abs(value)
        if absVal > 0.7 {
            interpret = "Strong"
        } else if absVal > 0.3 {
            interpret = "Moderate"
        } else {
            interpret = "Weak"
        }
        let sign = value >= 0 ? "Positive" : "Negative"
        return "\(rowName) vs \(colName)\nCorrelation: \(String(format: "%.4f", value))\nInterpretation: \(interpret) \(sign)"
    }
}
