import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("You're signed in!")
                    .font(.title2)

                if let email = authManager.currentUserEmail {
                    Text(email)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
}
