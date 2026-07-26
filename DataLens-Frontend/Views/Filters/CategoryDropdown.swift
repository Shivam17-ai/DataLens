import SwiftUI

// MARK: - CategoryDropdown

/// Multi-select dropdown that shows all unique values for a text column.
/// Features: inline value search, percentage bars, checkboxes, select-all,
/// apply/cancel flow, and cross-filter publication on apply.
struct CategoryDropdown: View {

    // MARK: Dependencies
    let column: Column
    let dataset: DataSet
    @ObservedObject var filterViewModel: FilterViewModel
    @EnvironmentObject var crossFilterManager: CrossFilterManager

    // MARK: Private State
    @State private var isOpen: Bool = false
    @State private var searchText: String = ""
    @State private var pendingSelection: Set<String> = []
    @State private var appliedSelection: Set<String> = []

    // MARK: Computed
    private var uniqueValues: [ValueCount] {
        let column = column.name
        var counts: [String: Int] = [:]
        for row in dataset.rows {
            let val = "\(row.values[column] ?? "(blank)")"
            counts[val, default: 0] += 1
        }
        let total = dataset.rows.count
        return counts
            .map { ValueCount(value: $0.key, count: $0.value, total: total) }
            .sorted { $0.count > $1.count }
    }

    private var filteredValues: [ValueCount] {
        guard !searchText.isEmpty else { return uniqueValues }
        return uniqueValues.filter { $0.value.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectionLabel: String {
        if appliedSelection.isEmpty {
            return column.name
        }
        return "\(column.name) (\(appliedSelection.count) selected)"
    }

    // MARK: Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Trigger Button ──────────────────────────────────────────
            triggerButton

            // ── Dropdown Panel ─────────────────────────────────────────
            if isOpen {
                dropdownPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isOpen)
        .onAppear { syncPendingFromApplied() }
    }

    // MARK: - Sub-views

    private var triggerButton: some View {
        Button(action: {
            if !isOpen { syncPendingFromApplied() }
            withAnimation { isOpen.toggle() }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(appliedSelection.isEmpty ? ColorPalette.textSecondary : ColorPalette.accent)

                Text(selectionLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(appliedSelection.isEmpty ? ColorPalette.textPrimary : ColorPalette.accent)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .rotationEffect(.degrees(isOpen ? 0 : 0)) // rotation handled by chevron name swap
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(ColorPalette.background.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(appliedSelection.isEmpty ? ColorPalette.border : ColorPalette.accent.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var dropdownPanel: some View {
        VStack(spacing: 0) {
            // Header: Search + Select All / Deselect All
            VStack(spacing: 8) {
                // Inline search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textSecondary)
                    TextField("Search \(column.name)…", text: $searchText)
                        .font(.system(size: 11))
                        .foregroundColor(ColorPalette.textPrimary)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(ColorPalette.background.opacity(0.5))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))

                // Select all / Deselect all
                HStack {
                    Button("Select All") {
                        filteredValues.forEach { pendingSelection.insert($0.value) }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ColorPalette.success)
                    .buttonStyle(.plain)

                    Text("·")
                        .foregroundColor(ColorPalette.textSecondary)

                    Button("Deselect All") {
                        filteredValues.forEach { pendingSelection.remove($0.value) }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(pendingSelection.count) selected")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            .padding(10)

            Divider().background(ColorPalette.border)

            // Value rows (max 300pt, then scrollable)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredValues, id: \.value) { item in
                        valueRow(for: item)
                    }
                }
            }
            .frame(maxHeight: 300)

            Divider().background(ColorPalette.border)

            // Footer: Apply / Cancel
            HStack(spacing: 8) {
                Button("Cancel") {
                    syncPendingFromApplied()
                    withAnimation { isOpen = false }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ColorPalette.border.opacity(0.3))
                .cornerRadius(6)
                .buttonStyle(.plain)

                Spacer()

                Button("Apply") {
                    applySelection()
                    withAnimation { isOpen = false }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(ColorPalette.accent)
                .cornerRadius(6)
                .buttonStyle(.plain)
            }
            .padding(10)
        }
        .background(ColorPalette.cards)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ColorPalette.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func valueRow(for item: ValueCount) -> some View {
        let isChecked = pendingSelection.contains(item.value)
        Button(action: {
            if isChecked { pendingSelection.remove(item.value) }
            else { pendingSelection.insert(item.value) }
        }) {
            ZStack(alignment: .leading) {
                // Percentage bar behind row
                GeometryReader { geo in
                    ColorPalette.accent.opacity(0.12)
                        .frame(width: geo.size.width * item.percentage)
                }

                HStack(spacing: 8) {
                    // Checkbox
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isChecked ? ColorPalette.accent : ColorPalette.border, lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isChecked ? ColorPalette.accent : Color.clear)
                            )
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Text(item.value)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ColorPalette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Text("\(item.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .background(isChecked ? ColorPalette.accent.opacity(0.08) : Color.clear)
    }

    // MARK: - Helpers

    private func syncPendingFromApplied() {
        pendingSelection = appliedSelection
    }

    private func applySelection() {
        appliedSelection = pendingSelection
        filterViewModel.filterState.selectedCategories[column.name] = Array(appliedSelection)
    }
}

// MARK: - Value Count Helper

private struct ValueCount {
    let value: String
    let count: Int
    let total: Int
    var percentage: Double { total > 0 ? Double(count) / Double(total) : 0 }
}
