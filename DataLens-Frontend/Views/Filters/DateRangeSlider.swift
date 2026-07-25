import SwiftUI
import Combine

// MARK: - DateRangeSlider

/// A fully custom double-handled date range slider with:
///  - Mini timeline histogram above the track
///  - Live date labels below each handle
///  - Preset quick-select buttons (Last 7d, 30d, 90d, This Year, All Time)
///  - Debounced 200 ms updates via CrossFilterManager
struct DateRangeSlider: View {

    // MARK: Dependencies

    @ObservedObject var filterViewModel: FilterViewModel
    @EnvironmentObject var crossFilterManager: CrossFilterManager

    /// The dataset used to determine date bounds and histogram bins
    let dataset: DataSet
    /// The date column being filtered
    let dateColumn: Column

    // MARK: Layout Constants

    private let trackHeight: CGFloat = 4
    private let handleDiameter: CGFloat = 20
    private let histogramHeight: CGFloat = 36
    private let labelFont = Font.system(size: 10, weight: .semibold)

    // MARK: Internal State

    @State private var minDate: Date = Date()
    @State private var maxDate: Date = Date()
    @State private var fromDate: Date = Date()
    @State private var toDate: Date = Date()
    @State private var histogramBins: [Int] = []
    @State private var isDraggingLeft: Bool = false
    @State private var isDraggingRight: Bool = false
    @State private var activePreset: DatePreset? = .allTime
    @State private var debounceTask: DispatchWorkItem? = nil

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ColorPalette.accent)
                Text(dateColumn.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                Text(rangeLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ColorPalette.success)
            }

            // Preset buttons
            presetButtonsRow

            // Mini histogram + slider track
            GeometryReader { geo in
                let trackWidth = geo.size.width - handleDiameter
                let leftFraction  = fraction(for: fromDate)
                let rightFraction = fraction(for: toDate)
                let leftX  = handleDiameter / 2 + leftFraction  * trackWidth
                let rightX = handleDiameter / 2 + rightFraction * trackWidth

                VStack(spacing: 6) {
                    // Mini timeline histogram
                    histogramView(trackWidth: trackWidth)

                    // Slider track + handles
                    ZStack(alignment: .leading) {
                        // Full track (dark)
                        RoundedRectangle(cornerRadius: trackHeight / 2)
                            .fill(ColorPalette.border)
                            .frame(height: trackHeight)

                        // Selected range track (accent with glow)
                        Rectangle()
                            .fill(ColorPalette.accent)
                            .frame(width: max(0, rightX - leftX), height: trackHeight)
                            .offset(x: leftX)
                            .shadow(color: ColorPalette.accent.opacity(0.5), radius: 3)

                        // Left handle
                        handleView(isDragging: isDraggingLeft)
                            .offset(x: leftX - handleDiameter / 2)
                            .gesture(leftHandleDrag(trackWidth: trackWidth, geo: geo))

                        // Right handle
                        handleView(isDragging: isDraggingRight)
                            .offset(x: rightX - handleDiameter / 2)
                            .gesture(rightHandleDrag(trackWidth: trackWidth, geo: geo))
                    }
                    .frame(height: handleDiameter)

                    // Date labels below handles
                    ZStack(alignment: .leading) {
                        Text(formatted(fromDate))
                            .font(labelFont)
                            .foregroundColor(ColorPalette.textSecondary)
                            .offset(x: max(0, min(leftX - 30, geo.size.width - 80)))

                        Text(formatted(toDate))
                            .font(labelFont)
                            .foregroundColor(ColorPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(x: min(0, rightX - geo.size.width + 30))
                    }
                    .frame(height: 14)
                }
            }
            .frame(height: histogramHeight + handleDiameter + 20)
        }
        .padding(14)
        .background(ColorPalette.cards.opacity(0.4))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ColorPalette.border, lineWidth: 1))
        .onAppear { setup() }
        .onChange(of: dataset.id) { _ in setup() }
    }

    // MARK: Sub-views

    private var presetButtonsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DatePreset.allCases, id: \.self) { preset in
                    Button(action: { applyPreset(preset) }) {
                        Text(preset.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(activePreset == preset ? .white : ColorPalette.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(activePreset == preset ? ColorPalette.accent : ColorPalette.border.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func histogramView(trackWidth: CGFloat) -> some View {
        if !histogramBins.isEmpty {
            let maxBin = histogramBins.max() ?? 1
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(histogramBins.enumerated()), id: \.offset) { idx, count in
                    let height = maxBin > 0 ? (CGFloat(count) / CGFloat(maxBin)) * histogramHeight : 2
                    let binFraction = (Double(idx) + 0.5) / Double(histogramBins.count)
                    let inRange = binFraction >= fraction(for: fromDate) && binFraction <= fraction(for: toDate)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(inRange ? ColorPalette.accent.opacity(0.7) : ColorPalette.border.opacity(0.4))
                        .frame(height: max(2, height))
                }
            }
            .frame(height: histogramHeight)
            .padding(.horizontal, handleDiameter / 2)
        }
    }

    private func handleView(isDragging: Bool) -> some View {
        Circle()
            .fill(ColorPalette.accent)
            .frame(width: handleDiameter, height: handleDiameter)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: isDragging ? ColorPalette.accent.opacity(0.6) : Color.black.opacity(0.3),
                    radius: isDragging ? 8 : 3)
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
    }

    // MARK: Gesture Builders

    private func leftHandleDrag(trackWidth: CGFloat, geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDraggingLeft = true
                activePreset = nil
                let x = value.location.x - handleDiameter / 2
                let frac = max(0, min(x / trackWidth, fraction(for: toDate) - 0.001))
                let newDate = snapToDay(date(from: frac))
                if newDate < toDate { fromDate = newDate }
                debounceUpdate()
            }
            .onEnded { _ in isDraggingLeft = false }
    }

    private func rightHandleDrag(trackWidth: CGFloat, geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDraggingRight = true
                activePreset = nil
                let x = value.location.x - handleDiameter / 2
                let frac = max(fraction(for: fromDate) + 0.001, min(x / trackWidth, 1.0))
                let newDate = snapToDay(date(from: frac))
                if newDate > fromDate { toDate = newDate }
                debounceUpdate()
            }
            .onEnded { _ in isDraggingRight = false }
    }

    // MARK: Computation Helpers

    private func setup() {
        let dates = filterViewModel.extractDates(from: dataset, column: dateColumn.name)
        guard !dates.isEmpty, let lo = dates.min(), let hi = dates.max() else { return }

        minDate = lo
        maxDate = hi

        if let existing = filterViewModel.dateRange,
           existing.columnName == dateColumn.name {
            fromDate = existing.from
            toDate   = existing.to
        } else {
            fromDate = lo
            toDate   = hi
        }

        histogramBins = filterViewModel.buildDateHistogram(from: dataset, column: dateColumn.name, binCount: 40)
    }

    private func fraction(for date: Date) -> Double {
        let span = maxDate.timeIntervalSince(minDate)
        guard span > 0 else { return 0 }
        return max(0, min(1, date.timeIntervalSince(minDate) / span))
    }

    private func date(from fraction: Double) -> Date {
        let span = maxDate.timeIntervalSince(minDate)
        return minDate.addingTimeInterval(fraction * span)
    }

    private func snapToDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private var rangeLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return "\(df.string(from: fromDate)) – \(df.string(from: toDate))"
    }

    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d yyyy"
        return df.string(from: date)
    }

    /// Debounce: wait 200 ms after last handle move before publishing the filter
    private func debounceUpdate() {
        debounceTask?.cancel()
        let work = DispatchWorkItem { [self] in
            let range = DateRangeFilter(from: fromDate, to: toDate, columnName: dateColumn.name)
            DispatchQueue.main.async {
                filterViewModel.setDateRange(range)
            }
        }
        debounceTask = work
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func applyPreset(_ preset: DatePreset) {
        activePreset = preset
        let (newFrom, newTo) = preset.dateRange(relativeTo: maxDate, dataMin: minDate)
        fromDate = max(minDate, newFrom)
        toDate   = min(maxDate, newTo)
        debounceUpdate()
    }
}

// MARK: - Date Preset

enum DatePreset: CaseIterable {
    case last7days, last30days, last90days, thisYear, allTime

    var label: String {
        switch self {
        case .last7days:  return "Last 7d"
        case .last30days: return "Last 30d"
        case .last90days: return "Last 90d"
        case .thisYear:   return "This Year"
        case .allTime:    return "All Time"
        }
    }

    /// Returns (from, to) for this preset relative to the reference date
    func dateRange(relativeTo reference: Date, dataMin: Date) -> (Date, Date) {
        let cal = Calendar.current
        switch self {
        case .last7days:
            return (cal.date(byAdding: .day, value: -7, to: reference) ?? dataMin, reference)
        case .last30days:
            return (cal.date(byAdding: .day, value: -30, to: reference) ?? dataMin, reference)
        case .last90days:
            return (cal.date(byAdding: .day, value: -90, to: reference) ?? dataMin, reference)
        case .thisYear:
            let comps = cal.dateComponents([.year], from: reference)
            let jan1 = cal.date(from: comps) ?? dataMin
            return (jan1, reference)
        case .allTime:
            return (dataMin, reference)
        }
    }
}
