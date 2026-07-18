import SwiftUI

/// Reusable EmptyStateView displaying a large muted icon, headline title, secondary text, and optional action button.
struct EmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String
    let actionButtonTitle: String?
    let action: (() -> Void)?
    
    init(
        iconName: String,
        title: String,
        subtitle: String,
        actionButtonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName          = iconName
        self.title             = title
        self.subtitle          = subtitle
        self.actionButtonTitle = actionButtonTitle
        self.action            = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Large muted icon
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(ColorPalette.textSecondary.opacity(0.5))
                .padding(.bottom, 8)
            
            // Headline text
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
            
            // Supporting text
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .lineSpacing(4)
                .padding(.bottom, 8)
            
            // Action button
            if let btnTitle = actionButtonTitle, let act = action {
                Button(action: act) {
                    Text(btnTitle)
                }
                .primaryStyle()
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}
