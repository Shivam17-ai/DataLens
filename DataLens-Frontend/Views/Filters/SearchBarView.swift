import SwiftUI
import Combine

// MARK: - SearchBarView

/// Full-featured global search bar with:
///   - Debounced text input (300ms) tied to FilterViewModel
///   - Search history (up to 10 recent queries)
///   - Scope chip selector (All Columns / Specific columns)
///   - Animated focus ring and clear button
struct SearchBarView: View {

    // MARK: Dependencies
    @ObservedObject var filterViewModel: FilterViewModel
    let dataset: DataSet

    // MARK: Private State
    @State private var isFocused: Bool = false
    @State private var searchText: String = ""
    @State private var searchHistory: [String] = []
    @State private var showHistory: Bool = false
    @State private var selectedScope: SearchScope = .all
    @State private var debounceTask: DispatchWorkItem? = nil

    enum SearchScope: String, CaseIterable {
        case all = "All Columns"
        case text = "Text Only"
        case numbers = "Numbers Only"
    }

    private var textColumns: [Column] {
        dataset.columns.filter { $0.type == .string }
    }
    private var numericColumns: [Column] {
        dataset.columns.filter { $0.type == .number }
    }

    // MARK: Body
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Scope Selector ──────────────────────────────────────────
            scopeSelector

            // ── Search Input ────────────────────────────────────────────
            searchInputField

            // ── History dropdown ─────────────────────────────────────────
            if showHistory && !searchHistory.isEmpty {
                historyDropdown
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: showHistory)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onAppear {
            searchText = filterViewModel.filterState.searchText
        }
    }

    // MARK: - Sub-views

    private var scopeSelector: some View {
        HStack(spacing: 4) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                scopeChip(scope)
            }
        }
    }

    @ViewBuilder
    private func scopeChip(_ scope: SearchScope) -> some View {
        let isSelected = selectedScope == scope
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedScope = scope
                triggerSearch(text: searchText)
            }
        }) {
            Text(scope.rawValue)
                .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : ColorPalette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? ColorPalette.accent : ColorPalette.border.opacity(0.3))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var searchInputField: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isFocused ? ColorPalette.accent : ColorPalette.textSecondary)
                .animation(.easeInOut(duration: 0.2), value: isFocused)

            // Text Field (using Binding to control debounce manually)
            TextField("Search \(scopePlaceholder)…", text: $searchText)
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.textPrimary)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        filterViewModel.filterState.searchText = ""
                    } else {
                        triggerSearch(text: newValue)
                    }
                }
                .onSubmit {
                    commitToHistory(searchText)
                    showHistory = false
                }

            // Clear Button
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // History toggle
            if !searchHistory.isEmpty {
                Button(action: { withAnimation { showHistory.toggle() }}) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(showHistory ? ColorPalette.accent : ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ColorPalette.background.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isFocused ? ColorPalette.accent.opacity(0.8) : ColorPalette.border,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .shadow(color: isFocused ? ColorPalette.accent.opacity(0.15) : .clear, radius: 4)
        .onTapGesture { isFocused = true }
    }

    private var historyDropdown: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Recent Searches", systemImage: "clock")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(ColorPalette.textSecondary)
                Spacer()
                Button("Clear") {
                    withAnimation { searchHistory = [] }
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(ColorPalette.warning)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider().background(ColorPalette.border)

            ForEach(searchHistory.reversed().prefix(5), id: \.self) { query in
                Button(action: {
                    searchText = query
                    triggerSearch(text: query)
                    withAnimation { showHistory = false }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.textSecondary)
                        Text(query)
                            .font(.system(size: 11))
                            .foregroundColor(ColorPalette.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
        }
        .background(ColorPalette.cards)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }

    // MARK: - Helpers

    private var scopePlaceholder: String {
        switch selectedScope {
        case .all: return "all columns"
        case .text: return "text columns"
        case .numbers: return "numbers"
        }
    }

    private func triggerSearch(text: String) {
        debounceTask?.cancel()
        let work = DispatchWorkItem {
            DispatchQueue.main.async {
                filterViewModel.filterState.searchText = text
            }
        }
        debounceTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func clearSearch() {
        withAnimation {
            searchText = ""
            filterViewModel.filterState.searchText = ""
        }
    }

    private func commitToHistory(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchHistory.removeAll { $0 == query }
        searchHistory.append(query)
        if searchHistory.count > 10 { searchHistory.removeFirst() }
    }
}
