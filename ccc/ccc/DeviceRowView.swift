import SwiftUI

struct DeviceRowView: View {
    let device: BLEDevice

    var body: some View {
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
    }
}
