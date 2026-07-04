import SwiftUI

@MainActor
struct TeamMatchupView: View {
    let match: WorldCupMatch
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            HStack(spacing: compact ? 5 : 7) {
                Text(CountryFlag.emoji(for: match.homeCode))
                    .font(.system(size: compact ? 16 : 24))
                    .accessibilityHidden(true)
                Text(match.homeTeam)
                    .font(compact ? .subheadline.weight(.medium) : .headline)
                    .lineLimit(compact ? 1 : 2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("vs")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            HStack(spacing: compact ? 5 : 7) {
                Text(match.awayTeam)
                    .font(compact ? .subheadline.weight(.medium) : .headline)
                    .lineLimit(compact ? 1 : 2)
                    .multilineTextAlignment(.trailing)
                Text(CountryFlag.emoji(for: match.awayCode))
                    .font(.system(size: compact ? 16 : 24))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(match.title)
    }
}
