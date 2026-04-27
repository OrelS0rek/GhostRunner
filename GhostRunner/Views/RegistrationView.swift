//
//  RegistrationView.swift
//  GhostRunner
//
//  Created by Admin on 09/02/2026.
//

import SwiftUI
import FirebaseAuth


struct RegistrationView: View {
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss // This allows us to go back to login

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .bold()

            VStack(spacing: 15) {
                TextField("Full Name", text: $fullName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red).font(.caption)
            }

            Button(action: registerUser) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .disabled(isLoading)

            Spacer()
        }
        .padding(.top, 20)
    }

    func registerUser() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }

        isLoading = true
        AuthManager.shared().register(withEmail: email, password: password) { success, error in
            isLoading = false
            if success {
                // Save the user profile to Firestore
                if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                    UserManager.shared.createUserProfile(
                        uid: uid,
                        fullName: fullName,
                        email: email
                    )
                }
                dismiss()
            } else {
                errorMessage = error ?? "Registration failed"
            }
        }
    }
}
