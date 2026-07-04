import SwiftUI

@MainActor
struct IdleView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("World Cup").font(.title3.bold())
                    Text("Choose what you're watching").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isLoadingMatches { ProgressView().controlSize(.small) }
                else {
                    Button { Task { await model.loadMatches() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).help("Refresh matches")
                }
            }

            if model.matches.isEmpty && !model.isLoadingMatches {
                ContentUnavailableView {
                    Label("No matches found", systemImage: "soccerball")
                } description: {
                    Text("Start a manual session or refresh the FIFA schedule.")
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.matches.prefix(8)) { match in
                            MatchRow(match: match) { model.select(match) }
                        }
                    }
                }
            }

            Divider()
            Button {
                let match = WorldCupMatch(
                    id: "manual-\(UUID().uuidString)", homeTeam: "Manual", awayTeam: "Session",
                    homeCode: "", awayCode: "", kickoff: .now, stage: "Soccer",
                    phase: .unknown, clockSeconds: nil
                )
                model.select(match)
            } label: {
                Label("Start without a listed match", systemImage: "timer")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

@MainActor
private struct MatchRow: View {
    let match: WorldCupMatch
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(spacing: 3) {
                    Text(match.kickoff, format: .dateTime.hour().minute())
                        .font(.caption.weight(.semibold))
                    Text(match.kickoff, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: 48)
                Divider().frame(height: 34)
                VStack(alignment: .leading, spacing: 5) {
                    TeamMatchupView(match: match, compact: true)
                    HStack(spacing: 5) {
                        if match.phase != .scheduled {
                            Circle().fill(.red).frame(width: 5, height: 5)
                        }
                        Text(match.phase.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(11)
            .contentShape(Rectangle())
            .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(match.title), \(match.phase.label), \(match.kickoff.formatted())")
    }
}
