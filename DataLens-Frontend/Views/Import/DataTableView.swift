import SwiftUI

/// DataTableView displays the imported dataset in a custom-styled spreadsheet-like grid with advanced interactions
struct DataTableView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    @FocusState private var isSearchFocused: Bool
    @State private var scrollOffset: CGFloat = 0
    @State private var hoveredHeader: String? = nil
    @State private var selectedRow: Row? = nil
    
    @State private var isReimportHovered = false
    @State private var isChartsHovered = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Toolbar: Dataset Name, Search Input, and Re-import Button
                HStack(spacing: 16) {
                    if let dataset = dataViewModel.currentDataSet {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dataset.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                            Text("Imported at \(formatDate(dataset.importedAt))")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Live Search Bar
                    TableSearchBar(text: $dataViewModel.searchText, isFocused: $isSearchFocused)
                        .frame(width: 300)
                    
                    // Re-import Button
                    Button(action: {
                        dataViewModel.reset()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Re-import")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isReimportHovered ? AppColors.accent.opacity(0.85) : AppColors.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isReimportHovered = hovering
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(AppColors.sidebar)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                    }
                )
                
                // Grid Data Area
                if let dataset = dataViewModel.currentDataSet {
                    if dataViewModel.filteredRows.isEmpty && !dataViewModel.searchText.isEmpty {
                        // Helpful Empty Results layout
                        EmptySearchStateView(query: dataViewModel.searchText)
                    } else {
                        // Scrolling Spreadsheet Structure
                        ScrollView([.horizontal, .vertical]) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                // Horizontal Scroll Position preference tracker
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: geo.frame(in: .named("tableScroll")).minX
                                        )
                                }
                                .frame(height: 0)
                                
                                // Table Header Row (Column Headers)
                                HStack(spacing: 0) {
                                    // Spacing matching pinned columns width
                                    Spacer()
                                        .frame(width: 210)
                                    
                                    // Scrollable headers (Index 1 to N-1)
                                    ForEach(dataset.columns.dropFirst()) { col in
                                        HeaderCell(col: col, hoveredHeader: $hoveredHeader)
                                    }
                                }
                                .overlay(
                                    // Pinned left headers (Row number header + Column 0 header)
                                    HStack(spacing: 0) {
                                        Text("#")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(AppColors.textSecondary)
                                            .frame(width: 50, alignment: .center)
                                            .frame(maxHeight: .infinity)
                                            .background(AppColors.sidebar)
                                        
                                        if let firstCol = dataset.columns.first {
                                            HeaderCell(col: firstCol, hoveredHeader: $hoveredHeader)
                                        }
                                    }
                                    .background(AppColors.sidebar)
                                    .offset(x: -scrollOffset)
                                    .zIndex(5)
                                    , alignment: .leading
                                )
                                .overlay(
                                    VStack {
                                        Spacer()
                                        Rectangle()
                                            .fill(AppColors.border)
                                            .frame(height: 1)
                                    }
                                )
                                
                                // Table Data Rows
                                ForEach(Array(dataViewModel.filteredRows.enumerated()), id: \.element.id) { index, row in
                                    DataTableRowView(
                                        rowIndex: index,
                                        row: row,
                                        columns: dataset.columns,
                                        scrollOffset: scrollOffset,
                                        query: dataViewModel.searchText,
                                        onClick: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedRow = row
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .coordinateSpace(name: "tableScroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            scrollOffset = value
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                // Summary Footer: Fixed at bottom of table
                HStack(alignment: .center) {
                    if let dataset = dataViewModel.currentDataSet {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(dataViewModel.filteredRows.count) of \(dataset.rowCount) rows  •  \(dataset.columnCount) columns")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                            
                            if !dataViewModel.searchText.isEmpty {
                                Text("Filtered by \"\(dataViewModel.searchText)\"")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.success)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Display aggregates for first few numeric columns in the footer
                    if let dataset = dataViewModel.currentDataSet {
                        let numCols = dataViewModel.getNumericColumns()
                        if !numCols.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(numCols.prefix(3)) { col in
                                        if let stats = dataViewModel.displayStats[col.name] {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(col.name)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(AppColors.success)
                                                    .lineLimit(1)
                                                
                                                HStack(spacing: 8) {
                                                    StatBadge(label: "Sum", value: formatDouble(stats.sum))
                                                    StatBadge(label: "Avg", value: formatDouble(stats.average))
                                                    StatBadge(label: "Min", value: formatDouble(stats.minNumeric))
                                                    StatBadge(label: "Max", value: formatDouble(stats.maxNumeric))
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(AppColors.cards.opacity(0.4))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(AppColors.border, lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: 550)
                        }
                    }
                    
                    Spacer()
                    
                    // Navigation trigger
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navigationViewModel.navigate(to: .charts)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("Continue to Charts")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isChartsHovered ? AppColors.accent.opacity(0.85) : AppColors.accent)
                        )
                        .shadow(color: AppColors.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isChartsHovered = hovering
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(AppColors.sidebar)
                .overlay(
                    VStack {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                        Spacer()
                    }
                )
            }
            .background(AppColors.background)
            
            // Full Details popup modal sheet overlay
            if let row = selectedRow, let dataset = dataViewModel.currentDataSet {
                RowDetailPopup(row: row, columns: dataset.columns, onClose: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRow = nil
                    }
                })
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDouble(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.4g", value)
    }
}

// MARK: - Subviews

/// HeaderCell handles sorting cycles and statistics hover popovers
struct HeaderCell: View {
    let col: Column
    @EnvironmentObject var dataViewModel: DataViewModel
    @Binding var hoveredHeader: String?
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: typeIconName(for: col.type))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.success)
            
            Text(col.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Sort indicator
            if dataViewModel.sortColumn == col.name {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.accent)
                    .rotationEffect(.degrees(dataViewModel.sortAscending ? 0 : 180))
            }
        }
        .frame(width: 160, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(AppColors.sidebar)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                dataViewModel.sortData(by: col.name)
            }
        }
        .onHover { hovering in
            isHovered = hovering
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredHeader = hovering ? col.name : nil
            }
        }
        .overlay(
            Group {
                if hoveredHeader == col.name {
                    StatsPopoverView(columnName: col.name, stats: dataViewModel.displayStats[col.name])
                        .offset(y: 40)
                        .zIndex(10)
                }
            }
            , alignment: .topLeading
        )
        .zIndex(isHovered ? 10 : 1)
    }
    
    private func typeIconName(for type: ColumnType) -> String {
        switch type {
        case .number: return "number"
        case .text: return "textformat"
        case .date: return "calendar"
        }
    }
}

