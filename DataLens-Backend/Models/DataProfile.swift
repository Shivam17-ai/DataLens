import Foundation

// MARK: - Issue Severity & Type

/// Severity level of a data quality issue
enum IssueSeverity: String, Codable, CaseIterable {
    case high   = "High"
    case medium = "Medium"
    case low    = "Low"
}

/// A specific data quality issue identified during profiling
struct DataQualityIssue: Identifiable, Hashable {
    let id = UUID()
    let columnName: String?
    let description: String
    let severity: IssueSeverity
}

// MARK: - Quality Score

/// Breakdown of the data quality score logic
struct QualityScore: Hashable {
    let score: Double // 0 to 100
    let missingPenalty: Double
    let duplicatePenalty: Double
    let consistencyScore: Double
    let outlierPenalty: Double
}

// MARK: - Tab Overview Structs

/// Dataset-wide statistics and metrics
struct DatasetOverview: Hashable {
    let filename: String
    let importDate: Date
    let rowCount: Int
    let columnCount: Int
    let missingCount: Int
    let missingPercentage: Double
    let duplicateCount: Int
    let duplicatePercentage: Double
    let memorySizeEstimate: String
}

// MARK: - Column Detail Profiles

/// Numeric-specific profile stats
struct NumberProfile: Hashable {
    let mean: Double
    let median: Double
    let mode: Double
    let stdDev: Double
    let variance: Double
    let min: Double
    let max: Double
    let range: Double
    let q1: Double
    let q2: Double
    let q3: Double
    let skewness: Double
    let kurtosis: Double
    let outlierCount: Int
    let histogram: [Int] // 10 bins
}

/// Text-specific profile stats
struct TextProfile: Hashable {
    let averageLength: Double
    let minLength: Int
    let maxLength: Int
    let emptyStringCount: Int
}

/// Date-specific profile stats
struct DateProfile: Hashable {
    let earliestDate: Date?
    let latestDate: Date?
    let rangeSpanDays: Double
    let mostCommonYear: Int?
    let mostCommonMonth: Int?
    let timelineDensity: [DateDensityPoint] // 10 segments for timeline density
}

struct DateDensityPoint: Hashable, Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

/// Frequent values distribution row
struct FrequentValue: Hashable, Identifiable {
    let id = UUID()
    let value: String
    let count: Int
    let percentage: Double
}

/// Container for column-specific profiled metrics
struct ColumnProfile: Identifiable, Hashable {
    let id = UUID()
    let columnName: String
    let columnType: ColumnType
    let missingCount: Int
    let missingPercentage: Double
    let uniqueCount: Int
    let uniquePercentage: Double
    let topValues: [FrequentValue]
    let numberProfile: NumberProfile?
    let textProfile: TextProfile?
    let dateProfile: DateProfile?
}

// MARK: - Correlation Heatmap Structs

/// Symmetric pearson correlation matrix for numeric columns
struct CorrelationMatrix: Hashable {
    let columns: [String]
    let values: [[Double]] // columns.count x columns.count correlation coefficients
}

// MARK: - Master Profile Object

/// Cached master struct containing the completed profiled dataset
struct FullDataProfile: Hashable {
    let overview: DatasetOverview
    let qualityScore: QualityScore
    let columnDistribution: [ColumnType: Int]
    let issues: [DataQualityIssue]
    let columnProfiles: [ColumnProfile]
    let correlations: CorrelationMatrix
}
