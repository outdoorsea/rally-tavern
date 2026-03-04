import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Welcome")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                Spacer()
                Spacer()
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.authenticate(email: email, password: password)
            } catch AuthError.invalidCredentials {
                errorMessage = "Invalid email or password"
            } catch {
                errorMessage = "An error occurred. Please try again."
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
