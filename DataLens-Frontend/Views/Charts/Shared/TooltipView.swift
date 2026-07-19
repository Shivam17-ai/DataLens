import SwiftUI

/// A premium dark tooltip card displaying category labels, values, and percentage representations.
struct TooltipView: View {
    let title: String
    let value: String
    let percentage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Category/X label
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
                .lineLimit(1)
            
            // Value representation
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(ColorPalette.textPrimary)
                
                if let pct = percentage {
                    Text("(\(pct))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorPalette.success)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ColorPalette.cards)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorPalette.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}
