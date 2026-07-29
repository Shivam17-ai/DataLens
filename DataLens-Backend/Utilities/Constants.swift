import Foundation
import SwiftUI

// MARK: - Constants
/// Centralized design-token registry for the entire DataLens application.
/// All magic numbers, strings, and config values live here.
struct Constants {

    // MARK: - App Meta

    struct App {
        static let name        = "DataLens"
        static let version     = "1.0.0"
        static let buildNumber = "1"
        static let tagline     = "Your Native Mac Analytics Tool"
        static let getStartedButton = "Get Started"
        static let bundleID    = "com.datalens.app"
        static let githubURL   = "https://github.com/datalens-app/datalens"
    }

    // MARK: - Animation Timings

    struct Animation {
        /// 0.15s – micro interactions, hover, button press
        static let instant:  Double = 0.15
        /// 0.25s – panel open/close, tab switch
        static let standard: Double = 0.25
        /// 0.35s – page transitions, sheet presentation
        static let slow:     Double = 0.35
        /// 0.5s  – chart enter, complex transitions
        static let deliberate: Double = 0.50
    }

    // MARK: - Typography Scale

    /// All text sizes used throughout DataLens. Use these — never hardcode font sizes.
    struct Typography {
        /// 28pt Heavy — screen hero titles
        static let largeTitle  = Font.system(size: 28, weight: .heavy)
        /// 22pt Semibold — section titles
        static let title       = Font.system(size: 22, weight: .semibold)
        /// 17pt Semibold — card headers, subsection labels
        static let headline    = Font.system(size: 17, weight: .semibold)
        /// 14pt Regular — body text, descriptions
        static let body        = Font.system(size: 14, weight: .regular)
        /// 13pt Semibold — button labels, column headers
        static let label       = Font.system(size: 13, weight: .semibold)
        /// 12pt Regular — captions, secondary info
        static let caption     = Font.system(size: 12, weight: .regular)
        /// 11pt Regular — tiny labels, timestamps, hints
        static let small       = Font.system(size: 11, weight: .regular)
        /// 9pt Bold Monospaced — section eyebrow labels
        static let eyebrow     = Font.system(size: 9, weight: .bold, design: .monospaced)
    }

    // MARK: - Spacing Scale

    /// Spacing tokens. Use these for all padding/spacing — never hardcode pt values.
    struct Spacing {
        /// 4pt
        static let xs:  CGFloat = 4
        /// 8pt
        static let sm:  CGFloat = 8
        /// 16pt
        static let md:  CGFloat = 16
        /// 24pt
        static let lg:  CGFloat = 24
        /// 32pt
        static let xl:  CGFloat = 32
        /// 48pt
        static let xxl: CGFloat = 48
    }

    // MARK: - Border Radius Scale

    struct Radius {
        /// 6pt – small chips, tags, toggles
        static let small:      CGFloat = 6
        /// 10pt – standard card radius
        static let medium:     CGFloat = 10
        /// 14pt – modals, panels
        static let large:      CGFloat = 14
        /// 20pt – sheet corners, hero cards
        static let extraLarge: CGFloat = 20
        /// 9999pt – pill shapes
        static let full:       CGFloat = 9999
    }

    // MARK: - Shadow Definitions

    struct Shadow {
        struct Definition {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        /// Barely visible lift — used on flat cards
        static let subtle  = Definition(color: Color.black.opacity(0.10), radius:  3, x: 0, y: 1)
        /// Standard card elevation
        static let medium  = Definition(color: Color.black.opacity(0.20), radius: 12, x: 0, y: 4)
        /// Deep shadow for modals and overlays
        static let strong  = Definition(color: Color.black.opacity(0.30), radius: 24, x: 0, y: 8)
        /// Accent glow — used for highlighted/selected elements
        static let glow    = Definition(color: Color(hex: "#533483").opacity(0.40), radius: 16, x: 0, y: 0)
    }

    // MARK: - Legacy Layout (kept for backwards compat, prefer Spacing/Radius above)

    struct Layout {
        static let cornerRadius:  CGFloat = 12.0
        static let padding:       CGFloat = 16.0
        static let outerPadding:  CGFloat = 24.0
    }

    // MARK: - History

    struct History {
        static let maxSnapshots: Int = 10
    }

    // MARK: - Performance Thresholds

    struct Performance {
        /// Operations slower than this (ms) are logged as warnings
        static let slowOperationThreshold: Double = 100
        /// Maximum chart render cache entries before eviction
        static let chartCacheLimit: Int = 20
        /// Throttle rapid filter changes by this amount (ms)
        static let filterThrottleMs: Int = 100
        /// Max recent-export history items to remember
        static let maxRecentExports: Int = 5
        /// Clear cached exports older than this many days
        static let exportCacheAgeDays: Int = 30
    }

    // MARK: - UserDefaults / AppStorage Keys

