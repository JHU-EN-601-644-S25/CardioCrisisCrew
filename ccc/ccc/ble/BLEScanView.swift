//
//  BLEScanView.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//
import SwiftUI

struct BLEScanView: View {
    @StateObject private var scanner = BLEScanner()
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedDevice: BLEDevice?
    @State private var showConnectionView = false
    
    init(selectedDevice: Binding<BLEDevice?> = .constant(nil)) {
        _selectedDevice = selectedDevice
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .padding()
                }
                
                Spacer()
                
                Text("Available Devices")
                    .font(.headline)
                
                Spacer()
                
                // Empty view for balance
                Image(systemName: "arrow.left")
                    .padding()
                    .opacity(0)
            }
            
            Text(scanner.status)
                .font(.subheadline)
                .padding(.top)
            
            if scanner.devices.isEmpty && scanner.scanning {
                Text("Searching for devices...")
                    .foregroundColor(.secondary)
                    .padding()
                
                ProgressView()
                    .padding()
            } else if scanner.devices.isEmpty {
                Text("No devices found")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
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
                    selectedDevice = device
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            Button(scanner.scanning ? "Stop Scan" : "Start Scan") {
                scanner.scanning ? scanner.stopScan() : scanner.startScan()
            }
            .padding()
            .frame(minWidth: 200)
            .background(scanner.scanning ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.bottom)
        }
        .navigationTitle("BLE Scan")
        .navigationBarHidden(true)
        .padding()
        .onAppear {
            // Auto-start scanning when view appears
            if !scanner.scanning {
                scanner.startScan()
            }
        }
        .onDisappear {
            // Stop scanning when view disappears
            if scanner.scanning {
                scanner.stopScan()
            }
        }
        .sheet(isPresented: $showConnectionView) {
            if let device = selectedDevice {
                BLEConnectionView(device: device)
            }
        }
    }
}
