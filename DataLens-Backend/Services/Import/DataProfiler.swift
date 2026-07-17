import Foundation

/// Service that executes dataset profiling and metrics analysis on background threads.
struct DataProfiler {

    /// Profiles a given dataset completely. Runs on a background thread.
    static func profile(dataset: DataSet) async -> FullDataProfile {
        return await Task.detached(priority: .userInitiated) {
            let rowCount = dataset.rows.count
            let colCount = dataset.columns.count

            // 1. Gather counts and cell types
            var totalCells = rowCount * colCount
            if totalCells == 0 { totalCells = 1 }

            var missingCount = 0
            var duplicateCount = 0
            var memorySizeBytes: Int64 = 0

            // Estimate memory size and count missing cells
            for row in dataset.rows {
                for col in dataset.columns {
                    if let val = row.values[col.name] {
                        if let str = val as? String {
                            memorySizeBytes += Int64(str.utf8.count)
                            if str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                missingCount += 1
                            }
                        } else if val is Double {
                            memorySizeBytes += 8
                        } else if val is Date {
                            memorySizeBytes += 8
                        } else {
                            memorySizeBytes += 16
                        }
                    } else {
                        missingCount += 1
                    }
                }
            }

            // Estimate duplicates
            var seenRows = Set<String>()
            for row in dataset.rows {
                let serialized = dataset.columns.map { col -> String in
                    if let v = row.values[col.name] {
                        return String(describing: v)
                    }
                    return ""
                }.joined(separator: "||")
                if seenRows.contains(serialized) {
                    duplicateCount += 1
                } else {
                    seenRows.insert(serialized)
                }
            }

            // Memory size string format
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB]
            byteCountFormatter.countStyle = .binary
            let memorySizeStr = byteCountFormatter.string(fromByteCount: memorySizeBytes)

            // Overview stats
            let missingPercentage = (Double(missingCount) / Double(totalCells)) * 100.0
            let duplicatePercentage = (Double(duplicateCount) / Double(max(1, rowCount))) * 100.0

            let overview = DatasetOverview(
                filename: dataset.name,
                importDate: dataset.importedAt,
                rowCount: rowCount,
                columnCount: colCount,
                missingCount: missingCount,
                missingPercentage: missingPercentage,
                duplicateCount: duplicateCount,
                duplicatePercentage: duplicatePercentage,
                memorySizeEstimate: memorySizeStr
            )

            // Column Type distribution
            var columnDistribution: [ColumnType: Int] = [.number: 0, .text: 0, .date: 0]
            for col in dataset.columns {
                columnDistribution[col.type, default: 0] += 1
            }

            // 2. Profile columns
            var colProfiles: [ColumnProfile] = []
            var totalOutliers = 0

            for col in dataset.columns {
                let profile = self.profileColumn(dataset: dataset, column: col)
                colProfiles.append(profile)
                if let numProfile = profile.numberProfile {
                    totalOutliers += numProfile.outlierCount
                }
            }

            // 3. Compute quality score
            let missingPenalty = min(30.0, missingPercentage * 3.0)
            let duplicatePenalty = min(20.0, duplicatePercentage * 2.0)
            let outlierRatio = Double(totalOutliers) / Double(max(1, rowCount))
            let outlierPenalty = min(20.0, outlierRatio * 100.0)
            let consistencyScore = 100.0 - missingPenalty - duplicatePenalty - outlierPenalty
            let score = QualityScore(
                score: max(0.0, min(100.0, consistencyScore)),
                missingPenalty: missingPenalty,
                duplicatePenalty: duplicatePenalty,
                consistencyScore: consistencyScore,
                outlierPenalty: outlierPenalty
            )

            // 4. Generate issues
            let issues = self.detectIssues(dataset: dataset, overview: overview, profiles: colProfiles)

            // 5. Compute numeric correlations
            let correlations = self.computeCorrelations(dataset: dataset)

