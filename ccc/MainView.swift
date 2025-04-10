import SwiftUI
import CoreBluetooth

struct MainView: View {
    @State private var isSignedIn = false
    @State private var ekgData: EkgData? = nil
    @State private var showExportSheet = false
    @State private var selectedHospitalIndex = 0
    @StateObject private var scanner = BLEScanner()

    private let hospitals = ["General Hospital", "Baltimore City Medical Center", "Johns Hopkins Hospital"]

    var timestampText: String {
        if let ts = ekgData?.timestamp {
            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            if let date = parser.date(from: ts) {
                return "Last Updated: \(formatter.string(from: date))"
            }
        }
        return "No timestamp"
    }

    var body: some View {
        NavigationView {
            VStack {
                // Top bar: user and export
                HStack {
                    Menu {
                        Button(action: {
                            isSignedIn.toggle()
                        }) {
                            Text(isSignedIn ? "Sign Out" : "Sign In")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 40, height: 40)
                    }

                    Spacer()

                    Button("Export") {
                        showExportSheet = true
                    }
                }
                .padding()

                // EKG Graph
                if let readings = ekgData?.readings {
                    EkgGraphView(readings: readings)
                        .frame(height: 200)
                        .padding()
                } else {
                    Text("Loading EKG data...")
                        .padding()
                }

                // Timestamp
                Text(timestampText)
                    .padding(.bottom)

                // BLE Status
                Text(scanner.status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Device list
                List(scanner.devices) { device in
                    DeviceRowView(device: device)
                        .onTapGesture {
                            scanner.status = "Tapped \(device.name)"
                            // Extend: Navigate to DeviceConnectionView(device)
                        }
                }

                // Scan button
                Button(scanner.scanning ? "Stop Scan" : "Start Scan") {
                    scanner.scanning ? scanner.stopScan() : scanner.startScan()
                }
                .padding()
                .background(scanner.scanning ? Color.red : Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .padding(.bottom)
            }
            .navigationTitle("Cardio Crisis Crew")
            .onAppear {
                loadEkgData()
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheetView(hospitals: hospitals, selectedIndex: $selectedHospitalIndex)
            }
        }
    }

    func loadEkgData() {
        if let url = Bundle.main.url(forResource: "ekg_data", withExtension: "xml"),
           let data = try? Data(contentsOf: url) {
            let parser = EkgXmlParser()
            ekgData = parser.parse(data: data)
        } else {
            print("Failed to load ekg_data.xml")
            ekgData = EkgData(readings: [0.0, 0.0, 0.0], timestamp: "1970-01-01T00:00:00", heartRate: 0)
        }
    }
}