    struct AppStorageKeys {
        // General
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appTheme               = "appTheme"
        static let appLanguage            = "appLanguage"

        // Data
        static let defaultDelimiter       = "defaultDelimiter"
        static let defaultEncoding        = "defaultEncoding"

        // Charts
        static let defaultColorTheme      = "defaultColorTheme"
        static let chartAnimationSpeed    = "chartAnimationSpeed"
        static let showGridLines          = "showGridLines"
        static let showTooltips           = "showTooltips"
        static let showLegend             = "showLegend"

        // AI
        static let groqAPIKey             = "groq_api_key"
        static let groqModel              = "groqModel"

        // Export
        static let defaultExportFormat    = "defaultExportFormat"
        static let defaultExportQuality   = "defaultExportQuality"
        static let exportWatermark        = "exportWatermark"

        // Advanced
        static let enableDebugMode        = "enableDebugMode"
        static let enablePerformanceHUD   = "enablePerformanceHUD"
        static let enableReduceMotion     = "enableReduceMotion"
    }

    // MARK: - Sidebar Labels

    struct Sidebar {
        static let home       = "Home"
        static let importData = "Import Data"
        static let dashboard  = "Dashboard"
        static let charts     = "Charts"
        static let aiInsights = "AI Insights"
        static let export     = "Export"
        static let settings   = "Settings"
        static let help       = "Help"
    }

    // MARK: - Keyboard Shortcut Descriptions
    // (Used in ShortcutsOverlayView — key names shown as badges)

    struct Shortcuts {
        struct Global {
            static let all: [(String, String)] = [
                ("New Dashboard",        "⌘N"),
                ("Open Dashboard",       "⌘O"),
                ("Save Dashboard",       "⌘S"),
                ("Export Current View",  "⌘E"),
                ("Focus Search",         "⌘F"),
                ("Undo",                 "⌘Z"),
                ("Redo",                 "⌘⇧Z"),
                ("Settings",             "⌘,"),
                ("Close Tab",            "⌘W"),
                ("Go to Home",           "⌘1"),
                ("Go to Import Data",    "⌘2"),
                ("Go to Dashboard",      "⌘3"),
                ("Go to Charts",         "⌘4"),
                ("Go to AI Insights",    "⌘5"),
                ("Go to Export",         "⌘6"),
                ("Close Panel",          "⎋"),
                ("Show Shortcuts",       "?"),
            ]
        }
        struct Chart {
            static let all: [(String, String)] = [
                ("Copy as Image",        "⌘C"),
                ("Print Chart",          "⌘P"),
                ("Reset Zoom",           "R"),
                ("Zoom In",              "+"),
                ("Zoom Out",             "-"),
                ("Toggle Annotations",   "A"),
                ("Toggle Legend",        "L"),
                ("Toggle Grid Lines",    "G"),
                ("Toggle Tooltips",      "T"),
            ]
        }
        struct Dashboard {
            static let all: [(String, String)] = [
                ("Select All Cards",     "⌘A"),
                ("Duplicate Card",       "⌘D"),
                ("Delete Card",          "⌫"),
                ("Group Cards",          "⌘G"),
                ("Send to Back",         "⌘["),
                ("Bring to Front",       "⌘]"),
                ("Move Card 1pt",        "↑↓←→"),
                ("Move Card 10pt",       "⇧↑↓←→"),
                ("Toggle Preview Mode",  "Space"),
            ]
        }
    }

    // MARK: - Onboarding

    struct Onboarding {
        static let slide1Title    = "Welcome to DataLens"
        static let slide1Subtitle = "Your native Mac analytics tool"

        static let slide2Title    = "Import Your Data"
        static let slide2Subtitle = "Drag and drop CSV or Excel files to get started instantly"

        static let slide3Title    = "Visualise Everything"
        static let slide3Subtitle = "15 chart types, interactive dashboards, and AI powered insights"

        static let slide4Title    = "You're Ready!"
        static let slide4Subtitle = "Let's start analysing your data"

        static let skipButton = "Skip"
        static let doneButton = "Get Started"
    }

    // MARK: - Empty States

    struct EmptyStates {
        static let noDataTitle          = "No Data Imported Yet"
        static let noDataSubtitle       = "Import a CSV or Excel file to begin analyzing and building charts."

        static let noSearchTitle        = "No Results Found"
        static let noSearchSubtitle     = "Try adjusting your query or filters to find what you are looking for."

        static let noChartsTitle        = "No Charts Created"
        static let noChartsSubtitle     = "Create visual insights of your clean data in the Charts workspace."

        static let noDashboardsTitle    = "No Dashboards Yet"
        static let noDashboardsSubtitle = "Assemble interactive grids of charts and KPIs into responsive dashboards."

        static let noActivityTitle      = "No Recent Activity"
        static let noActivitySubtitle   = "Import a dataset or create a chart to see activity here."
    }
}
