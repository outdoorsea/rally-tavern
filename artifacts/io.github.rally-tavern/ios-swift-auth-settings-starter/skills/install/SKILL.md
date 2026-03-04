# Install: ios-swift-auth-settings-starter

## Steps

1. Copy all files from `templates/` into your Xcode project directory
2. Replace all `{{project_name}}` placeholders with your actual project name
3. Open the `.xcodeproj` in Xcode (or create a new SwiftUI project and add the source files)
4. Ensure deployment target is iOS 17.0+
5. Build and run on a simulator: Cmd+R
6. Verify: Login screen should appear with email and password fields

## Post-Install

- Replace the stub `AuthManager.authenticate()` with your real auth backend (REST API, Firebase Auth, etc.)
- Add Keychain storage for tokens instead of UserDefaults (for production use)
- Customize the settings options in `SettingsManager` for your app's needs
- Add proper input validation to the login form
- Run `Cmd+U` in Xcode to verify all tests pass
