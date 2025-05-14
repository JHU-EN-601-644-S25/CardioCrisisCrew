import SwiftUI
import CoreBluetooth

struct BLEConnectionView: View {
    let device: BLEDevice
    
    // Service and characteristic UUIDs for Raspberry Pi
    private let raspberryPiServiceUUID = "00000001-1E3C-FAD4-74E2-97A033F1BFAA"
    private let raspberryPiCharacteristicUUID = "00000002-1E3C-FAD4-74E2-97A033F1BFAA"
    
    @StateObject private var connectionManager: BLEConnectionManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showDisconnectAlert = false
    @State private var showPatientForm = false
    @State private var patientInfo = PatientFormData()
    
    init(device: BLEDevice) {
        self.device = device
        // Initialize the connection manager with the device's identifier
        _connectionManager = StateObject(wrappedValue: BLEConnectionManager(
            deviceIdentifier: device.identifier,
            serviceUUID: "00000001-1E3C-FAD4-74E2-97A033F1BFAA",
            characteristicUUID: "00000002-1E3C-FAD4-74E2-97A033F1BFAA"
        ))
    }
    
    var body: some View {
        VStack {
            // Header with device info
            VStack(alignment: .leading, spacing: 8) {
                Text(device.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(device.identifier.uuidString)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("RSSI: \(device.rssi)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let patientId = connectionManager.currentPatientId {
                    Text("Patient ID: \(patientId)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // Connection status
            HStack {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 12, height: 12)
                
                Text(connectionManager.connectionStatus)
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .padding(.vertical)
            
            // Data display
            if connectionManager.isConnected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Display received data if available
                        if !connectionManager.receivedData.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Received Data:")
                                    .font(.headline)
                                
                                Text(connectionManager.receivedData)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                // AWS API Integration buttons
                                HStack {
                                    Button(action: {
                                        showPatientForm = true
                                    }) {
                                        Label("Update Patient Info", systemImage: "person.crop.circle.badge.plus")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .disabled(connectionManager.isUploadingData)
                                }
                                .padding(.top, 8)
                                
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
                        }
                        
                        // Display characteristics if available
                        if !connectionManager.characteristics.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Characteristics:")
                                    .font(.headline)
                                
                                ForEach(connectionManager.characteristics, id: \.uuid) { characteristic in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(characteristic.uuid.uuidString)
                                                .font(.subheadline)
                                            
                                            // Show if this is the Raspberry Pi characteristic
                                            if characteristic.uuid.uuidString.uppercased() == raspberryPiCharacteristicUUID.uppercased() {
                                                Text("Raspberry Pi Data Characteristic")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Read button for readable characteristics
                                        if characteristic.properties.contains(.read) {
                                            Button("Read") {
                                                readCharacteristic(characteristic)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else if connectionManager.connectionTimedOut {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text("Connection timed out")
                        .font(.headline)
                    
                    Text("Please make sure the device is powered on and in range")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Button("Try Again") {
                        connectionManager.reconnect()
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                .padding()
            } else {
                // Loading indicator while connecting
                VStack {
                    ProgressView()
                        .padding()
                    
                    Text("Connecting to device...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
            
            Spacer()
            
            // Disconnect button
            if connectionManager.isConnected {
                Button(action: {
                    showDisconnectAlert = true
                }) {
                    Text("Disconnect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .alert(isPresented: $showDisconnectAlert) {
                    Alert(
                        title: Text("Disconnect from device?"),
                        message: Text("Are you sure you want to disconnect from \(device.name)?"),
                        primaryButton: .destructive(Text("Disconnect")) {
                            connectionManager.disconnect()
                            presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationTitle("Device Connection")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Start connection when view appears
            connectionManager.connect()
        }
        .onDisappear {
            // Clean up when view disappears
            connectionManager.disconnect()
        }
        .sheet(isPresented: $showPatientForm) {
            PatientFormView(patientInfo: $patientInfo, isPresented: $showPatientForm) { patientData in
                // Update the patient data with the existing patient ID
                if let existingPatientId = connectionManager.currentPatientId {
                    let updatedPatientData = PatientData(
                        patientId: existingPatientId, 
                        firstName: patientData.firstName,
                        lastName: patientData.lastName,
                        sex: patientData.sex,
                        age: Int(patientData.age) ?? 0
                    )
                    
                    // Send the patient data with current ECG data
                    if !connectionManager.currentECGData.isEmpty {
                        connectionManager.sendDataToAWS(patientData: updatedPatientData, ecgData: connectionManager.currentECGData)
                    } else {
                        // If no ECG data is available, show an alert
                        connectionManager.apiStatus = "No ECG data available to upload with patient information"
                    }
                }
            }
        }
    }
    
    // Helper function to read a characteristic
    private func readCharacteristic(_ characteristic: CBCharacteristic) {
        connectionManager.readCharacteristic(characteristic)
    }
    
    // Color indicator for connection status
    private var connectionStatusColor: Color {
        if connectionManager.isConnected {
            return .green
        } else if connectionManager.connectionTimedOut {
            return .orange
        } else {
            return .yellow
        }
    }
}

// Form data structure
struct PatientFormData {
    var firstName: String = ""
    var lastName: String = ""
    var sex: String = "male"
    var age: String = ""
}

// Patient form view
struct PatientFormView: View {
    @Binding var patientInfo: PatientFormData
    @Binding var isPresented: Bool
    var onSubmit: (PatientData) -> Void
    
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Information")) {
                    TextField("First Name", text: $patientInfo.firstName)
                        .autocapitalization(.words)
                    
                    TextField("Last Name", text: $patientInfo.lastName)
                        .autocapitalization(.words)
                    
                    Picker("Sex", selection: $patientInfo.sex) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                    
                    TextField("Age", text: $patientInfo.age)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button("Submit") {
                        if validateForm() {
                            let age = Int(patientInfo.age) ?? 0
                            
                            let patientData = PatientData(
                                patientId: "",  // This will be set by the parent view
                                firstName: patientInfo.firstName,
                                lastName: patientInfo.lastName,
                                sex: patientInfo.sex,
                                age: age
                            )
                            
                            onSubmit(patientData)
                            isPresented = false
                        } else {
                            showValidationAlert = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Patient Information")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
            )
            .alert(isPresented: $showValidationAlert) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(validationMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func validateForm() -> Bool {
        if patientInfo.firstName.isEmpty {
            validationMessage = "First name is required"
            return false
        }
        
        if patientInfo.lastName.isEmpty {
            validationMessage = "Last name is required"
            return false
        }
        
        if patientInfo.age.isEmpty {
            validationMessage = "Age is required"
            return false
        }
        
        if Int(patientInfo.age) == nil {
            validationMessage = "Age must be a number"
            return false
        }
        
        return true
    }
}
