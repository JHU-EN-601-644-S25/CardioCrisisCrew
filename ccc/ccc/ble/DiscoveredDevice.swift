//
//  DiscoveredDevice.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//

import Foundation
import CoreBluetooth

struct DiscoveredDevice: Identifiable, Hashable {
    let id = UUID()
    let peripheral: CBPeripheral
    let name: String
    let address: String
    let rssi: Int
}
