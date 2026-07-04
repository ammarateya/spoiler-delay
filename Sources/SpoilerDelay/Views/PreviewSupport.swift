#if DEBUG
import SwiftUI

@MainActor
private final class PreviewMessageSource: MessageSource {
    var canReadDatabase: Bool { get async { true } }
    func start(_ handler: @escaping @MainActor ([IncomingMessage]) -> Void) {}
    func stop() {}
}

@MainActor
private final class PreviewNotificationBridge: NotificationBridging {
    func requestAuthorization() async -> Bool { true }
    func deliver(_ message: IncomingMessage, after delay: TimeInterval) async {}
    func flushDelayedMessages() async {}
}

private struct PreviewFeed: MatchFeed {
    let matches: [WorldCupMatch]
    func upcomingMatches(now: Date) async throws -> [WorldCupMatch] { matches }
    func status(for match: WorldCupMatch) async throws -> WorldCupMatch { match }
}

@MainActor
private func previewModel(state: String) -> AppModel {
    let match = WorldCupMatch(
        id: "preview", homeTeam: "Portugal", awayTeam: "Croatia", homeCode: "POR", awayCode: "CRO",
        kickoff: Date.now.addingTimeInterval(1_800), stage: "Round of 16", phase: .secondHalf,
        clockSeconds: 72 * 60
    )
    let model = AppModel(
        messageSource: PreviewMessageSource(),
        notificationBridge: PreviewNotificationBridge(),
        feed: PreviewFeed(matches: [match])
    )
    let ready = PermissionState(
        notificationsAuthorized: true, fullDiskAccess: true, contactsAuthorized: true,
        launchAtLogin: true, nativeMessagesDisabled: true
    )
    switch state {
    case "idle": model.configurePreview(permissions: ready, matches: [match])
    case "setup": model.configurePreview(permissions: PermissionState())
    case "configure": model.configurePreview(permissions: ready, matches: [match], selectedMatch: match)
    default:
        let session = DelaySession(
            match: match, delaySeconds: 90, startedAt: .now,
            fallbackEnd: .now.addingTimeInterval(2_400), fullTimeDetectedAt: nil
        )
        model.configurePreview(permissions: ready, session: session)
    }
    return model
}

#Preview("Setup · Light", traits: .fixedLayout(width: 360, height: 500)) {
    RootPopoverView(model: previewModel(state: "setup")).preferredColorScheme(.light)
}

#Preview("Idle · Dark", traits: .fixedLayout(width: 360, height: 500)) {
    RootPopoverView(model: previewModel(state: "idle")).preferredColorScheme(.dark)
}

#Preview("Configure", traits: .fixedLayout(width: 360, height: 500)) {
    RootPopoverView(model: previewModel(state: "configure"))
}

#Preview("Active", traits: .fixedLayout(width: 360, height: 500)) {
    RootPopoverView(model: previewModel(state: "active"))
}
#endif
