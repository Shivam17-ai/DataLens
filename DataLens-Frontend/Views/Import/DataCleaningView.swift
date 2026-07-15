import SwiftUI

// MARK: - Amber Warning Color
private extension Color {
    static let amber = Color(hex: "#F59E0B")
}

// MARK: - DataCleaningView

/// 320pt side panel that slides in from the right edge of the DataTableView.
/// Contains 5 collapsible cleaning sections, each calling DataCleaner methods
/// via DataViewModel.applyCleaningOperation().
struct DataCleaningView: View {
    @EnvironmentObject var dataViewModel: DataViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Text("Data Cleaning")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dataViewModel.isCleaningPanelOpen = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.sidebar)
            .overlay(VStack { Spacer(); Rectangle().fill(AppColors.border).frame(height: 1) })

            // Feedback message (warning or success)
            if let msg = dataViewModel.cleaningMessage {
                let isWarning = msg.contains("⚠️")
                HStack(spacing: 8) {
                    Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(isWarning ? .amber : AppColors.success)
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isWarning ? Color.amber.opacity(0.08) : AppColors.success.opacity(0.08))
                .overlay(Rectangle().fill(isWarning ? Color.amber : AppColors.success).frame(width: 3), alignment: .leading)
            }

            ScrollView {
                VStack(spacing: 1) {
                    MissingValuesSection()
                    DuplicatesSection()
                    if dataViewModel.getTextColumns().count > 0    { TextCleaningSection() }
                    if dataViewModel.getNumericColumns().count > 0 { NumberCleaningSection() }
                    if !(dataViewModel.currentDataSet?.columns.filter { $0.type == .date }.isEmpty ?? true) {
                        DateCleaningSection()
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 320)
        .background(AppColors.sidebar)
        .overlay(Rectangle().fill(AppColors.border).frame(width: 1), alignment: .leading)
    }
}

// MARK: - Section Container

/// Collapsible section wrapper used by every cleaning section
struct CleaningSection<Content: View>: View {
    let title: String
    let iconName: String
    @State private var isExpanded: Bool = true
    let content: Content

    init(title: String, iconName: String, @ViewBuilder content: () -> Content) {
        self.title    = title
        self.iconName = iconName
        self.content  = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header — tap to expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 16)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.background.opacity(0.4))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(VStack { Spacer(); Rectangle().fill(AppColors.border.opacity(0.5)).frame(height: 1) })
    }
}

// MARK: - Small Apply Button

struct ApplyButton: View {
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(isHovered ? AppColors.accent.opacity(0.8) : AppColors.accent))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovered = h } }
    }
}

// MARK: - Column Picker Row

struct ColumnPickerRow: View {
    let label: String
    let columns: [Column]
    @Binding var selected: String?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Picker("", selection: $selected) {
                Text("All Columns").tag(String?.none)
                ForEach(columns) { col in
                    Text(col.name).tag(String?.some(col.name))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 140)
            .labelsHidden()
        }
    }
}

// MARK: - 1. Missing Values

