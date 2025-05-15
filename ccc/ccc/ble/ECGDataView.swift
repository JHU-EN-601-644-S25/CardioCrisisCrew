import SwiftUI
import CoreBluetooth

struct ECGDataView: View {
    let receivedData: String
    let isUploadingData: Bool
    let apiStatus: String
    @State private var isDataExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !receivedData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Collapsible header for received data
                    Button(action: {
                        withAnimation {
                            isDataExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Received Data:")
                                .font(.headline)
                            Spacer()
                            Image(systemName: isDataExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if isDataExpanded {
                        ScrollView {
                            Text(formatECGData(receivedData))
                                .font(.system(.callout, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .transition(.opacity)
                    }
                    
                    // API Status
                    if !apiStatus.isEmpty {
                        Text(apiStatus)
                            .font(.caption)
                            .foregroundColor(apiStatus.contains("failed") ? .red : .blue)
                    }
                    
                    if isUploadingData {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 4)
                            Text("Processing...")
                                .font(.caption)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            
            // Display raw data visualization
            if !receivedData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ECG Data Visualization")
                        .font(.headline)
                    
                    // If the data can be parsed as numbers, show a visualization
                    if let dataPoints = parseDataFromReceivedData() {
                        ECGVisualizationView(data: .constant(dataPoints))
                            .frame(height: 200)
                            .padding(.horizontal)
                    } else {
                        Text("Data format not suitable for visualization")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // Helper function to parse data from received data string
    private func parseDataFromReceivedData() -> [Double]? {
        // Try to parse as comma-separated values
        let components = receivedData.components(separatedBy: CharacterSet(charactersIn: ", \n"))
        let validComponents = components.compactMap { component -> Double? in
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            // Remove V suffix and convert to Double
            let voltageString = trimmed.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces)
            return Double(voltageString)
        }
        
        // Take only the first 30 values for better visualization
        if !validComponents.isEmpty {
            return Array(validComponents.prefix(30))
        }
        
        return nil
    }
    
    // Helper function to format ECG data
    private func formatECGData(_ data: String) -> String {
        let components = data.components(separatedBy: CharacterSet(charactersIn: ", \n"))
        let formattedValues = components.compactMap { component -> String? in
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let voltageString = trimmed.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces)
            if let value = Double(voltageString) {
                // Round to 5 decimal places without capping the value
                let roundedValue = (value * 100000).rounded() / 100000
                return String(format: "%.5fV", roundedValue)
            }
            return nil
        }
        return formattedValues.joined(separator: ", ")
    }
} 