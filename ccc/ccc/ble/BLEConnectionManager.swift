import Foundation
import CoreBluetooth
import Combine

class BLEConnectionManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var connectionStatus = "Initializing..."
    @Published var isConnected = false
    @Published var isConnecting = true
    @Published var characteristics: [CBCharacteristic] = []
    @Published var receivedData: String = ""
    @Published var connectionTimedOut = false
    @Published var apiStatus: String = ""
    @Published var isUploadingData = false
    @Published var currentPatientId: String?
    @Published var currentECGData: [Double] = []
    @Published var isDeveloperMode = false
    
    // Developer mode properties
    private var developerModeTimer: Timer?
    private var developerModeDataCount = 0
    private let maxDeveloperModeDataPoints = 100 // Increased for better visualization
    
    private var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var deviceIdentifier: UUID
    private var connectionTimer: Timer?
    private let connectionTimeout: TimeInterval = 10.0 // 10 seconds timeout
    
    // Track if initial data was sent
    private var initialDataSent = false
    
    // Track last uploaded data to avoid duplicates
    private var lastUploadedData: String = ""
    private var lastUploadTime: Date?
    private let minimumUploadInterval: TimeInterval = 30.0 // Minimum time between uploads
    
    // Raspberry Pi specific communication
    var targetServiceUUID: CBUUID
    var targetCharacteristicUUID: CBUUID
    private var targetCharacteristic: CBCharacteristic?
    
    // AWS API Service using shared instance
    private let apiService = AWSAPIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(deviceIdentifier: UUID, serviceUUID: String? = nil, characteristicUUID: String? = nil) {
        self.deviceIdentifier = deviceIdentifier
        
        // Set target UUIDs if provided, otherwise use defaults
        if let serviceUUID = serviceUUID {
            self.targetServiceUUID = CBUUID(string: serviceUUID)
        } else {
            self.targetServiceUUID = CBUUID(string: "00000001-1E3C-FAD4-74E2-97A033F1BFAA")
        }
        
        if let characteristicUUID = characteristicUUID {
            self.targetCharacteristicUUID = CBUUID(string: characteristicUUID)
        } else {
            self.targetCharacteristicUUID = CBUUID(string: "00000002-1E3C-FAD4-74E2-97A033F1BFAA")
        }
        
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func connect() {
        guard centralManager.state == .poweredOn else {
            connectionStatus = "Bluetooth is not available"
            return
        }
        
        // Start connection timeout timer
        startConnectionTimer()
        
        // Look for peripherals with the specified UUID
        if let peripheral = centralManager.retrievePeripherals(withIdentifiers: [deviceIdentifier]).first {
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
            connectionStatus = "Connecting..."
        } else {
            // If the device isn't already known, scan for it
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            connectionStatus = "Scanning for device..."
        }
    }
    
    func disconnect() {
        stopConnectionTimer()
        
        if let peripheral = peripheral, centralManager.state == .poweredOn {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        isConnected = false
        isConnecting = false
        connectionStatus = "Disconnected"
    }
    
    private func startConnectionTimer() {
        stopConnectionTimer()
        connectionTimedOut = false
        
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if !self.isConnected {
                self.connectionTimedOut = true
                self.isConnecting = false
                self.connectionStatus = "Connection timed out"
                
                // Stop scanning if we were scanning
                if self.centralManager.isScanning {
                    self.centralManager.stopScan()
                }
                
                // Disconnect if we were in the process of connecting
                if let peripheral = self.peripheral {
                    self.centralManager.cancelPeripheralConnection(peripheral)
                }
            }
        }
    }
    
    private func stopConnectionTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    // AWS API Integration
    func sendDataToAWS(patientData: PatientData, ecgData: [Double]? = nil, forceUpload: Bool = false) {
        // Use provided ECG data or fall back to current ECG data
        let ecgValues = ecgData ?? currentECGData
        
        guard !ecgValues.isEmpty else {
            apiStatus = "No ECG data available to upload"
            return
        }
        
        // Check time interval only for automatic uploads and if it's not the first data
        if !forceUpload && !initialDataSent {
            let now = Date()
            if let lastUpload = self.lastUploadTime {
                let timeSinceLastUpload = now.timeIntervalSince(lastUpload)
                if timeSinceLastUpload < self.minimumUploadInterval {
                    return
                }
            }
            self.lastUploadTime = now
        }
        
        isUploadingData = true
        apiStatus = "Uploading data to AWS..."
        
        // Create a new patient data object with the current patient ID if available
        let finalPatientData: PatientData
        if let currentId = currentPatientId {
            finalPatientData = PatientData(
                patientId: currentId,
                firstName: patientData.firstName,
                lastName: patientData.lastName,
                sex: patientData.sex,
                age: patientData.age
            )
        } else {
            finalPatientData = patientData
        }
        
        apiService.postECGData(patientData: finalPatientData, ecgData: ecgValues)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isUploadingData = false
                    
                    switch completion {
                    case .finished:
                        self.apiStatus = "Data uploaded successfully"
                        // Update last upload time and mark initial data as sent
                        self.lastUploadTime = Date()
                        self.lastUploadedData = ecgValues.description
                        self.initialDataSent = true
                    case .failure(let error):
                        self.apiStatus = "Upload failed: \(error.localizedDescription)"
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isConnecting {
                connect()
            }
        case .poweredOff:
            connectionStatus = "Bluetooth is turned off"
            isConnected = false
            isConnecting = false
        case .unauthorized:
            connectionStatus = "Bluetooth permission denied"
            isConnected = false
            isConnecting = false
        case .unsupported:
            connectionStatus = "Bluetooth not supported"
            isConnected = false
            isConnecting = false
        default:
            connectionStatus = "Bluetooth unavailable"
            isConnected = false
            isConnecting = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // If we find the device we're looking for, connect to it
        if peripheral.identifier == deviceIdentifier {
            centralManager.stopScan()
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
            connectionStatus = "Device found, connecting..."
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "unknown device")")
        self.peripheral = peripheral
        peripheral.delegate = self
        
        // Generate a new patient ID when connection is established
        currentPatientId = UUID().uuidString
        print("Generated new patient ID: \(currentPatientId ?? "none")")
        
        // Reset patient information in UserDefaults
        UserDefaults.standard.removeObject(forKey: "patientFirstName")
        UserDefaults.standard.removeObject(forKey: "patientLastName")
        UserDefaults.standard.removeObject(forKey: "patientSex")
        UserDefaults.standard.removeObject(forKey: "patientAge")
        
        // Reset upload tracking data
        lastUploadedData = ""
        lastUploadTime = nil
        
        // Reset initial data sent flag
        initialDataSent = false
        
        // Discover services
        peripheral.discoverServices([targetServiceUUID])
        
        isConnected = true
        isConnecting = false
        connectionStatus = "Connected"
        connectionTimer?.invalidate()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        isConnecting = false
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Disconnected"
        isConnected = false
        isConnecting = false
        
        // Clear characteristics when disconnected
        characteristics = []
        receivedData = ""
    }
    
    // CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            connectionStatus = "Service discovery failed: \(error.localizedDescription)"
            return
        }
        
        guard let services = peripheral.services else {
            connectionStatus = "No services found"
            return
        }
        
        connectionStatus = "Services discovered, finding characteristics..."
        
        // Look for our target service
        for service in services {
            if service.uuid == targetServiceUUID {
                // Found our service, now discover its characteristics
                peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            connectionStatus = "Characteristic discovery failed: \(error.localizedDescription)"
            return
        }
        
        guard let characteristics = service.characteristics else {
            connectionStatus = "No characteristics found"
            return
        }
        
        // Store all discovered characteristics
        self.characteristics = characteristics
        
        connectionStatus = "Ready"
        
        // Look for our target characteristic
        for characteristic in characteristics {
            if characteristic.uuid == targetCharacteristicUUID {
                targetCharacteristic = characteristic
                
                // If the characteristic is readable, read its value
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
                
                // If the characteristic supports notifications, subscribe to them
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        if let data = characteristic.value {
            if let string = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    // Append new data to existing received data
                    if !self.receivedData.isEmpty {
                        self.receivedData += ", "
                    }
                    self.receivedData += string
                    
                    // Parse ECG data - improved parsing logic
                    let components = string.components(separatedBy: CharacterSet(charactersIn: ", \n"))
                    let ecgData = components.compactMap { component -> Double? in
                        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                        // Skip empty components
                        guard !trimmed.isEmpty else { return nil }
                        let voltageString = trimmed.replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces)
                        if let value = Double(voltageString) {
                            // Round to 5 decimal places
                            return (value * 100000).rounded() / 100000
                        }
                        return nil
                    }
                    
                    // Append new ECG data to current data
                    if !ecgData.isEmpty {
                        self.currentECGData.append(contentsOf: ecgData)
                        
                        // If we have a patient ID, send the data to AWS
                        if let patientId = self.currentPatientId {
                            // Create a temporary patient data with just the ID for automatic uploads
                            let tempPatientData = PatientData(
                                patientId: patientId,
                                firstName: "TEMP",  // Temporary name for automatic uploads
                                lastName: "",
                                sex: "",
                                age: 0
                            )
                            
                            // Force upload on first data, then use normal interval
                            self.sendDataToAWS(patientData: tempPatientData, ecgData: ecgData, forceUpload: !self.initialDataSent)
                        }
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error.localizedDescription)")
        } else {
            print("Successfully wrote to characteristic")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
        } else {
            print("Notification state updated for characteristic")
        }
    }

    // Add after init method
    func startDeveloperMode() {
        isDeveloperMode = true
        isConnected = true
        isConnecting = false
        connectionStatus = "Developer Mode Active"
        
        // Generate a new patient ID
        currentPatientId = UUID().uuidString
        
        // Reset data
        currentECGData = []
        receivedData = "" // Reset received data
        developerModeDataCount = 0
        
        // Generate all data points immediately
        for _ in 0..<maxDeveloperModeDataPoints {
            generateDummyECGData()
        }
        
        // Update receivedData string with the generated data
        receivedData = currentECGData.map { String(format: "%.5fV", $0) }.joined(separator: ", ")
        
        // If we have a patient ID, send all the data to AWS at once
        if let patientId = currentPatientId {
            let tempPatientData = PatientData(
                patientId: patientId,
                firstName: "DEV_MODE",
                lastName: "",
                sex: "",
                age: 0
            )
            
            sendDataToAWS(patientData: tempPatientData, ecgData: currentECGData, forceUpload: true)
        }
    }
    
    func stopDeveloperMode() {
        isDeveloperMode = false
        isConnected = false
        connectionStatus = "Developer Mode Stopped"
        developerModeTimer?.invalidate()
        developerModeTimer = nil
        developerModeDataCount = 0
        currentECGData = []
    }
    
    private func generateDummyECGData() {
        guard isDeveloperMode, developerModeDataCount < maxDeveloperModeDataPoints else {
            return
        }
        
        // Generate a more realistic ECG-like pattern
        let time = Double(developerModeDataCount)
        var value: Double
        
        // Create a basic ECG-like pattern that will work well with the visualization
        if time.truncatingRemainder(dividingBy: 20) < 2 {
            // P wave - small positive deflection
            value = 0.1 + 0.05 * sin(time * 10)
        } else if time.truncatingRemainder(dividingBy: 20) < 4 {
            // QRS complex - sharp spike
            if time.truncatingRemainder(dividingBy: 20) < 3 {
                value = 0.8 // R wave peak
            } else {
                value = 0.2 // S wave
            }
        } else if time.truncatingRemainder(dividingBy: 20) < 6 {
            // T wave - rounded positive deflection
            value = 0.3 + 0.1 * sin(time * 5)
        } else {
            // Baseline - slight variation around 0.5
            value = 0.5 + Double.random(in: -0.05...0.05)
        }
        
        // Add some noise
        let noise = Double.random(in: -0.02...0.02)
        value += noise
        
        // Ensure value stays within 0-1V range
        value = max(0.0, min(1.0, value))
        
        // Add the value to current ECG data
        currentECGData.append(value)
        developerModeDataCount += 1
    }
}

// Extension for helper methods
extension BLEConnectionManager {
    func readCharacteristic(_ characteristic: CBCharacteristic) {
        guard let peripheral = peripheral, isConnected else { return }
        peripheral.readValue(for: characteristic)
    }
    
    func reconnect() {
        connectionTimedOut = false
        isConnecting = true
        connectionStatus = "Reconnecting..."
        connect()
    }
}
