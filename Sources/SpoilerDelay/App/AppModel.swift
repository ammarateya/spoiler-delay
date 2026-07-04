import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var permissions = PermissionState()
    @Published private(set) var matches: [WorldCupMatch] = []
    @Published private(set) var session: DelaySession?
    @Published var selectedMatch: WorldCupMatch?
    @Published var delaySeconds: TimeInterval = 90
    @Published var customDelayText = "90"
    @Published var streamClockText = ""
    @Published var fallbackEnd = Date.now.addingTimeInterval(3 * 60 * 60)
    @Published var isLoadingMatches = false
    @Published var errorMessage: String?

    let messageSource: MessageSource
    let notificationBridge: NotificationBridging
    let feed: MatchFeed
    let permissionManager: PermissionManager

    private var messageSourceStarted = false
    private var matchTimer: Timer?
    private var endTimer: Timer?
    private let sessionKey = "activeDelaySession"

    convenience init() {
        self.init(
            messageSource: MessagesDatabaseSource(),
            notificationBridge: NotificationBridge(),
            feed: FIFAMatchFeed()
        )
    }

    init(
        messageSource: MessageSource,
        notificationBridge: NotificationBridging,
        feed: MatchFeed
    ) {
        self.messageSource = messageSource
        self.notificationBridge = notificationBridge
        self.feed = feed
        self.permissionManager = PermissionManager(messageSource: messageSource)
        restoreSession()
    }

    var isActive: Bool { session != nil }
    var statusSymbol: String {
        if errorMessage != nil { return "exclamationmark.shield.fill" }
        return isActive ? "clock.badge.checkmark.fill" : "shield.lefthalf.filled"
    }

    func start() {
        Task {
            await refreshPermissions()
            await loadMatches()
            if session != nil { beginSessionMonitoring() }
        }
    }

    func refreshPermissions() async {
        permissions = await permissionManager.currentState()
        if permissions.requiredReady && !messageSourceStarted {
            messageSourceStarted = true
            messageSource.start { [weak self] messages in
                guard let self else { return }
                Task { await self.handle(messages) }
            }
        }
    }

    func requestNotifications() {
        Task {
            _ = await notificationBridge.requestAuthorization()
            await refreshPermissions()
        }
    }

    func requestContacts() {
        Task {
            await permissionManager.requestContacts()
            await refreshPermissions()
        }
    }

    func setNativeMessagesDisabled(_ disabled: Bool) {
        UserDefaults.standard.set(disabled, forKey: "nativeMessagesDisabled")
        Task { await refreshPermissions() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        permissionManager.setLaunchAtLogin(enabled)
        Task { await refreshPermissions() }
    }

    func loadMatches() async {
        isLoadingMatches = true
        defer { isLoadingMatches = false }
        do {
            matches = try await feed.upcomingMatches(now: .now)
            errorMessage = nil
        } catch {
            errorMessage = "World Cup schedule unavailable. You can still use a manual session."
        }
    }

    func select(_ match: WorldCupMatch) {
        selectedMatch = match
        delaySeconds = 90
        customDelayText = "90"
        streamClockText = ""
        fallbackEnd = match.estimatedEnd.addingTimeInterval(delaySeconds + 30)
    }

    func useDelay(_ seconds: TimeInterval) {
        delaySeconds = seconds
        customDelayText = String(Int(seconds))
        if let match = selectedMatch {
            fallbackEnd = match.estimatedEnd.addingTimeInterval(seconds + 30)
        }
    }

    func applyCustomDelay() {
        guard let value = TimeInterval(customDelayText), value >= 0, value <= 6 * 60 * 60 else { return }
        useDelay(value)
    }

    func calibrate() {
        guard let official = selectedMatch?.clockSeconds,
              let calibrated = DelayMath.calibratedDelay(officialClock: official, streamClock: streamClockText) else {
            errorMessage = "Enter the match clock shown on your stream, such as 63:24."
            return
        }
        useDelay(calibrated)
        errorMessage = nil
    }

    func startSession() {
        guard let match = selectedMatch else { return }
        let safeFallback = max(fallbackEnd, Date.now.addingTimeInterval(delaySeconds + 60))
        session = DelaySession(
            match: match,
            delaySeconds: delaySeconds,
            startedAt: .now,
            fallbackEnd: safeFallback,
            fullTimeDetectedAt: nil
        )
        selectedMatch = nil
        persistSession()
        beginSessionMonitoring()
    }

    func stopSession() {
        matchTimer?.invalidate()
        endTimer?.invalidate()
        matchTimer = nil
        endTimer = nil
        session = nil
        persistSession()
        Task { await notificationBridge.flushDelayedMessages() }
    }

    func clearSelection() {
        selectedMatch = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    private func handle(_ messages: [IncomingMessage]) async {
        if let current = session, current.automaticEnd <= .now { stopSession() }
        let delay = session?.delaySeconds ?? 0
        for message in messages {
            await notificationBridge.deliver(message, after: delay)
        }
    }

    private func beginSessionMonitoring() {
        matchTimer?.invalidate()
        endTimer?.invalidate()
        matchTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshActiveMatch() }
        }
        endTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkAutomaticEnd() }
        }
        Task { await refreshActiveMatch() }
    }

    private func refreshActiveMatch() async {
        guard var currentSession = session else { return }
        do {
            let current = try await feed.status(for: currentSession.match)
            currentSession.match = current
            if current.phase == .fullTime && currentSession.fullTimeDetectedAt == nil {
                currentSession.fullTimeDetectedAt = .now
            }
            session = currentSession
            persistSession()
            errorMessage = nil
        } catch {
            errorMessage = "Live match tracking is unavailable. Protection will use the fallback end time."
        }
    }

    private func checkAutomaticEnd() {
        guard let session, session.automaticEnd <= .now else { return }
        stopSession()
    }

    private func persistSession() {
        if let session, let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let saved = try? JSONDecoder().decode(DelaySession.self, from: data),
              saved.automaticEnd > .now else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
            return
        }
        session = saved
    }

#if DEBUG
    func configurePreview(
        permissions: PermissionState,
        matches: [WorldCupMatch] = [],
        selectedMatch: WorldCupMatch? = nil,
        session: DelaySession? = nil
    ) {
        self.permissions = permissions
        self.matches = matches
        self.selectedMatch = selectedMatch
        self.session = session
        if let selectedMatch { fallbackEnd = selectedMatch.estimatedEnd }
    }
#endif
}

@MainActor
enum AppRuntime {
    static let model = AppModel()
}
