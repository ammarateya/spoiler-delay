import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationBridge: NSObject, NotificationBridging, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func deliver(_ message: IncomingMessage, after delay: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = message.sender
        if let chat = message.chatName, chat != message.sender { content.subtitle = chat }
        content.body = message.body
        content.sound = .default
        content.threadIdentifier = message.chatName ?? message.sender
        content.userInfo = [
            "messageID": message.id,
            "spoilerDelayed": delay > 0
        ]
        let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false) : nil
        let request = UNNotificationRequest(identifier: "message.\(message.id)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    func flushDelayedMessages() async {
        let allRequests = await center.pendingNotificationRequests()
        let delayed = allRequests.filter { request in
            (request.content.userInfo["spoilerDelayed"] as? Bool) == true
        }
        let pending: [UNNotificationRequest] = delayed.sorted { first, second in
            let firstID = (first.content.userInfo["messageID"] as? NSNumber)?.int64Value ?? .max
            let secondID = (second.content.userInfo["messageID"] as? NSNumber)?.int64Value ?? .max
            return firstID < secondID
        }
        center.removePendingNotificationRequests(withIdentifiers: pending.map { $0.identifier })
        for (index, request) in pending.enumerated() {
            let mutable = request.content.mutableCopy() as? UNMutableNotificationContent
            mutable?.userInfo["spoilerDelayed"] = false
            let trigger = index == 0 ? nil : UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(index), repeats: false)
            let replacement = UNNotificationRequest(
                identifier: "\(request.identifier).released",
                content: mutable ?? request.content,
                trigger: trigger
            )
            try? await center.add(replacement)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
        Task { @MainActor in
            if let url = URL(string: "messages:") { NSWorkspace.shared.open(url) }
        }
    }
}
