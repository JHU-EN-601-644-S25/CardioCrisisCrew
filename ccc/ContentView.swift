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
    @State private var navigateToMain = false

    let validUsers = [
        User(username: "admin", password: "admin123", role: "ADMIN"),
        User(username: "Admin", password: "admin123", role: "ADMIN"),
        User(username: "user", password: "user123", role: "USER")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Cardio Crisis Crew")
                    .font(.title)
                    .bold()

                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Login") {
                    if validUsers.contains(where: { $0.username == username && $0.password == password }) {
                        navigateToMain = true
                    } else {
                        showInvalidAlert = true
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent)

                NavigationLink(destination: MainView(), isActive: $navigateToMain) {
                    EmptyView()
                }
            }
            .padding()
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