struct MissingValuesSection: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @State private var selectedColumn: String? = nil
    @State private var customFill = ""

    private var columns: [Column] { dataViewModel.currentDataSet?.visibleColumns ?? [] }
    private var missingCount: Int {
        guard let ds = dataViewModel.currentDataSet else { return 0 }
        let cols = selectedColumn.map { [$0] } ?? ds.columns.map(\.name)
        return ds.rows.filter { row in cols.contains { row.values[$0] == nil } }.count
    }

    var body: some View {
        CleaningSection(title: "Missing Values", iconName: "questionmark.circle") {
            ColumnPickerRow(label: "Column", columns: columns, selected: $selectedColumn)

            // Missing count badge
            HStack {
                Text("Missing values:")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(missingCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(missingCount > 0 ? Color.amber : AppColors.success)
            }

            Divider().background(AppColors.border)

            // Fill strategies
            Group {
                HStack {
                    Text("Remove rows with missing").font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                    Spacer()
                    ApplyButton(label: "Apply") {
                        dataViewModel.applyCleaningOperation(.removeMissing(columns: selectedColumn.map { [$0] }))
                    }
                }
                if let col = selectedColumn,
                   dataViewModel.currentDataSet?.columns.first(where: { $0.name == col })?.type == .number {
                    HStack {
                        Text("Fill with Mean").font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                        Spacer()
                        ApplyButton(label: "Apply") {
                            dataViewModel.applyCleaningOperation(.fillMissing(columnName: col, strategy: .mean))
                        }
                    }
                    HStack {
                        Text("Fill with Median").font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                        Spacer()
                        ApplyButton(label: "Apply") {
                            dataViewModel.applyCleaningOperation(.fillMissing(columnName: col, strategy: .median))
                        }
                    }
                }
                if let col = selectedColumn {
                    HStack {
                        Text("Fill with Mode").font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                        Spacer()
                        ApplyButton(label: "Apply") {
                            dataViewModel.applyCleaningOperation(.fillMissing(columnName: col, strategy: .mode))
                        }
                    }
                    HStack(spacing: 6) {
                        TextField("Custom value", text: $customFill)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(6)
                            .background(AppColors.background)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppColors.border, lineWidth: 1))
                        ApplyButton(label: "Fill") {
                            dataViewModel.applyCleaningOperation(.fillMissing(columnName: col, strategy: .custom(customFill)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 2. Duplicates

struct DuplicatesSection: View {
    @EnvironmentObject var dataViewModel: DataViewModel

    private var dupCount: Int {
        guard let ds = dataViewModel.currentDataSet else { return 0 }
        return DataCleaner.countDuplicates(dataset: ds)
    }

    var body: some View {
        CleaningSection(title: "Duplicates", iconName: "doc.on.doc") {
            HStack {
                Text("Duplicate rows:")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(dupCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dupCount > 0 ? Color.amber : AppColors.success)
            }
            HStack {
                Text("Remove all duplicates (keep first)")
                    .font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                Spacer()
                ApplyButton(label: "Remove") {
                    dataViewModel.applyCleaningOperation(.removeDuplicates(columns: nil))
                }
            }
        }
    }
}

// MARK: - 3. Text Cleaning

struct TextCleaningSection: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @State private var selectedColumn: String? = nil
    @State private var findText   = ""
    @State private var replaceText = ""
    @State private var caseSensitive = false

    private var textCols: [Column] { dataViewModel.getTextColumns() }

    var body: some View {
        CleaningSection(title: "Text Cleaning", iconName: "textformat") {
            ColumnPickerRow(label: "Column", columns: textCols, selected: $selectedColumn)

            if let col = selectedColumn {
                Group {
                    CleanRow(label: "Trim Whitespace") {
                        dataViewModel.applyCleaningOperation(.trimWhitespace(columnName: col))
                    }
                    CleanRow(label: "Convert to Uppercase") {
                        dataViewModel.applyCleaningOperation(.convertCase(columnName: col, conversion: .upper))
                    }
                    CleanRow(label: "Convert to Lowercase") {
                        dataViewModel.applyCleaningOperation(.convertCase(columnName: col, conversion: .lower))
                    }
                    CleanRow(label: "Remove Special Chars") {
                        dataViewModel.applyCleaningOperation(.removeSpecialCharacters(columnName: col))
                    }
                }

                Divider().background(AppColors.border)
                Text("Find & Replace").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textSecondary)

                TextField("Find", text: $findText)
                    .cleanTextField()
                TextField("Replace with", text: $replaceText)
                    .cleanTextField()

                HStack {
                    Toggle("Case sensitive", isOn: $caseSensitive)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    ApplyButton(label: "Replace") {
                        dataViewModel.applyCleaningOperation(.findAndReplace(columnName: col, find: findText, replace: replaceText, caseSensitive: caseSensitive))
                    }
                }
            } else {
                Text("Select a text column above.")
                    .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - 4. Number Cleaning

struct NumberCleaningSection: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @State private var selectedColumn: String? = nil
    @State private var decimals: Double = 2
    @State private var customLo = ""
    @State private var customHi = ""

    private var numCols: [Column] { dataViewModel.getNumericColumns() }

    var body: some View {
        CleaningSection(title: "Number Cleaning", iconName: "number") {
            ColumnPickerRow(label: "Column", columns: numCols, selected: $selectedColumn)

            if let col = selectedColumn {
                // Round
                HStack {
                    Text("Round to \(Int(decimals)) dp").font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                    Spacer()
                    ApplyButton(label: "Apply") {
                        dataViewModel.applyCleaningOperation(.round(columnName: col, decimals: Int(decimals)))
                    }
                }
                Slider(value: $decimals, in: 0...10, step: 1)
                    .accentColor(AppColors.accent)

                Divider().background(AppColors.border)

                CleanRow(label: "Normalize (0–1)") {
                    dataViewModel.applyCleaningOperation(.normalize(columnName: col))
                }
                CleanRow(label: "Standardize (z-score)") {
                    dataViewModel.applyCleaningOperation(.standardize(columnName: col))
                }

                Divider().background(AppColors.border)
                Text("Remove Outliers").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textSecondary)

                CleanRow(label: "IQR method") {
                    dataViewModel.applyCleaningOperation(.removeOutliers(columnName: col, method: .iqr))
                }
                CleanRow(label: "Z-score method (±3σ)") {
                    dataViewModel.applyCleaningOperation(.removeOutliers(columnName: col, method: .zscore))
                }

                HStack(spacing: 6) {
                    TextField("Min", text: $customLo).cleanTextField().frame(maxWidth: 60)
                    Text("–").foregroundColor(AppColors.textSecondary)
                    TextField("Max", text: $customHi).cleanTextField().frame(maxWidth: 60)
                    Spacer()
                    ApplyButton(label: "Apply") {
                        guard let lo = Double(customLo), let hi = Double(customHi) else { return }
                        dataViewModel.applyCleaningOperation(.removeOutliers(columnName: col, method: .customRange(lo: lo, hi: hi)))
                    }
                }
            } else {
                Text("Select a numeric column above.")
                    .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - 5. Date Cleaning

struct DateCleaningSection: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @State private var selectedColumn: String? = nil
    @State private var outputFormat = "yyyy-MM-dd"

    private static let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "dd-MMM-yyyy", "MMMM d, yyyy"]
    private var dateCols: [Column] { dataViewModel.currentDataSet?.columns.filter { $0.type == .date } ?? [] }

    var body: some View {
        CleaningSection(title: "Date Cleaning", iconName: "calendar") {
            ColumnPickerRow(label: "Column", columns: dateCols, selected: $selectedColumn)

            if let col = selectedColumn {
                // Format picker
                HStack {
                    Text("Format").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Picker("", selection: $outputFormat) {
                        ForEach(Self.formats, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).frame(maxWidth: 140).labelsHidden()
                }
                HStack {
                    Text("Standardize date format").font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
                    Spacer()
                    ApplyButton(label: "Apply") {
                        dataViewModel.applyCleaningOperation(.standardizeDate(columnName: col, format: outputFormat))
                    }
                }

                Divider().background(AppColors.border)
                Text("Extract Components").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.textSecondary)

                ForEach(DateComponent.allCases) { component in
                    CleanRow(label: "Extract \(component.rawValue)") {
                        dataViewModel.applyCleaningOperation(.extractDateComponent(columnName: col, component: component, newColumnName: nil))
                    }
                }
            } else {
                Text("Select a date column above.")
                    .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Helpers

/// A simple label + apply button row for one-tap operations
struct CleanRow: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(AppColors.textPrimary)
            Spacer()
            ApplyButton(label: "Apply", action: action)
        }
    }
}

private extension View {
    func cleanTextField() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(AppColors.textPrimary)
            .padding(6)
            .background(AppColors.background)
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppColors.border, lineWidth: 1))
    }
}
