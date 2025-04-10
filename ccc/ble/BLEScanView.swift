//
//  BLEScanView.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//
import SwiftUI

struct BLEScanView: View {
    @StateObject private var scanner = BLEScanner()

    var body: some View {
        VStack {
            Text(scanner.status)
                .font(.subheadline)
                .padding(.top)

            List(scanner.devices) { device in
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.identifier.uuidString)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("RSSI: \(device.rssi)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .onTapGesture {
                    // TODO: Handle connection
                    scanner.status = "Tapped \(device.name)"
                }
            }

            Button(scanner.scanning ? "Stop Scan" : "Start Scan") {
                scanner.scanning ? scanner.stopScan() : scanner.startScan()
            }
            .padding()
            .background(scanner.scanning ? Color.red : Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .navigationTitle("BLE Scan")
        .padding()
    }
}
