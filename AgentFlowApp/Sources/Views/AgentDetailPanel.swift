import SwiftUI

// MARK: - Agent Detail Panel

struct AgentDetailPanel: View {
    let agent: AgentModel
    let toolCalls: [ToolCallModel]
    let messages: [MessageBubble]
    let theme: Theme
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(agent.state.color)
                    .frame(width: 8, height: 8)

                Text(agent.name)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.white.opacity(0.1))

            // State
            HStack(spacing: 16) {
                statItem(label: "State", value: agent.state.rawValue.capitalized, color: agent.state.color)
                statItem(label: "Tools", value: "\(agent.toolCallCount)", color: .white)
            }

            // Token usage
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tokens")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("\(AgentRenderer.formatTokens(agent.tokensUsed)) / \(AgentRenderer.formatTokens(agent.tokensMax))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(agent.state.color.opacity(0.7))
                            .frame(
                                width: geo.size.width * min(CGFloat(agent.tokensUsed) / CGFloat(max(agent.tokensMax, 1)), 1),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                // Context breakdown
                if agent.context.total > 0 {
                    contextBreakdown
                }
            }

            // Recent tool calls
            if !toolCalls.isEmpty {
                Divider().overlay(Color.white.opacity(0.1))

                Text("Tool Calls")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(toolCalls.suffix(5)) { tool in
                            toolCallRow(tool)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            // Messages
            Divider().overlay(Color.white.opacity(0.1))

            Text("Messages (\(messages.count))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            if messages.isEmpty {
                Text("No messages yet")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { msg in
                            messageRow(msg)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .defaultScrollAnchor(.bottom)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.agentFillTop.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.uiBorder.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(color.opacity(0.9))
        }
    }

    private var contextBreakdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Context")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            HStack(spacing: 8) {
                contextLegend(label: "System", count: agent.context.systemPrompt, color: Color(red: 0.6, green: 0.5, blue: 1.0))
                contextLegend(label: "User", count: agent.context.userMessages, color: Color(red: 0.4, green: 0.8, blue: 1.0))
                contextLegend(label: "Tools", count: agent.context.toolResults, color: Color(red: 1.0, green: 0.73, blue: 0.27))
            }
            HStack(spacing: 8) {
                contextLegend(label: "Reasoning", count: agent.context.reasoning, color: Color(red: 0.4, green: 1.0, blue: 0.67))
                contextLegend(label: "Subagent", count: agent.context.subagentResults, color: Color(red: 1.0, green: 0.5, blue: 0.6))
            }
        }
    }

    private func contextLegend(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(label) \(AgentRenderer.formatTokens(count))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func messageRow(_ msg: MessageBubble) -> some View {
        let roleLabel: String
        let roleColor: Color
        let bgColor: Color
        switch msg.role {
        case .thinking:
            roleLabel = "thinking"
            roleColor = theme.thinking.opacity(0.7)
            bgColor = theme.bubbleThinking
        case .user:
            roleLabel = "user"
            roleColor = theme.ctxUser.opacity(0.7)
            bgColor = theme.bubbleUser
        case .assistant:
            roleLabel = "assistant"
            roleColor = theme.primary.opacity(0.7)
            bgColor = theme.bubbleAssistant
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text(roleLabel)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(roleColor)

            Text(msg.text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(bgColor.opacity(0.8))
        )
    }

    private func toolCallRow(_ tool: ToolCallModel) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tool.state == .running
                    ? Color(red: 1.0, green: 0.73, blue: 0.27)
                    : tool.state == .error
                        ? Color(red: 1.0, green: 0.33, blue: 0.4)
                        : Color(red: 0.4, green: 1.0, blue: 0.67))
                .frame(width: 5, height: 5)

            Text(tool.name)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            if tool.tokenCost > 0 {
                Text("\(AgentRenderer.formatTokens(tool.tokenCost))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.03))
        )
    }
}
