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
    
    private var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var deviceIdentifier: UUID
    private var connectionTimer: Timer?
    private let connectionTimeout: TimeInterval = 10.0 // 10 seconds timeout
    
    // Add these properties for Raspberry Pi specific communication
    var targetServiceUUID: CBUUID
    var targetCharacteristicUUID: CBUUID
    private var targetCharacteristic: CBCharacteristic?
    
    // AWS API Service
    private let apiService = AWSAPIService()
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
    
    // MARK: - AWS API Integration
    
    func sendDataToAWS(patientData: PatientData? = nil, ecgData: [Int]? = nil) {
        // Use provided patient data or dummy data
        let patientInfo = patientData ?? AWSAPIService.dummyPatientData
        
        // Use provided ECG data or dummy data
        let ecgValues = ecgData ?? AWSAPIService.dummyECGData
        
        isUploadingData = true
        apiStatus = "Uploading data to AWS..."
        
        apiService.postECGData(patientData: patientInfo, ecgData: ecgValues)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isUploadingData = false
                    
                    switch completion {
                    case .finished:
                        self.apiStatus = "Data uploaded successfully"
                    case .failure(let error):
                        self.apiStatus = "Upload failed: \(error.localizedDescription)"
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    func fetchPatientData() {
        let patientData = AWSAPIService.dummyPatientData
        
        apiStatus = "Fetching patient data..."
        
        apiService.getPatientData(patientData: patientData)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        self.apiStatus = "Fetch failed: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] patientData in
                    guard let self = self else { return }
                    self.apiStatus = "Patient data retrieved: \(patientData.firstName) \(patientData.lastName)"
                }
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
        connectionStatus = "Connected, discovering services..."
        isConnecting = false
        isConnected = true
        stopConnectionTimer()
        
        // Discover the services we're interested in
        peripheral.discoverServices([targetServiceUUID])
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
    
    // MARK: - CBPeripheralDelegate
    
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
            print("Error reading characteristic value: \(error.localizedDescription)")
            return
        }
        
        // Check if this is our target characteristic
        if characteristic.uuid == targetCharacteristicUUID, let data = characteristic.value {
            // Try to convert the data to a string
            if let string = String(data: data, encoding: .utf8) {
                receivedData = string
                
                // After receiving data from Raspberry Pi, we could send it to AWS
                // For demonstration purposes, we'll add a button in the UI to trigger this
            } else {
                // If it's not a string, show the raw data as hex
                receivedData = data.map { String(format: "%02X", $0) }.joined(separator: " ")
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