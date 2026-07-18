import SwiftUI

// MARK: - Metallic Loading View

/// LoadingView displays a premium rotating metallic ring with a pulsing center dot.
struct LoadingView: View {
    let message: String?
    
    @State private var rotationAngle = 0.0
    @State private var pulseScale = 0.8
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer rotating ring
                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [ColorPalette.success, ColorPalette.accent, ColorPalette.success],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(rotationAngle))
                
                // Pulsing dot
                Circle()
                    .fill(ColorPalette.success)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulseScale)
            }
            .onAppear {
                // Continuous rotation animation
                withAnimation(
                    Animation.linear(duration: 1.0)
                        .repeatForever(autoreverses: false)
                ) {
                    rotationAngle = 360.0
                }
                
                // Continuous pulsing scale animation
                withAnimation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.3
                }
            }
            
            if let msg = message {
                Text(msg)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Table Skeleton Loader

/// Renders a skeleton grid representation of the spreadsheet cells using shimmer states.
struct TableSkeletonView: View {
    var body: some View {
        VStack(spacing: 8) {
            // Header Row Skeleton
            HStack(spacing: 12) {
                Spacer().frame(width: 50)
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ColorPalette.border.opacity(0.6))
                        .frame(height: 32)
                        .shimmer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Divider().background(ColorPalette.border)
            
            // Grid Rows Skeletons
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<10, id: \.self) { rIndex in
                        HStack(spacing: 12) {
                            // Row Number Skeleton
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorPalette.border.opacity(0.4))
                                .frame(width: 32, height: 20)
                                .shimmer()
                            
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(ColorPalette.border.opacity(0.4))
                                    .frame(height: 20)
                                    .shimmer()
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(ColorPalette.background)
    }
}
