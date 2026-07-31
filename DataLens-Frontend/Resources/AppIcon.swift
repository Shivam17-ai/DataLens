import SwiftUI

/// Programmatic macOS App Icon generator using SwiftUI Canvas
struct AppIcon: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            
            // 1. Dark metallic background
            context.fill(Path(rect), with: .color(Color(hex: "#1A1A2E")))
            
            // 2. Subtle gradient overlay
            let gradient = Gradient(colors: [Color(hex: "#533483").opacity(0.3), .clear])
            context.fill(Path(rect), with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            
            // 3. Draw a modern clean Monogram "DL"
            let monogramString = "DL"
            let font = Font.system(size: size.width * 0.4, weight: .bold, design: .sansSerif)
            
            // Split letters "D" and "L" to apply individual highlight colors
            // Letter D: #00B4D8 cyan
            // Letter L: #533483 purple
            let dRect = CGRect(x: size.width * 0.18, y: size.height * 0.22, width: size.width * 0.35, height: size.height * 0.5)
            let lRect = CGRect(x: size.width * 0.50, y: size.height * 0.22, width: size.width * 0.35, height: size.height * 0.5)
            
            // Apply glow effect around letters
            context.addFilter(.shadow(color: Color(hex: "#00B4D8").opacity(0.5), radius: size.width * 0.05, x: 0, y: 0))
            context.draw(Text("D").font(font).foregroundColor(Color(hex: "#00B4D8")), in: dRect)
            
            context.addFilter(.shadow(color: Color(hex: "#533483").opacity(0.5), radius: size.width * 0.05, x: 0, y: 0))
            context.draw(Text("L").font(font).foregroundColor(Color(hex: "#533483")), in: lRect)
            
            // 4. Draw a small bar chart icon below monogram
            let barWidth = size.width * 0.06
            let spacing = size.width * 0.03
            let startY = size.height * 0.78
            let maxHeight = size.height * 0.12
            
            let barColors = [Color(hex: "#00B4D8"), Color(hex: "#533483"), Color(hex: "#F59E0B")]
            let heightsRatio: [CGFloat] = [0.4, 1.0, 0.7]
            
            let startX = size.width * 0.5 - (barWidth * 1.5 + spacing)
            
            for i in 0..<3 {
                let x = startX + CGFloat(i) * (barWidth + spacing)
                let height = maxHeight * heightsRatio[i]
                let barRect = CGRect(x: x, y: startY - height, width: barWidth, height: height)
                
                context.fill(Path(barRect), with: .color(barColors[i]))
            }
        }
        .frame(width: 512, height: 512)
    }
}
