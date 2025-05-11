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
    @State private var failedAttempts = 0
    @State private var isLockedOut = false
    @State private var lockoutEndTime: Date?
    @State private var remainingLockoutTime = 0
    
    // Timer for lockout countdown
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
                    .disabled(isLockedOut)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .disabled(isLockedOut)

                if isLoading {
                    ProgressView()
                        .padding()
                } else if isLockedOut {
                    VStack {
                        Text("Account locked")
                            .foregroundColor(.red)
                            .font(.headline)
                        Text("Please try again in \(remainingLockoutTime) seconds")
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    Button("Login") {
                        Task {
                            isLoading = true
                            let success = await loginWithCognito(username: username, password: password)
                            isLoading = false
                            if success {
                                failedAttempts = 0
                                currentUser = User(username: username, role: "USER")
                                navigateToHome = true
                            } else {
                                failedAttempts += 1
                                if failedAttempts >= 5 {
                                    isLockedOut = true
                                    lockoutEndTime = Date().addingTimeInterval(60) // 1 minute lockout
                                    remainingLockoutTime = 60
                                }
                                showInvalidAlert = true
                            }
                        }
                    }
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLockedOut)
                }

                NavigationLink(
                    destination: HomeView(user: currentUser ?? User(username: "", role: ""), onSignOut: signOut),
                    isActive: $navigateToHome
                ) {
                    EmptyView()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .alert("Invalid credentials", isPresented: $showInvalidAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invalid username or password. \(5 - failedAttempts) attempts remaining.")
            }
            .onReceive(timer) { _ in
                if let endTime = lockoutEndTime {
                    let remaining = Int(endTime.timeIntervalSince(Date()))
                    if remaining <= 0 {
                        isLockedOut = false
                        lockoutEndTime = nil
                        failedAttempts = 0
                        remainingLockoutTime = 0
                    } else {
                        remainingLockoutTime = remaining
                    }
                }
            }
        }
    }

    // MARK: - Cognito Login Function

    func loginWithCognito(username: String, password: String) async -> Bool {
        let clientId = "7g0tcvh99nrkp5k0q790krqefr" 
        let region = "us-east-2"              

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
            

            if let idToken = response.authenticationResult?.idToken {
                print("Login succeeded, got ID token.")
                UserDefaults.standard.set(idToken, forKey: "cognitoIdToken")
                print("Saved ID token to UserDefaults")
                return true
            } else {
                print("Login failed: no ID token returned.")
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
        
        func signOut() {
            // Clear any stored tokens or credentials
            UserDefaults.standard.removeObject(forKey: "cognitoAccessToken")
            UserDefaults.standard.removeObject(forKey: "cognitoRefreshToken")
            UserDefaults.standard.removeObject(forKey: "cognitoIdToken")
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: - Cognito Sign Out Function
    func signOut() async {
        let clientId = "7g0tcvh99nrkp5k0q790krqefr"
        let region = "us-east-2"
        
        do {
            let config = try await CognitoIdentityProviderClient.CognitoIdentityProviderClientConfiguration(region: region)
            let client = CognitoIdentityProviderClient(config: config)
            
            // Clear local credentials
            currentUser?.signOut()
            currentUser = nil
            username = ""
            password = ""
            
            // Revoke tokens if available
            if let refreshToken = UserDefaults.standard.string(forKey: "cognitoRefreshToken") {
                let input = RevokeTokenInput(
                    clientId: clientId,
                    token: refreshToken
                )
                _ = try await client.revokeToken(input: input)
            }
        } catch {
            print("Sign out error: \(error)")
        }
    }
}
