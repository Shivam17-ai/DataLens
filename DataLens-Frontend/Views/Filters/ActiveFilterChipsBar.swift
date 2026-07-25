import SwiftUI

/// ActiveFilterChipsBar displays a horizontal scrollable list of active filter chips.
/// Each chip has a pill-shape, height of 28pt, and a clear button.
struct ActiveFilterChipsBar: View {
    @ObservedObject var crossFilterManager: CrossFilterManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.accent)
                .padding(.leading, 16)
            
            Text("Active Filters:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(crossFilterManager.activeFilters) { filter in
                        HStack(spacing: 6) {
                            Text(filter.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    crossFilterManager.removeFilter(id: filter.id)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .frame(height: 28) // Requirement: 28pt height
                        .background(
                            Capsule()
                                .fill(ColorPalette.accent)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, 6)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    crossFilterManager.clearAllFilters()
                }
            }) {
                Text("Clear All")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ColorPalette.warning)
                    .padding(.trailing, 16)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 38)
        .background(ColorPalette.sidebar.opacity(0.4))
        .overlay(
            VStack {
                Spacer()
                Rectangle().fill(ColorPalette.border).frame(height: 1)
            }
        )
    }
}
