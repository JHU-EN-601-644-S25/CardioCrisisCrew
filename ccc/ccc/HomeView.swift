import SwiftUI
import CoreBluetooth

struct HomeView: View {
    let user: ContentView.User
    let onSignOut: () async -> Void
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
                            
                            // Use the shared ECGDataView component
                            ECGDataView(
                                receivedData: connectionManager.receivedData,
                                isUploadingData: connectionManager.isUploadingData,
                                apiStatus: connectionManager.apiStatus
                            )
                            
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
                        }
                        .padding(.vertical)
                    } else {
                        Text("No ECG device connected")
                            .foregroundColor(.gray)
                            .padding()
                        
                        // Developer Mode Button
                        Button(action: {
                            if connectionManager.isDeveloperMode {
                                connectionManager.stopDeveloperMode()
                            } else {
                                connectionManager.startDeveloperMode()
                            }
                        }) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .padding(.trailing, 5)
                                Text(connectionManager.isDeveloperMode ? "Stop Developer Mode" : "Start Developer Mode")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(connectionManager.isDeveloperMode ? Color.orange : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.bottom)
                        
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
                // Store patient information in UserDefaults
                UserDefaults.standard.set(patientData.firstName, forKey: "patientFirstName")
                UserDefaults.standard.set(patientData.lastName, forKey: "patientLastName")
                UserDefaults.standard.set(patientData.sex, forKey: "patientSex")
                UserDefaults.standard.set(patientData.age, forKey: "patientAge")
                
                // Use the current ECG data from the connection manager
                let ecgData = connectionManager.currentECGData
                
                // Send the data to AWS
                connectionManager.sendDataToAWS(patientData: patientData, ecgData: ecgData, forceUpload: true)
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
                Task {
                    await onSignOut()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(user: ContentView.User(username: "admin", role: "ADMIN"), onSignOut: {})
    }
} 