            return FullDataProfile(
                overview: overview,
                qualityScore: score,
                columnDistribution: columnDistribution,
                issues: issues,
                columnProfiles: colProfiles,
                correlations: correlations
            )
        }.value
    }

    // MARK: - Private Profiling Subroutines

    private static func profileColumn(dataset: DataSet, column: Column) -> ColumnProfile {
        let rows = dataset.rows
        let rowCount = max(1, rows.count)
        let colName = column.name

        // Collect non-nil raw cell values
        var nonNilValues: [Any] = []
        var missingCount = 0

        for row in rows {
            if let val = row.values[colName] {
                if let str = val as? String, str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    missingCount += 1
                } else {
                    nonNilValues.append(val)
                }
            } else {
                missingCount += 1
            }
        }

        let missingPercentage = (Double(missingCount) / Double(rowCount)) * 100.0

        // Unique count & frequencies
        var stringRepMap: [String: Int] = [:]
        for val in nonNilValues {
            let str = self.formatValue(val)
            stringRepMap[str, default: 0] += 1
        }

        let uniqueCount = stringRepMap.count
        let uniquePercentage = (Double(uniqueCount) / Double(max(1, nonNilValues.count))) * 100.0

        // Sort for top values
        let sortedFrequencies = stringRepMap.sorted { $0.value > $1.value }
        let topValues: [FrequentValue] = sortedFrequencies.prefix(5).map { item in
            FrequentValue(
                value: item.key,
                count: item.value,
                percentage: (Double(item.value) / Double(max(1, nonNilValues.count))) * 100.0
            )
        }

        // Subprofiles based on column type
        var numberProfile: NumberProfile? = nil
        var textProfile: TextProfile? = nil
        var dateProfile: DateProfile? = nil

        switch column.type {
        case .number:
            let nums = nonNilValues.compactMap { $0 as? Double }.sorted()
            if !nums.isEmpty {
                let count = Double(nums.count)
                let sum = nums.reduce(0.0, +)
                let mean = sum / count
                
                // Median
                let mid = nums.count / 2
                let median = nums.count % 2 == 0 ? (nums[mid - 1] + nums[mid]) / 2.0 : nums[mid]
                
                // Mode
                var modeVal = 0.0
                if let topValStr = topValues.first?.value, let dVal = Double(topValStr) {
                    modeVal = dVal
                } else {
                    modeVal = median
                }

                // Variance & StdDev
                let sumSquares = nums.map { pow($0 - mean, 2.0) }.reduce(0.0, +)
                let variance = sumSquares / max(1.0, count)
                let stdDev = sqrt(variance)

                // Quartiles
                let q1 = nums[nums.count / 4]
                let q2 = median
                let q3 = nums[(nums.count * 3) / 4]
                
                // Min, Max, Range
                let minVal = nums.first ?? 0.0
                let maxVal = nums.last ?? 0.0
                let rangeVal = maxVal - minVal

                // Skewness & Kurtosis
                var skewness = 0.0
                var kurtosis = 0.0
                if stdDev > 0 {
                    let skewSum = nums.map { pow(($0 - mean) / stdDev, 3.0) }.reduce(0.0, +)
                    skewness = skewSum / max(1.0, count)

                    let kurtSum = nums.map { pow(($0 - mean) / stdDev, 4.0) }.reduce(0.0, +)
                    kurtosis = (kurtSum / max(1.0, count)) - 3.0
                }

                // IQR Outliers
                let iqr = q3 - q1
                let lowerBound = q1 - 1.5 * iqr
                let upperBound = q3 + 1.5 * iqr
                let outlierCount = nums.filter { $0 < lowerBound || $0 > upperBound }.count

                // 10 Bins Histogram
                var histogram = Array(repeating: 0, count: 10)
                if rangeVal > 0 {
                    let binWidth = rangeVal / 10.0
                    for num in nums {
                        let binIndex = min(9, Int(floor((num - minVal) / binWidth)))
                        if binIndex >= 0 && binIndex < 10 {
                            histogram[binIndex] += 1
                        }
                    }
                } else if !nums.isEmpty {
                    histogram[0] = nums.count
                }

                numberProfile = NumberProfile(
                    mean: mean,
                    median: median,
                    mode: modeVal,
                    stdDev: stdDev,
                    variance: variance,
                    min: minVal,
                    max: maxVal,
                    range: rangeVal,
                    q1: q1,
                    q2: q2,
                    q3: q3,
                    skewness: skewness,
                    kurtosis: kurtosis,
                    outlierCount: outlierCount,
                    histogram: histogram
                )
            }
            
        case .text:
            let texts = nonNilValues.map { String(describing: $0) }
            let lengths = texts.map { $0.count }
            let avgLength = Double(lengths.reduce(0, +)) / Double(max(1, texts.count))
            let minLen = lengths.min() ?? 0
            let maxLen = lengths.max() ?? 0
            
            var emptyStringCount = 0
            for t in texts {
                if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emptyStringCount += 1
                }
            }

            textProfile = TextProfile(
                averageLength: avgLength,
                minLength: minLen,
                maxLength: maxLen,
                emptyStringCount: emptyStringCount
            )
            
        case .date:
            let dates = nonNilValues.compactMap { $0 as? Date }.sorted()
            if !dates.isEmpty {
                let earliest = dates.first
                let latest = dates.last
                let spanDays = (latest?.timeIntervalSince(earliest ?? Date()) ?? 0.0) / 86400.0

                // Years and Months modes
                var yearsMap: [Int: Int] = [:]
                var monthsMap: [Int: Int] = [:]
                let calendar = Calendar.current

                for date in dates {
                    let year = calendar.component(.year, from: date)
                    let month = calendar.component(.month, from: date)
                    yearsMap[year, default: 0] += 1
                    monthsMap[month, default: 0] += 1
                }

                let mostCommonYear = yearsMap.max { $0.value < $1.value }?.key
                let mostCommonMonth = monthsMap.max { $0.value < $1.value }?.key

                // Timeline Density (10 segments)
                var timelinePoints: [DateDensityPoint] = []
                if let start = earliest, let end = latest, spanDays > 0 {
                    let interval = end.timeIntervalSince(start) / 10.0
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd/yy"

                    for i in 0..<10 {
                        let segStart = start.addingTimeInterval(interval * Double(i))
                        let segEnd = start.addingTimeInterval(interval * Double(i + 1))
                        let count = dates.filter { $0 >= segStart && $0 < segEnd }.count
                        timelinePoints.append(DateDensityPoint(
                            label: formatter.string(from: segStart),
                            count: count
                        ))
                    }
                } else if let single = earliest {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd/yy"
                    timelinePoints = [DateDensityPoint(label: formatter.string(from: single), count: dates.count)]
                }

                dateProfile = DateProfile(
                    earliestDate: earliest,
                    latestDate: latest,
                    rangeSpanDays: spanDays,
                    mostCommonYear: mostCommonYear,
                    mostCommonMonth: mostCommonMonth,
                    timelineDensity: timelinePoints
                )
            }
        }

        return ColumnProfile(
            columnName: colName,
            columnType: column.type,
            missingCount: missingCount,
            missingPercentage: missingPercentage,
            uniqueCount: uniqueCount,
            uniquePercentage: uniquePercentage,
            topValues: topValues,
            numberProfile: numberProfile,
            textProfile: textProfile,
            dateProfile: dateProfile
        )
    }

    private static func detectIssues(
        dataset: DataSet,
        overview: DatasetOverview,
        profiles: [ColumnProfile]
    ) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []

        // 1. Dataset wide checks
        if overview.duplicatePercentage > 10.0 {
            issues.append(DataQualityIssue(
                columnName: nil,
                description: String(format: "High duplicate rate (%.1f%%). Consider removing duplicate rows.", overview.duplicatePercentage),
                severity: .high
            ))
        } else if overview.duplicateCount > 0 {
            issues.append(DataQualityIssue(
                columnName: nil,
                description: "\(overview.duplicateCount) duplicate rows detected.",
                severity: .medium
            ))
        }

        if overview.missingPercentage > 15.0 {
            issues.append(DataQualityIssue(
                columnName: nil,
                description: String(format: "High missing values rate (%.1f%%) across the dataset.", overview.missingPercentage),
                severity: .high
            ))
        }

        // 2. Column specific checks
        for profile in profiles {
            let colName = profile.columnName

            if profile.missingPercentage > 20.0 {
                issues.append(DataQualityIssue(
                    columnName: colName,
                    description: String(format: "Column '%@' has %.1f%% missing values.", colName, profile.missingPercentage),
                    severity: .high
                ))
            } else if profile.missingCount > 0 {
                issues.append(DataQualityIssue(
                    columnName: colName,
                    description: String(format: "Column '%@' has %d missing value(s).", colName, profile.missingCount),
                    severity: .medium
                ))
            }

            if let num = profile.numberProfile {
                if num.outlierCount > 10 {
                    issues.append(DataQualityIssue(
                        columnName: colName,
                        description: "Column '\(colName)' has \(num.outlierCount) statistical outliers.",
                        severity: .medium
                    ))
                } else if num.outlierCount > 0 {
                    issues.append(DataQualityIssue(
                        columnName: colName,
                        description: "Column '\(colName)' has \(num.outlierCount) outliers.",
                        severity: .low
                    ))
                }
            }

            if let txt = profile.textProfile {
                if profile.uniquePercentage > 95.0 && profile.columnType == .text && dataset.rowCount > 50 {
                    // Check if text column might be an ID or primary key
                    issues.append(DataQualityIssue(
                        columnName: colName,
                        description: "Column '\(colName)' has very high cardinality (\(profile.uniqueCount) unique values).",
                        severity: .low
                    ))
                }
            }
        }

        return issues
    }

    private static func computeCorrelations(dataset: DataSet) -> CorrelationMatrix {
        // Find numeric columns
        let numCols = dataset.columns.filter { $0.type == .number }.map { $0.name }
        guard numCols.count >= 2 else {
            return CorrelationMatrix(columns: [], values: [])
        }

        let rowCount = dataset.rows.count
        var columnsData: [String: [Double]] = [:]

        // Extract numbers and impute missing values with mean for calculation
        for colName in numCols {
            var colValues: [Double] = []
            var sum = 0.0
            var count = 0

            for row in dataset.rows {
                if let v = row.values[colName] as? Double {
                    colValues.append(v)
                    sum += v
                    count += 1
                } else {
                    colValues.append(Double.nan)
                }
            }

            let mean = count > 0 ? (sum / Double(count)) : 0.0
            // Impute nan with mean
            let imputedValues = colValues.map { $0.isNaN ? mean : $0 }
            columnsData[colName] = imputedValues
        }

        var valuesMatrix = Array(repeating: Array(repeating: 0.0, count: numCols.count), count: numCols.count)

        for i in 0..<numCols.count {
            for j in i..<numCols.count {
                let colA = numCols[i]
                let colB = numCols[j]

                guard let arrA = columnsData[colA], let arrB = columnsData[colB], arrA.count == arrB.count else {
                    continue
                }

                let correlation = self.pearsonCorrelation(arrA, arrB)
                valuesMatrix[i][j] = correlation
                valuesMatrix[j][i] = correlation
            }
        }

        return CorrelationMatrix(columns: numCols, values: valuesMatrix)
    }

    private static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, !x.isEmpty else { return 0.0 }
        let n = Double(x.count)

        let sumX = x.reduce(0.0, +)
        let sumY = y.reduce(0.0, +)

        let sumX2 = x.map { $0 * $0 }.reduce(0.0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0.0, +)

        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0.0, +)

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        if denominator == 0 { return 0.0 }
        return numerator / denominator
    }

    private static func formatValue(_ value: Any) -> String {
        if let d = value as? Date {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }
        if let n = value as? Double {
            return n.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", n) : String(n)
        }
        return String(describing: value)
    }
}
