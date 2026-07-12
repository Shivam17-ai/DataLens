import SwiftUI
import Combine

/// DataViewModel controls data import states and holds the actively parsed dataset
class DataViewModel: ObservableObject {
    @Published var currentDataSet: DataSet? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isImportSuccess: Bool = false
    
    /// Imports a CSV file at the given URL asynchronously on a background thread
    func importCSV(url: URL) {
        // Enforce CSV extension
        guard url.pathExtension.lowercased() == "csv" else {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.errorMessage = "Only comma-separated values (.csv) files are supported."
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        isImportSuccess = false
        
        Task {
            do {
                let dataSet = try await CSVParser.parse(url: url)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isLoading = false
                        self.isImportSuccess = true
                    }
                    
                    // Delay actual dataset assignment by 1 second to show checkmark transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.currentDataSet = dataSet
                            self.isImportSuccess = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    /// Retrieves all cell values for a specified column name
    func getColumnValues(columnName: String) -> [Any] {
        guard let dataset = currentDataSet else { return [] }
        return dataset.rows.compactMap { $0.values[columnName] }
    }
    
    /// Filters columns to only return numeric columns
    func getNumericColumns() -> [Column] {
        guard let dataset = currentDataSet else { return [] }
        return dataset.columns.filter { $0.type == .number }
    }
    
    /// Filters columns to only return text columns
    func getTextColumns() -> [Column] {
        guard let dataset = currentDataSet else { return [] }
        return dataset.columns.filter { $0.type == .text }
    }
    
    /// Resets the current state to allow importing a new file
    func reset() {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentDataSet = nil
            self.errorMessage = nil
            self.isLoading = false
        }
    }
}