/// StatsPopoverView displays column aggregate metrics in a popover
struct StatsPopoverView: View {
    let columnName: String
    let stats: ColumnStats?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Statistics")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 2)
            
            if let stats = stats {
                switch stats.type {
                case .number:
                    StatRow(label: "Sum", value: formatDouble(stats.sum))
                    StatRow(label: "Average", value: formatDouble(stats.average))
                    StatRow(label: "Min", value: formatDouble(stats.minNumeric))
                    StatRow(label: "Max", value: formatDouble(stats.maxNumeric))
                case .text:
                    StatRow(label: "Unique Count", value: "\(stats.uniqueCount ?? 0)")
                    StatRow(label: "Most Common", value: stats.mostCommonValue ?? "N/A")
                case .date:
                    StatRow(label: "Earliest", value: formatDate(stats.earliestDate))
                    StatRow(label: "Latest", value: formatDate(stats.latestDate))
                }
            } else {
                Text("No data available")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .frame(width: 190)
        .background(AppColors.cards)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
    
    private func formatDouble(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.4g", value)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
    }
}

/// DataTableRowView aligns cells, handles background updates, row highlight, and overlays pinned items
struct DataTableRowView: View {
    let rowIndex: Int
    let row: Row
    let columns: [Column]
    let scrollOffset: CGFloat
    let query: String
    let onClick: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        let isEven = rowIndex % 2 == 0
        let baseBgColor = isEven ? AppColors.background : AppColors.sidebar
        let rowBgColor = isHovered ? AppColors.cards : baseBgColor
        
