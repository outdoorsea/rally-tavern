import Foundation

enum AuthError: Error {
    case invalidCredentials
    case networkError
}

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserEmail: String?

    private let tokenKey = "auth_token"

    init() {
        // Restore session from persisted token
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            isAuthenticated = true
            currentUserEmail = UserDefaults.standard.string(forKey: "user_email")
        }
    }

    /// Authenticate with email and password.
    ///
    /// Replace this stub with your real auth backend (REST API, Firebase, etc.).
    func authenticate(email: String, password: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // Stub validation — accept any non-empty credentials
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }

        // In production: call your auth API, receive a JWT/session token
        let token = "stub-token-\(UUID().uuidString)"

        // Persist session
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(email, forKey: "user_email")

        isAuthenticated = true
        currentUserEmail = email
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: "user_email")
        isAuthenticated = false
        currentUserEmail = nil
    }
}
