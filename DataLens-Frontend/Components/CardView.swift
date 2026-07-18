import SwiftUI

/// Reusable styling container representing the premium metallic cards in DataLens.
/// Implements 16pt padding, card style gradients, and hover lifts.
struct CardView<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16) // Always 16pt inner padding
        .cardStyle(isHovered: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                isHovered = hovering
            }
        }
    }
}
