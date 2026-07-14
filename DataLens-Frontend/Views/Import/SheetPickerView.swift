import SwiftUI

/// Animated dropdown that lets the user choose a worksheet from a multi-sheet Excel workbook
struct SheetPickerView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Trigger Button — shows current sheet name and a chevron
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.success)

                    Text(dataViewModel.selectedSheet ?? "Select Sheet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.cards)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isExpanded ? AppColors.accent : AppColors.border,
                            lineWidth: 1.5
                        )
                )
            }
            .buttonStyle(.plain)

            // Expanded sheet list
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(dataViewModel.availableSheets) { sheet in
                        SheetRowView(
                            sheet: sheet,
                            isSelected: sheet.name == dataViewModel.selectedSheet
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                            dataViewModel.switchSheet(to: sheet.name)
                        }
                    }
                }
                .padding(6)
                .background(AppColors.cards)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal:   .opacity.combined(with: .move(edge: .top))
                ))
                .zIndex(10)
            }
        }
        .frame(maxWidth: 340)
    }
}

// MARK: - Sheet Row

/// A single selectable row inside the sheet-picker dropdown
private struct SheetRowView: View {
    let sheet: SheetInfo
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Left accent bar for the selected sheet
                Rectangle()
                    .fill(isSelected ? AppColors.accent : Color.clear)
                    .frame(width: 3, height: 16)
                    .cornerRadius(1.5)

                Image(systemName: "tablecells")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                Text(sheet.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Row / column count badge
                Text("\(sheet.rowCount) rows, \(sheet.columnCount) cols")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected
                          ? AppColors.accent.opacity(0.18)
                          : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
