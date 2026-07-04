import Foundation

@MainActor
protocol MessageSource: AnyObject {
    var canReadDatabase: Bool { get async }
    func start(_ handler: @escaping @MainActor ([IncomingMessage]) -> Void)
    func stop()
}

protocol MatchFeed: Sendable {
    func upcomingMatches(now: Date) async throws -> [WorldCupMatch]
    func status(for match: WorldCupMatch) async throws -> WorldCupMatch
}

@MainActor
protocol NotificationBridging: AnyObject {
    func requestAuthorization() async -> Bool
    func deliver(_ message: IncomingMessage, after delay: TimeInterval) async
    func flushDelayedMessages() async
}
