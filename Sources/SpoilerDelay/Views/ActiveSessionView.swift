import SwiftUI

@MainActor
struct ActiveSessionView: View {
    @ObservedObject var model: AppModel
    let session: DelaySession
    @State private var now = Date.now

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = max(0, session.automaticEnd.timeIntervalSince(now))
        return VStack(spacing: 18) {
                Spacer(minLength: 4)
                ZStack {
                    Circle().fill(.blue.opacity(0.10)).frame(width: 92, height: 92)
                    Circle().stroke(.blue.opacity(0.18), lineWidth: 5).frame(width: 92, height: 92)
                    Image(systemName: "shield.fill")
                        .font(.system(size: 37, weight: .medium)).foregroundStyle(.blue)
                }
                .accessibilityLabel("Spoiler protection is active")

                VStack(spacing: 5) {
                    TeamMatchupView(match: session.match)
                    HStack(spacing: 6) {
                        Circle().fill(session.match.phase == .fullTime ? Color.secondary : Color.red).frame(width: 6, height: 6)
                        Text(session.match.phase.label)
                        if let clock = session.match.clockSeconds, session.match.phase != .fullTime {
                            Text("• \(DelayMath.format(TimeInterval(clock)))")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    InfoLine(label: "Messages delayed", value: DelayMath.format(session.delaySeconds))
                    InfoLine(label: session.fullTimeDetectedAt == nil ? "Fallback ends" : "Releasing in", value: session.fullTimeDetectedAt == nil ? session.fallbackEnd.formatted(date: .omitted, time: .shortened) : DelayMath.format(remaining))
                }
                .padding(12)
                .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Scores and match events are never shown or saved.")
                    .font(.caption2).foregroundStyle(.tertiary)

                Spacer()
                Button(role: .destructive, action: model.stopSession) {
                    Text("Stop and release queued messages").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
        }
        .padding(16)
        .onReceive(ticker) { now = $0 }
    }
}

@MainActor
private struct InfoLine: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
