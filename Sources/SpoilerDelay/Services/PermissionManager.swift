import AppKit
import Contacts
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class PermissionManager {
    private let messageSource: MessageSource

    init(messageSource: MessageSource) {
        self.messageSource = messageSource
    }

    func currentState() async -> PermissionState {
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        return PermissionState(
            notificationsAuthorized: notificationSettings.authorizationStatus == .authorized,
            fullDiskAccess: await messageSource.canReadDatabase,
            contactsAuthorized: CNContactStore.authorizationStatus(for: .contacts) == .authorized,
            launchAtLogin: SMAppService.mainApp.status == .enabled,
            nativeMessagesDisabled: UserDefaults.standard.bool(forKey: "nativeMessagesDisabled")
        )
    }

    func requestContacts() async {
        _ = try? await CNContactStore().requestAccess(for: .contacts)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            openLoginItemsSettings()
        }
    }

    func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    func openNotificationSettings() {
        open("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    func openLoginItemsSettings() {
        open("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    }

    private func open(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}
