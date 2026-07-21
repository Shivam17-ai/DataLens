import SwiftUI

/// PieSliceItem contains calculated geometry and colors for individual slices.
struct PieSliceItem: Identifiable, Equatable {
    let id: UUID
    let point: ChartDataPoint
    let startAngle: Double
    let endAngle: Double
    let midAngle: Double
    let percentage: Double
    let color: Color
    let isOther: Bool
    
    var dx: CGFloat {
        let radians = midAngle * .pi / 180.0
        return CGFloat(cos(radians) * 12.0)
    }
    
    var dy: CGFloat {
        let radians = midAngle * .pi / 180.0
        return CGFloat(sin(radians) * 12.0)
    }
}

/// PieSliceBase handles slice calculations, angles, fanning layouts,
/// and color mappings for both Pie and Donut chart views.
struct PieSliceBase {
    static func buildSlices(
        from data: ChartData,
        config: ChartConfig,
        colors: [Color]
    ) -> [PieSliceItem] {
        let total = data.points.map { $0.y }.reduce(0, +)
        guard total > 0 else { return [] }
        
        var slices: [PieSliceItem] = []
        var currentAngle = config.pieStartAngle
        let totalArc = config.semiCircleMode ? 180.0 : 360.0
        
        for (index, pt) in data.points.enumerated() {
            let percentage = pt.y / total
            // Enforce minimum slice angle of 3 degrees
            let minAngle = 3.0
            var angleWidth = percentage * totalArc
            if angleWidth < minAngle {
                angleWidth = minAngle
            }
            
            let midAngle = currentAngle + angleWidth / 2.0
            
            let isOther = pt.x == "Other"
            let color = isOther ? Color(hex: "#A0A0B0") : colors[index % colors.count]
            
            slices.append(PieSliceItem(
                id: pt.id,
                point: pt,
                startAngle: currentAngle,
                endAngle: currentAngle + angleWidth,
                midAngle: midAngle,
                percentage: percentage,
                color: color,
                isOther: isOther
            ))
            
            currentAngle += angleWidth
        }
        
        return slices
    }
}
