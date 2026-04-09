import SwiftUI

// MARK: - Top Bar

struct TopBar: View {
    @Bindable var state: SimulationState
    var sessionWatcher: SessionWatcher?

    var body: some View {
        HStack(spacing: 16) {
            // App title
            HStack(spacing: 8) {
                Image(systemName: state.theme.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(state.theme.uiAccent)

                Text("Agent Flow")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(statusLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(statusColor.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.1))
            )

            Spacer()

            // Agent count
            HStack(spacing: 6) {
                Image(systemName: "person.2")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))

                Text("\(state.agents.count) agents")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Model name
            if let model = state.currentModel {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                        .foregroundStyle(state.theme.uiAccent.opacity(0.6))

                    Text(formatModelName(model))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(state.theme.uiAccent.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(state.theme.uiAccent.opacity(0.08))
                )
            }

            // Token count
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))

                Text("\(AgentRenderer.formatTokens(state.totalTokens)) tokens")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Cost
            if state.showCost {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(state.theme.success)

                    Text(formatCost(state.totalTokens))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(state.theme.success.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(state.theme.success.opacity(0.08))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(state.theme.uiBackground.opacity(0.9))
                .overlay(
                    Rectangle()
                        .fill(state.theme.uiAccent.opacity(0.08))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    private var statusColor: Color {
        if let watcher = sessionWatcher {
            return watcher.isConnected
                ? state.theme.success
                : Color(red: 1.0, green: 0.73, blue: 0.27)
        }
        return Color(red: 0.6, green: 0.5, blue: 1.0)
    }

    private var statusLabel: String {
        if let watcher = sessionWatcher {
            if watcher.isConnected {
                let count = watcher.activeSessions
                let sources = Set(watcher.sessionSources.values.map(\.rawValue))
                let sourceStr = sources.sorted().joined(separator: "+")
                return count > 1 ? "LIVE \(count)x (\(sourceStr))" : "LIVE (\(sourceStr))"
            }
            return "WATCHING"
        }
        return "DEMO"
    }

    private func formatModelName(_ model: String) -> String {
        // Shorten model names: "claude-opus-4-6" → "Opus 4.6"
        if model.contains("opus") { return model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-", with: " ").capitalized }
        if model.contains("sonnet") { return model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-", with: " ").capitalized }
        if model.contains("haiku") { return model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-", with: " ").capitalized }
        return model
    }

    private func formatCost(_ tokens: Int) -> String {
        let cost = Double(tokens) * 8.0 / 1_000_000
        if cost < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", cost)
    }
}
