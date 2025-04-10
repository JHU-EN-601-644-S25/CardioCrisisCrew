//
//  BLEDevice.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//


import SwiftUI
import CoreBluetooth

struct BLEDevice: Identifiable {
    let id = UUID()
    let name: String
    let identifier: UUID
    let rssi: Int
}

class BLEScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [BLEDevice] = []
    @Published var status: String = "Ready to scan"
    @Published var scanning = false

    private var manager: CBCentralManager!
    private var scanTimeout: DispatchWorkItem?

    override init() {
        super.init()
        self.manager = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            status = "Bluetooth is ON"
        case .poweredOff:
            status = "Bluetooth is OFF"
        case .unauthorized:
            status = "Bluetooth unauthorized"
        case .unsupported:
            status = "Bluetooth unsupported"
        default:
            status = "Bluetooth state: \(central.state.rawValue)"
        }
    }

    func startScan() {
        guard manager.state == .poweredOn else {
            status = "Bluetooth not ready"
            return
        }

        status = "Scanning..."
        scanning = true
        devices.removeAll()

        manager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        // Auto-stop after 10 seconds
        scanTimeout = DispatchWorkItem {
            self.stopScan()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: scanTimeout!)
    }

    func stopScan() {
        manager.stopScan()
        scanning = false
        status = "Scan stopped"
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            let device = BLEDevice(name: name, identifier: peripheral.identifier, rssi: RSSI.intValue)
            devices.append(device)
        }
    }
}
