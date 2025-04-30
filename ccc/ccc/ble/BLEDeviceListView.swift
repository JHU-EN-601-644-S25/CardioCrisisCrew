//
//  BLEDeviceListView.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//

import SwiftUI
import CoreBluetooth

struct BLEDeviceListView: View {
    var devices: [DiscoveredDevice]
    var onSelect: (DiscoveredDevice) -> Void

    var body: some View {
        List(devices) { device in
            Button(action: {
                onSelect(device)
            }) {
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
