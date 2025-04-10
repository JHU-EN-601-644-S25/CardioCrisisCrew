import SwiftUI

struct HomeView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToScan = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Cardio Crisis Crew")
                .font(.largeTitle)
                .bold()
                .padding(.top, 50)
            
            Spacer()
            
            Button(action: {
                navigateToScan = true
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Scan for Devices")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                // Go back to login screen
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
            
            NavigationLink(destination: BLEScanView(), isActive: $navigateToScan) {
                EmptyView()
            }
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
} 