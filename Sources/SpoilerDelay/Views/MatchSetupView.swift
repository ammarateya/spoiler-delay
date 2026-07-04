import SwiftUI

@MainActor
struct MatchSetupView: View {
    @ObservedObject var model: AppModel
    @FocusState private var focusedField: Field?

    private enum Field { case custom, clock }

    var body: some View {
        guard let match = model.selectedMatch else { return AnyView(EmptyView()) }
        return AnyView(ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Button(action: model.clearSelection) {
                    Label("Matches", systemImage: "chevron.left").font(.caption.weight(.medium))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 5) {
                    TeamMatchupView(match: match)
                    HStack {
                        Text(match.phase.label)
                        Text("•")
                        Text(match.kickoff, format: .dateTime.weekday(.abbreviated).hour().minute())
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stream delay").font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        ForEach(DelayMath.presets, id: \.self) { delay in
                            Button(DelayMath.format(delay)) { model.useDelay(delay) }
                                .buttonStyle(DelayPillStyle(selected: model.delaySeconds == delay))
                        }
                    }
                    HStack {
                        TextField("Seconds", text: $model.customDelayText)
                            .textFieldStyle(.roundedBorder).frame(width: 90)
                            .focused($focusedField, equals: .custom)
                            .onSubmit(model.applyCustomDelay)
                        Button("Use custom", action: model.applyCustomDelay).controlSize(.small)
                        Spacer()
                        Text("Current: \(DelayMath.format(model.delaySeconds))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let official = match.clockSeconds {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Calibrate from your screen").font(.subheadline.weight(.semibold))
                        HStack {
                            TextField("e.g. 63:24", text: $model.streamClockText)
                                .textFieldStyle(.roundedBorder).frame(width: 110)
                                .focused($focusedField, equals: .clock)
                            Button("Calculate", action: model.calibrate).controlSize(.small)
                            Spacer()
                        }
                        Text("Enter only the clock visible on your stream. FIFA's clock is sampled privately; scores are discarded. Official feed: \(DelayMath.format(TimeInterval(official))).")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Fallback protection end").font(.subheadline.weight(.semibold))
                    DatePicker("Protect until", selection: $model.fallbackEnd, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).labelsHidden()
                    Text("Live tracking ends protection at full-time + \(DelayMath.format(model.delaySeconds)) + 30s. This time is used only if the feed fails.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }

                Button(action: model.startSession) {
                    Label("Start Spoiler Mode", systemImage: "shield.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        })
    }
}

@MainActor
private struct DelayPillStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(selected ? Color.accentColor : Color.secondary.opacity(0.11), in: Capsule())
            .foregroundStyle(selected ? Color.white : Color.primary)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
