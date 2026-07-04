import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("hotKeyEnabled") private var hotKeyEnabled = true
    @AppStorage("hotKeyLetter") private var hotKeyLetter = "S"
    @AppStorage("hotKeyOption") private var hotKeyOption = true
    @AppStorage("hotKeyShift") private var hotKeyShift = true
    @AppStorage("hotKeyControl") private var hotKeyControl = false
    @AppStorage("hotKeyCommand") private var hotKeyCommand = false

    var body: some View {
        TabView {
            Form {
                Section("Permissions") {
                    SettingsStatusRow("Notifications", complete: model.permissions.notificationsAuthorized) {
                        model.requestNotifications()
                    }
                    SettingsStatusRow("Full Disk Access", complete: model.permissions.fullDiskAccess) {
                        model.permissionManager.openFullDiskAccessSettings()
                    }
                    SettingsStatusRow("Contacts", complete: model.permissions.contactsAuthorized, required: false) {
                        model.requestContacts()
                    }
                    Toggle("Native Messages notifications are disabled", isOn: Binding(
                        get: { model.permissions.nativeMessagesDisabled },
                        set: { value in model.setNativeMessagesDisabled(value) }
                    ))
                    Toggle("Launch at login", isOn: Binding(
                        get: { model.permissions.launchAtLogin },
                        set: { value in model.setLaunchAtLogin(value) }
                    ))
                }

                Section {
                    Button("Recheck permissions") { Task { await model.refreshPermissions() } }
                } footer: {
                    Text("Full Disk Access is required because Apple does not expose another app's notifications. Message bodies never leave this Mac.")
                }
            }
            .padding(18)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("Global shortcut") {
                    Toggle("Enable shortcut", isOn: $hotKeyEnabled)
                    HStack {
                        Toggle("⌥", isOn: $hotKeyOption).toggleStyle(.button)
                        Toggle("⇧", isOn: $hotKeyShift).toggleStyle(.button)
                        Toggle("⌃", isOn: $hotKeyControl).toggleStyle(.button)
                        Toggle("⌘", isOn: $hotKeyCommand).toggleStyle(.button)
                        Picker("Key", selection: $hotKeyLetter) {
                            ForEach(["S", "D", "P", "M"], id: \.self, content: Text.init)
                        }
                        .frame(width: 90)
                    }
                    .disabled(!hotKeyEnabled)
                }

                Section("Diagnostics") {
                    LabeledContent("Messages database", value: model.permissions.fullDiskAccess ? "Readable" : "Blocked")
                    LabeledContent("Notification bridge", value: model.permissions.notificationsAuthorized ? "Ready" : "Not authorized")
                    LabeledContent("Live match feed", value: model.errorMessage == nil ? "Available" : "Fallback")
                    LabeledContent("Stored cursor", value: String(UserDefaults.standard.integer(forKey: "messagesCursor")))
                }
            }
            .padding(18)
            .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 480, height: 410)
        .onChange(of: hotKeyEnabled) { _, _ in updateShortcut() }
        .onChange(of: hotKeyLetter) { _, _ in updateShortcut() }
        .onChange(of: hotKeyOption) { _, _ in updateShortcut() }
        .onChange(of: hotKeyShift) { _, _ in updateShortcut() }
        .onChange(of: hotKeyControl) { _, _ in updateShortcut() }
        .onChange(of: hotKeyCommand) { _, _ in updateShortcut() }
        .task { await model.refreshPermissions() }
    }

    private func updateShortcut() {
        AppDelegate.shared?.reconfigureHotKey()
    }
}

@MainActor
private struct SettingsStatusRow: View {
    let title: String
    let complete: Bool
    let required: Bool
    let action: () -> Void

    init(_ title: String, complete: Bool, required: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.complete = complete
        self.required = required
        self.action = action
    }

    var body: some View {
        HStack {
            Label(title, systemImage: complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(complete ? .green : .secondary)
            if !required { Text("Optional").font(.caption).foregroundStyle(.tertiary) }
            Spacer()
            if !complete { Button("Set Up", action: action).controlSize(.small) }
        }
    }
}
