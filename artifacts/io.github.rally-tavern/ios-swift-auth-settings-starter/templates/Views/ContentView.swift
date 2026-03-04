import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(authManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
