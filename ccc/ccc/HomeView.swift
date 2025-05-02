import SwiftUI
import CoreBluetooth

struct HomeView: View {
    let user: ContentView.User
    @State private var showBLEScanView = false
    @State private var showPatientInfo = false
    @State private var showSignOutAlert = false
    
    // For navigation control
    @Environment(\.presentationMode) var presentationMode
    
    // BLE connection state
    @State private var connectedDevice: BLEDevice?
    @StateObject private var connectionManager = BLEConnectionManager(deviceIdentifier: UUID())
    
    // Patient form data
    @State private var patientInfo = PatientFormData()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status card
                VStack(spacing: 15) {
                    HStack {
                        Text("ECG Status")
                            .font(.title2)
                            .bold()
                        Spacer()
                        Circle()
                            .fill(connectionManager.isConnected ? Color.green : Color.red)
                            .frame(width: 15, height: 15)
                        Text(connectionManager.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(connectionManager.isConnected ? .green : .red)
                    }
                    
                    Divider()
                    
                    if connectionManager.isConnected {
                        // Device information section
                        VStack(alignment: .leading, spacing: 8) {
                            if let device = connectedDevice {
                                Text("Connected to: \(device.name)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                
                                Text("Device ID: \(device.identifier.uuidString.prefix(8))...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Display characteristics if available
                            if !connectionManager.characteristics.isEmpty {
                                Text("Available Characteristics:")
                                    .font(.subheadline)
                                    .padding(.top, 8)
                                
                                ForEach(connectionManager.characteristics, id: \.uuid) { characteristic in
                                    if characteristic.uuid == connectionManager.targetCharacteristicUUID {
                                        Text("✓ Target ECG Characteristic")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            if !connectionManager.receivedData.isEmpty {
                                Text("Latest Data:")
                                    .font(.subheadline)
                                    .padding(.top, 4)
                                
                                Text(connectionManager.receivedData)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            // API Status
                            if !connectionManager.apiStatus.isEmpty {
                                Text(connectionManager.apiStatus)
                                    .font(.caption)
                                    .foregroundColor(connectionManager.apiStatus.contains("failed") ? .red : .blue)
                                    .padding(.top, 4)
                            }
                            
                            if connectionManager.isUploadingData {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                    Text("Processing...")
                                        .font(.caption)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical)
                        
                        // Display raw data visualization instead of fake BPM and wave
                        if !connectionManager.receivedData.isEmpty {
                            VStack(alignment: .leading) {
                                Text("ECG Data Visualization")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                // If the data can be parsed as numbers, show a visualization
                                if let dataPoints = parseDataFromReceivedData() {
                                    ECGVisualizationView(data: .constant(dataPoints))
                                        .frame(height: 100)
                                        .padding(.horizontal)
                                } else {
                                    Text("Data format not suitable for visualization")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        // Patient Information button
                        Button(action: {
                            showPatientInfo = true
                        }) {
                            HStack {
                                Image(systemName: "person.text.rectangle")
                                Text("Patient Information")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(connectionManager.isUploadingData)
                        
                        // Add disconnect button
                        Button(action: {
                            connectionManager.disconnect()
                            connectedDevice = nil
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .padding(.trailing, 5)
                                Text("Disconnect Device")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        Text("No ECG device connected")
                            .foregroundColor(.gray)
                            .padding()
                        
                        Button(action: {
                            showBLEScanView = true
                        }) {
                            HStack {
                                Image(systemName: "heart.circle")
                                    .padding(.trailing, 5)
                                Text("Scan for ECG Device")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Cardio Crisis ECG")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: 
            Button(action: {
                showSignOutAlert = true
            }) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
            }
        )
        .sheet(isPresented: $showPatientInfo) {
            PatientFormView(patientInfo: $patientInfo, isPresented: $showPatientInfo) { patientData in
                // Parse ECG data from receivedData
                let ecgData = parseECGDataForUpload()
                
                // Send the data to AWS
                connectionManager.sendDataToAWS(patientData: patientData, ecgData: ecgData)
            }
        }
        .sheet(isPresented: $showBLEScanView, onDismiss: {
            // This will be called when BLEScanView is dismissed
            if let device = connectedDevice {
                // Update the connection manager with the selected device
                connectionManager.deviceIdentifier = device.identifier
                connectionManager.reconnect()
            }
        }) {
            BLEScanView(selectedDevice: $connectedDevice)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // Helper function to parse data from received data string
    private func parseDataFromReceivedData() -> [Double]? {
        let receivedData = connectionManager.receivedData
        
        // Try to parse as comma-separated values
        let components = receivedData.components(separatedBy: CharacterSet(charactersIn: ", \n"))
        let validComponents = components.compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        // If we have valid numeric data, return it
        if !validComponents.isEmpty {
            return validComponents
        }
        
        // If we can't parse as numbers, try to interpret as hex data
        if receivedData.contains(" ") {
            // Might be hex data like "FF 00 A3 ..."
            let hexComponents = receivedData.components(separatedBy: " ")
            let values = hexComponents.compactMap { component -> Double? in
                guard let value = UInt8(component, radix: 16) else { return nil }
                return Double(value) / 255.0 * 2.0 - 1.0 // Scale to range -1.0 to 1.0
            }
            
            if !values.isEmpty {
                return values
            }
        }
        
        // If all else fails, return a simple sine wave as fallback
        return nil
    }
    
    // Helper function to parse ECG data for upload to AWS
    private func parseECGDataForUpload() -> [Double] {
        let receivedData = connectionManager.receivedData
        print("Parsing data for upload: \(receivedData)")
        
        // First try to parse as voltage values (e.g., "0.066V 2.265 V")
        let components = receivedData.components(separatedBy: CharacterSet(charactersIn: ", \n"))
        let validComponents = components.compactMap { component -> Double? in
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove 'V' suffix
            let voltageString = trimmed.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces)
            if let voltage = Double(voltageString) {
                return voltage
            }
            return nil
        }
        
        if !validComponents.isEmpty {
            print("Successfully parsed voltage values: \(validComponents)")
            return validComponents
        }
        
        // If that fails, try to parse as regular numbers
        let numberComponents = components.compactMap { component -> Double? in
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Double(trimmed) {
                return value
            }
            return nil
        }
        
        if !numberComponents.isEmpty {
            print("Successfully parsed numeric values: \(numberComponents)")
            return numberComponents
        }
        
        // If that fails, try to parse as hex values
        if receivedData.contains(" ") {
            let hexComponents = receivedData.components(separatedBy: " ")
            let values = hexComponents.compactMap { component -> Double? in
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = UInt8(trimmed, radix: 16) {
                    return Double(value)
                }
                return nil
            }
            
            if !values.isEmpty {
                print("Successfully parsed hex values: \(values)")
                return values
            }
        }
        
        // If all parsing attempts fail, log the error and return empty array
        print("Failed to parse ECG data. Raw data: \(receivedData)")
        return []
    }
}

struct ECGVisualizationView: View {
    @Binding var data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let step = width / CGFloat(data.count - 1)
                
                for i in data.indices {
                    let x = step * CGFloat(i)
                    let y = height / 2 - CGFloat(data[i]) * height
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.red, lineWidth: 2)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HealthTipView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.red)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(user: ContentView.User(username: "admin", role: "ADMIN"))
    }
} 