        HStack(spacing: 0) {
            // Padding spacer for pinned columns
            Spacer()
                .frame(width: 210)
            
            // Scrollable cells
            ForEach(columns.dropFirst()) { col in
                CellView(value: row.values[col.name], type: col.type, query: query, width: 160, bgColor: rowBgColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClick)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .overlay(
            // Pinned items: Row index column + Column 0 cell overlay
            HStack(spacing: 0) {
                Text("\(rowIndex + 1)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 50, alignment: .center)
                    .frame(maxHeight: .infinity)
                    .background(rowBgColor)
                
                if let firstCol = columns.first {
                    CellView(value: row.values[firstCol.name], type: firstCol.type, query: query, width: 160, bgColor: rowBgColor)
                }
            }
            .offset(x: -scrollOffset)
            .zIndex(5)
            , alignment: .leading
        )
        .overlay(
            VStack {
                Spacer()
                Rectangle()
                    .fill(AppColors.border.opacity(0.3))
                    .frame(height: 1)
            }
        )
    }
}

/// CellView formats and highlights query matches inside the table grid
struct CellView: View {
    let value: Any?
    let type: ColumnType
    let query: String
    let width: CGFloat
    let bgColor: Color
    
    var body: some View {
        let displayVal = formatCellValue(value)
        
        HStack(spacing: 0) {
            highlightedText(displayVal, query: query)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            Spacer()
        }
        .frame(width: width)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bgColor)
    }
    
    private func formatCellValue(_ value: Any?) -> String {
        guard let value = value else { return "" }
        if let doubleVal = value as? Double {
            if doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", doubleVal)
            }
            return String(format: "%.4g", doubleVal)
        }
        if let dateVal = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: dateVal)
        }
        return "\(value)"
    }
    
    private func highlightedText(_ text: String, query: String) -> Text {
        guard !query.isEmpty else { return Text(text) }
        
        let ranges = text.ranges(of: query, options: .caseInsensitive)
        guard !ranges.isEmpty else { return Text(text) }
        
        var resultText = Text("")
        var currentIndex = text.startIndex
        
        for range in ranges {
            let beforeRange = text[currentIndex..<range.lowerBound]
            resultText = resultText + Text(String(beforeRange))
            
            let matchText = text[range]
            resultText = resultText + Text(String(matchText))
                .foregroundColor(AppColors.success) // #00B4D8 Success color (cyan)
                .bold()
            
            currentIndex = range.upperBound
        }
        
        let remainingText = text[currentIndex...]
        resultText = resultText + Text(String(remainingText))
        
        return resultText
    }
}

/// TableSearchBar renders text box with clear button, custom icons, and purple focus ring
struct TableSearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isFocused ? AppColors.accent : AppColors.textSecondary)
            
            TextField("Search all columns...", text: $text)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textPrimary)
                .textFieldStyle(.plain)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? AppColors.accent : AppColors.border, lineWidth: 1.5)
        )
        .shadow(color: isFocused ? AppColors.accent.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 0)
    }
}

/// EmptySearchStateView displays search missing messages
struct EmptySearchStateView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary.opacity(0.6))
            
            Text("No Results Found")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("We couldn't find any matches for \"\(query)\".\nTry checking your spelling or search for another term.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
        .background(AppColors.background)
    }
}

/// RowDetailPopup represents a center-aligned details pop up card
struct RowDetailPopup: View {
    let row: Row
    let columns: [Column]
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture(perform: onClose)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.success)
                    
                    Text("Row Details")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(AppColors.border)
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(columns) { col in
                            HStack(alignment: .top) {
                                HStack(spacing: 6) {
                                    Image(systemName: col.type.iconName)
                                        .font(.system(size: 10))
                                        .foregroundColor(AppColors.success)
                                    
                                    Text(col.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(width: 150, alignment: .leading)
                                
                                Spacer()
                                
                                Text(formatValue(row.values[col.name]))
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textPrimary)
                                    .multilineTextAlignment(.trailing)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .frame(maxHeight: 400)
            }
            .padding(24)
            .frame(width: 500)
            .background(AppColors.cards)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
        }
    }
    
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "-" }
        if let doubleVal = value as? Double {
            if doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", doubleVal)
            }
            return String(format: "%f", doubleVal)
        }
        if let dateVal = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .medium
            return formatter.string(from: dateVal)
        }
        return "\(value)"
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 3) {
            Text("\(label):")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

// MARK: - Layout Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Extensions

extension String {
    /// Resolves list of ranges matching search queries (prevents loops on empty query strings)
    func ranges(of searchString: String, options: CompareOptions = []) -> [Range<Index>] {
        var ranges: [Range<Index>] = []
        var start = startIndex
        while let range = range(of: searchString, options: options, range: start..<endIndex) {
            ranges.append(range)
            if range.lowerBound == range.upperBound {
                break
            }
            start = range.upperBound
        }
        return ranges
    }
}
