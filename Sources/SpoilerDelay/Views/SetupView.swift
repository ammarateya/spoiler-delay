import SwiftUI

@MainActor
struct SetupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Finish setup").font(.title2.bold())
                    Text("Three required steps let Spoiler Delay safely replace Messages alerts. Message content stays on this Mac.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    PermissionRow(
                        symbol: "bell.badge",
                        title: "Allow notifications",
                        detail: "Shows immediate and delayed replacement alerts.",
                        complete: model.permissions.notificationsAuthorized,
                        actionTitle: "Allow",
                        action: model.requestNotifications
                    )
                    Divider().padding(.leading, 42)
                    PermissionRow(
                        symbol: "externaldrive.badge.checkmark",
                        title: "Full Disk Access",
                        detail: "Required to read Messages locally. Reopen after granting.",
                        complete: model.permissions.fullDiskAccess,
                        actionTitle: "Open Settings"
                    ) { model.permissionManager.openFullDiskAccessSettings() }
                    Divider().padding(.leading, 42)
                    PermissionRow(
                        symbol: "message.badge.filled.fill",
                        title: "Disable Messages alerts",
                        detail: "Prevents native alerts from leaking or duplicating messages.",
                        complete: model.permissions.nativeMessagesDisabled,
                        actionTitle: "Open Settings"
                    ) { model.permissionManager.openNotificationSettings() }
                }
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Toggle("I disabled native Messages notifications", isOn: Binding(
                    get: { model.permissions.nativeMessagesDisabled },
                    set: { value in model.setNativeMessagesDisabled(value) }
                ))
                .toggleStyle(.checkbox)

                HStack {
                    Button("Check again") { Task { await model.refreshPermissions() } }
                    Spacer()
                    Text("Contacts and login options are in Settings")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
    }
}

@MainActor
private struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let complete: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(complete ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            if complete {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Complete")
            } else {
                Button(actionTitle, action: action).controlSize(.small)
            }
        }
        .padding(11)
    }
}
