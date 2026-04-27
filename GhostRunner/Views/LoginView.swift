// LoginView.swift
import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isLoggedIn = false  // ← NEW

    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Image(systemName: "figure.run.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)

                Text("GhostRunner")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: loginUser) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .disabled(isLoading)

                VStack(spacing: 15) {
                    Text("OR").font(.caption).foregroundColor(.gray)

                    Button(action: { /* Google logic later */ }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                    }

                    Button(action: { /* Apple logic later */ }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Continue with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    NavigationLink(destination: RegistrationView()) {
                        Text("Don't have an account? Sign Up")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding(.top)
                    }
                }
                .padding(.horizontal)
                .disabled(isLoading)

                Spacer()
            }
            .padding(.top, 50)
            // ↓ NEW — covers the whole screen, can't be dismissed by swipe
            .fullScreenCover(isPresented: $isLoggedIn) {
                MainTabView()
            }
        }
    }

    func loginUser() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }

        isLoading = true

        AuthManager.shared().login(withEmail: email, password: password) { success, error in
            DispatchQueue.main.async {  // ← always update UI on main thread
                isLoading = false
                if success {
                    isLoggedIn = true  // ← triggers the fullScreenCover
                } else {
                    errorMessage = error ?? "Login failed"
                }
            }
        }
    }
}
