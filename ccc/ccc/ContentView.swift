//
//  ContentView.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//

import SwiftUI


struct ContentView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var showInvalidAlert = false
    @State private var navigateToHome = false
    
    // Keep the validUsers for now, but we'll implement a better auth system later
    let validUsers = [
        User(username: "admin", password: "admin123", role: "ADMIN"),
        User(username: "Admin", password: "admin123", role: "ADMIN"),
        User(username: "user", password: "user123", role: "USER")
    ]
    
    @State private var currentUser: User?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.red)
                    .padding(.bottom, 10)
                
                Text("Cardio Crisis Crew")
                    .font(.title)
                    .bold()
                
                Text("ECG Monitoring System")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)

                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("Login") {
                    if let user = validUsers.first(where: { $0.username == username && $0.password == password }) {
                        currentUser = user
                        navigateToHome = true
                    } else {
                        showInvalidAlert = true
                    }
                }
                .padding()
                .frame(width: 200)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                NavigationLink(destination: HomeView(user: currentUser ?? User(username: "", password: "", role: "")), isActive: $navigateToHome) {
                    EmptyView()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .alert("Invalid credentials", isPresented: $showInvalidAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    struct User: Identifiable {
        let id = UUID()
        let username: String
        let password: String
        let role: String
    }
}


