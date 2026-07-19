import SwiftUI

/// LegendView displays colored labels for series, with click to toggle highlight and double click to isolate.
struct LegendView: View {
    let seriesList: [String]
    let colors: [Color]
    @Binding var highlightedSeries: Set<String>
    
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 220))],
            alignment: .center,
            spacing: 8
        ) {
            ForEach(Array(seriesList.enumerated()), id: \.offset) { index, series in
                let color = colors[index % colors.count]
                // If set is empty, nothing is isolated/muted (everything highlighted).
                // Otherwise, only items inside the set are highlighted.
                let isHighlighted = highlightedSeries.isEmpty || highlightedSeries.contains(series)
                let isMuted = !isHighlighted
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(isMuted ? Color.gray.opacity(0.3) : color)
                        .frame(width: 8, height: 8)
                    
                    Text(series)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isMuted ? ColorPalette.textSecondary.opacity(0.4) : ColorPalette.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isMuted ? Color.clear : ColorPalette.cards)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isMuted ? ColorPalette.border.opacity(0.3) : ColorPalette.border, lineWidth: 1)
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                        if highlightedSeries.count == 1 && highlightedSeries.contains(series) {
                            highlightedSeries.removeAll()
                        } else {
                            highlightedSeries = [series]
                        }
                    }
                }
                .onTapGesture(count: 1) {
                    withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                        if highlightedSeries.contains(series) {
                            highlightedSeries.remove(series)
                        } else {
                            highlightedSeries.insert(series)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
