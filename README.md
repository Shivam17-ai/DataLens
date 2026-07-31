# DataLens 📊
> Native macOS Analytics App

## Overview
DataLens is a high-performance, native macOS analytics application built with SwiftUI. It empowers users to import datasets, construct interactive visualization dashboards with cross-filtering, and generate instant data insights powered by local or Groq AI models—all with a premium, hardware-accelerated user experience.

## Screenshots
![DataLens Dashboard Mockup](C:/Users/spg20/.gemini/antigravity-ide/brain/ce8d7314-ab14-4541-9e62-fc149294c3bf/uploaded_media_1785163375297.img)

## Features

### 📥 Data Import
- CSV and Excel (.xlsx) file import
- Native drag-and-drop file support
- Automated column type detection and cleansing operations
- In-memory data profiling and statistical summaries

### 📊 15 Chart Types
- **Basic:** Bar, Horizontal Bar, Line, Area, Pie, Donut
- **Statistical:** Scatter Plot, Bubble, Histogram, Box Plot
- **Advanced:** Heatmap, Treemap, Waterfall, Funnel, Gauge

### 🎛️ Interactive Dashboard
- Drag-and-drop dashboard grid builder
- Interactive cross-filtering between different charts
- Date range and category filtering
- Multi-dashboard support with layouts persistence
- Export dashboards as multi-page reports

### 🤖 AI Insights (Groq)
- Ask natural language data queries about your records
- 8 pre-built analytical prompt suggestions
- Smart automated chart suggestions
- Live streaming AI response interface

### 📤 Export Options
- Executive PDF reports (single chart, dashboard layout, or complete report)
- PNG/JPG image export with watermarks
- Delimiter-customizable CSV/TSV export
- Direct copy chart image to clipboard

## Tech Stack
| Layer | Technology |
|---|---|
| Language | Swift 5.8+ |
| UI Framework | SwiftUI |
| Charts | Swift Charts / CoreGraphics |
| AI | Groq API (LLaMA 3 70B) |
| Storage | CoreData / JSON File Storage |
| PDF | PDFKit / CoreText |
| Minimum macOS | 13.0 |

## Project Structure
```
DataLens/
├── DataLens-Backend/
│   ├── Models/            # DashboardLayout, Dataset models
│   ├── Services/          # Exporters, AI (Groq), CoreData
│   └── ViewModels/        # Chart, Data, AI, Export ViewModels
└── DataLens-Frontend/
    ├── App/               # Entry points, navigation
    ├── Components/        # Reusable custom UI buttons and managers
    └── Views/             # Home, Import, Dashboard, Charts, AI, Export Views
```

## Getting Started

### Prerequisites
- Mac running macOS 13.0 or later
- Xcode 14.0 or later
- Free Groq API key (optional) from [console.groq.com](https://console.groq.com)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/Shivam17-ai/DataLens.git
   ```
2. Open the project in Xcode.
3. Add the CoreXLSX dependency:
   `File -> Add Packages...` and enter `https://github.com/CoreOffice/CoreXLSX`
4. Build and run (`Cmd+R`).
5. Optional: Input your Groq API key under Settings.

## Requirements
- macOS 13.0+
- Internet connection only required for AI insights capabilities

## Privacy
- All datasets remain 100% local on your Mac.
- No remote analytics, tracking scripts, or telemetry telemetry are collected.

## Contributing
Contributions are welcome! Please fork the repository, make changes in a feature branch, and open a Pull Request.

## License
MIT License. Feel free to copy, modify, and distribute.

## Acknowledgements
- Apple's Swift Charts framework
- CoreOffice team for CoreXLSX library
- Groq for providing high-throughput API endpoints
- Apple's SF Symbols library
