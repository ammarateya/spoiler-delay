import SwiftUI

@MainActor
struct RootPopoverView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if !model.permissions.requiredReady {
                    SetupView(model: model)
                } else if let session = model.session {
                    ActiveSessionView(model: model, session: session)
                } else if model.selectedMatch != nil {
                    MatchSetupView(model: model)
                } else {
                    IdleView(model: model)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: screenKey)
        }
        .frame(width: 360, height: 500)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            if let message = model.errorMessage {
                ErrorBanner(message: message, dismiss: model.dismissError)
                    .padding(.top, 50)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var screenKey: String {
        if !model.permissions.requiredReady { return "setup" }
        if model.session != nil { return "active" }
        if model.selectedMatch != nil { return "configure" }
        return "idle"
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: model.statusSymbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(model.isActive ? .blue : .primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Spoiler Delay").font(.headline)
                Text(model.isActive ? "Protection active" : "Messages, on your time")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                AppDelegate.shared?.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Open settings")
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }
}

@MainActor
private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).lineLimit(3)
            Spacer(minLength: 4)
            Button(action: dismiss) { Image(systemName: "xmark") }
                .buttonStyle(.plain).accessibilityLabel("Dismiss")
        }
        .padding(10)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}
