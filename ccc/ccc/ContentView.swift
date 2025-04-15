//
//  ContentView.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//

//
//  ContentView.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//

import SwiftUI
import AWSCognitoIdentityProvider
import AWSClientRuntime

struct ContentView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var showInvalidAlert = false
    @State private var navigateToHome = false
    @State private var currentUser: User?
    @State private var isLoading = false

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

                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Button("Login") {
                        Task {
                            isLoading = true
                            let success = await loginWithCognito(username: username, password: password)
                            isLoading = false
                            if success {
                                currentUser = User(username: username, role: "USER") // Customize role logic as needed
                                navigateToHome = true
                            } else {
                                showInvalidAlert = true
                            }
                        }
                    }
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                NavigationLink(
                    destination: HomeView(user: currentUser ?? User(username: "", role: "")),
                    isActive: $navigateToHome
                ) {
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

    // MARK: - Cognito Login Function

    func loginWithCognito(username: String, password: String) async -> Bool {
        let clientId = "7g0tcvh99nrkp5k0q790krqefr"  // Replace with your actual App Client ID
        let region = "us-east-2"               // e.g. "us-east-1"

        do {
            let config = try await CognitoIdentityProviderClient.CognitoIdentityProviderClientConfiguration(region: region)
            let client = CognitoIdentityProviderClient(config: config)

            let input = InitiateAuthInput(
                authFlow: .userPasswordAuth,
                authParameters: [
                    "USERNAME": username,
                    "PASSWORD": password
                ],
                clientId: clientId
            )

            let response = try await client.initiateAuth(input: input)
            

            if let token = response.authenticationResult?.accessToken {
                print("Login succeeded.")
                // Store token securely as needed
                return true
            } else {
                print("Login failed: no access token returned.")
                return false
            }
        } catch {
            print("Login error: \(error)")
            return false
        }
    }

    // MARK: - Local User Struct (used only to pass to HomeView)

    struct User: Identifiable {
        let id = UUID()
        let username: String
        let role: String
    }
}
