//
//  ExportSheetView.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//


import SwiftUI

struct ExportSheetView: View {
    var hospitals: [String]
    @Binding var selectedIndex: Int
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Picker("Select Hospital", selection: $selectedIndex) {
                    ForEach(0..<hospitals.count, id: \.self) { index in
                        Text(hospitals[index])
                    }
                }
            }
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        print("Exporting to \(hospitals[selectedIndex])")
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
