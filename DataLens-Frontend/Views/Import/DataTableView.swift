import SwiftUI

/// DataTableView displays the imported dataset in a custom-styled spreadsheet-like grid
struct DataTableView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    @State private var isReimportHovered = false
    @State private var isChartsHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar: Dataset Name & Re-import button
            HStack {
                if let dataset = dataViewModel.currentDataSet {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dataset.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Imported at \(formatDate(dataset.importedAt))")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
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
            
            // Grid content area
            if let dataset = dataViewModel.currentDataSet {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            // Row number placeholder header
                            Text("#")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 50, alignment: .center)
                                .padding(.vertical, 12)
                                .background(AppColors.sidebar)
                            
                            ForEach(dataset.columns) { col in
                                HStack(spacing: 6) {
                                    Image(systemName: col.type.iconName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppColors.success)
                                    
                                    Text(col.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(width: 160, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(AppColors.sidebar)
                            }
                        }
                        .overlay(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(AppColors.border)
                                    .frame(height: 1)
                            }
                        )
                        
                        // Rows
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(dataset.rows.enumerated()), id: \.element.id) { rowIndex, row in
                                let isEven = rowIndex % 2 == 0
                                let rowBgColor = isEven ? AppColors.background : AppColors.sidebar
                                
                                HStack(spacing: 0) {
                                    // Row Index Label
                                    Text("\(rowIndex + 1)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(AppColors.textSecondary)
                                        .frame(width: 50, alignment: .center)
                                        .padding(.vertical, 10)
                                        .background(rowBgColor)
                                    
                                    // Cells
                                    ForEach(dataset.columns) { col in
                                        let displayVal = formatCellValue(row.values[col.name])
                                        
                                        Text(displayVal)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(AppColors.textPrimary)
                                            .lineLimit(1)
                                            .frame(width: 160, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(rowBgColor)
                                    }
                                }
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
                    }
                }
            }
            
            // Bottom bar: Summary and navigation button
            HStack {
                if let dataset = dataViewModel.currentDataSet {
                    Text("\(dataset.rowCount) rows  •  \(dataset.columnCount) columns")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
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
                    .padding(.horizontal, 20)
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
    }
    
    /// Formats creation dates into clean readable formats
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Formats cell data values depending on their types
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
}
