import SwiftUI
import AppKit

// MARK: - AccessibilityManager

/// Global accessibility utility manager that coordinates VoiceOver helper strings,
/// high contrast mode checking, reduce motion mode flags, and dynamic type adjustments.
@MainActor
final class AccessibilityManager: ObservableObject {
    
    static let shared = AccessibilityManager()
    
    // MARK: - Environmental Adjustments
    
    /// Returns 0 animation duration if reduce motion is enabled, otherwise standard timing.
    func animationDuration(standard: Double, reduceMotionEnabled: Bool) -> Double {
        return reduceMotionEnabled ? 0.0 : standard
    }
    
    /// Returns thicker border width if contrast is increased.
    func borderWidth(standard: CGFloat, increaseContrastEnabled: Bool) -> CGFloat {
        return increaseContrastEnabled ? standard + 1.0 : standard
    }
    
    // MARK: - Screen Reader Summaries
    
    /// Generates dynamic screen reader descriptions for charts
    func accessibilityChartSummary(
        title: String,
        chartType: String,
        xAxis: String?,
        yAxis: String?,
        dataPointsCount: Int,
        maxLabel: String?,
        maxValue: Double?,
        minLabel: String?,
        minValue: Double?
    ) -> String {
        var summary = "Chart titled \(title). This is a \(chartType) chart visualising \(yAxis ?? "values") across \(xAxis ?? "categories") with \(dataPointsCount) data points."
        
        if let maxL = maxLabel, let maxV = maxValue {
            summary += " Highest value is \(maxV.formatted(decimals: 1)) at \(maxL)."
        }
        if let minL = minLabel, let minV = minValue {
            summary += " Lowest value is \(minV.formatted(decimals: 1)) at \(minL)."
        }
        return summary
    }
}
