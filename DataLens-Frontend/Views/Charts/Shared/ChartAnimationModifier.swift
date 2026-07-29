import SwiftUI

// MARK: - ChartAnimationModifier
//
// A view modifier that adds a smooth enter animation when any chart loads or
// when the data (chartId) changes. Supports three styles:
//   .riseUp   — slide up + fade (bars, histogram, waterfall, funnel)
//   .scaleIn  — scale from 0.8 + fade (pie, donut, gauge, treemap)
//   .sweepIn  — horizontal slide + fade (line, area, scatter, bubble, heatmap)
//   .dropIn   — drop + spring (box plot)
//   .uniform  — gentle fade + subtle scale (default / safe)

// MARK: - Animation Style

enum ChartEnterStyle {
    case riseUp
    case scaleIn
    case sweepIn
    case dropIn
    case uniform
}

// MARK: - ViewModifier

struct ChartEnterAnimationModifier: ViewModifier {

    let style: ChartEnterStyle
    let chartId: String          // change triggers re-animation

    @State private var isVisible: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : scaleStart)
            .offset(x: isVisible ? 0 : offsetX, y: isVisible ? 0 : offsetY)
            .animation(animation, value: isVisible)
            .onAppear { triggerAnimation() }
            .onChange(of: chartId) { _ in
                isVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { triggerAnimation() }
            }
    }

    // MARK: Per-style values

    private var scaleStart: CGFloat {
        switch style {
        case .scaleIn:  return 0.78
        case .dropIn:   return 0.85
        case .riseUp:   return 0.95
        case .sweepIn:  return 1.0
        case .uniform:  return 0.96
        }
    }

    private var offsetX: CGFloat {
        switch style {
        case .sweepIn: return -24
        default: return 0
        }
    }

    private var offsetY: CGFloat {
        switch style {
        case .riseUp: return 20
        case .dropIn: return -16
        default: return 0
        }
    }

    private var animation: Animation {
        switch style {
        case .riseUp:  return .spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)
        case .scaleIn: return .spring(response: 0.5, dampingFraction: 0.72, blendDuration: 0)
        case .sweepIn: return .easeOut(duration: 0.45)
        case .dropIn:  return .spring(response: 0.45, dampingFraction: 0.65, blendDuration: 0)
        case .uniform: return .easeInOut(duration: 0.4)
        }
    }

    private func triggerAnimation() {
        withAnimation(animation) { isVisible = true }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches a chart enter animation.
    /// - Parameters:
    ///   - style: The enter animation style.
    ///   - chartId: A string identifier that, when changed, re-triggers the animation.
    func chartEnterAnimation(style: ChartEnterStyle, chartId: String) -> some View {
        modifier(ChartEnterAnimationModifier(style: style, chartId: chartId))
    }
}

// MARK: - Staggered Bar Animation Helper

/// Wraps a single bar-like element and animates it in with a staggered delay.
/// Use inside ForEach loops in bar/histogram charts.
struct StaggeredBarAnimationModifier: ViewModifier {

    let index: Int
    let totalCount: Int
    let baseDelay: Double

    @State private var isVisible: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(y: isVisible ? 1.0 : 0.05, anchor: .bottom)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.72)
                .delay(staggerDelay),
                value: isVisible
            )
            .onAppear {
                withAnimation { isVisible = true }
            }
    }

    private var staggerDelay: Double {
        let maxStagger = 0.35
        let perItem = maxStagger / max(Double(totalCount), 1.0)
        return baseDelay + Double(index) * perItem
    }
}

extension View {
    func staggeredBarAnimation(index: Int, totalCount: Int, baseDelay: Double = 0.05) -> some View {
        modifier(StaggeredBarAnimationModifier(index: index, totalCount: totalCount, baseDelay: baseDelay))
    }
}

// MARK: - Pulsing Glow Modifier (for live/selected elements)

struct ChartHighlightPulseModifier: ViewModifier {
    let isActive: Bool
    let color: Color

    @State private var pulse: Bool = false

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(pulse ? 0.6 : 0.2) : .clear, radius: pulse ? 10 : 4)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    withAnimation { pulse = false }
                }
            }
    }
}

extension View {
    func chartHighlightPulse(isActive: Bool, color: Color = ColorPalette.accent) -> some View {
        modifier(ChartHighlightPulseModifier(isActive: isActive, color: color))
    }
}
