import Foundation

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
}

@MainActor
class SettingsManager: ObservableObject {
    @Published var pushNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(pushNotificationsEnabled, forKey: Keys.pushNotifications) }
    }

    @Published var emailNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(emailNotificationsEnabled, forKey: Keys.emailNotifications) }
    }

    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    private enum Keys {
        static let pushNotifications = "settings_push_notifications"
        static let emailNotifications = "settings_email_notifications"
        static let theme = "settings_theme"
    }

    init() {
        self.pushNotificationsEnabled = UserDefaults.standard.bool(forKey: Keys.pushNotifications)
        self.emailNotificationsEnabled = UserDefaults.standard.bool(forKey: Keys.emailNotifications)

        let themeRaw = UserDefaults.standard.string(forKey: Keys.theme) ?? AppTheme.system.rawValue
        self.theme = AppTheme(rawValue: themeRaw) ?? .system
    }
}
