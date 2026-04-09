import SwiftUI

// MARK: - Message Feed Panel

/// Always-visible scrollable feed of agent–user communications across all agents.
/// Collapsed: shows the latest message as a one-line preview.
/// Expanded: scrollable list with agent tabs and auto-scroll.
struct MessageFeedPanel: View {
    @Bindable var state: SimulationState
    var onAgentClick: (String) -> Void

    @State private var expanded = false
    @State private var activeTab: String? = nil  // nil = all agents
    @State private var cachedMessages: [FeedMessage] = []
    @State private var refreshTimer: Timer?

    private let maxMessages = 200

    var body: some View {
        if expanded {
            expandedView
        } else {
            collapsedView
        }
    }

    // MARK: - Collapsed

    private var collapsedView: some View {
        Group {
            if let latest = cachedMessages.last {
                Button(action: { expanded = true }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(roleColor(latest.role))
                            .frame(width: 6, height: 6)

                        Text(latest.agentName)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)

                        Text(latest.text.replacingOccurrences(of: "\n", with: " ").prefix(50))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(roleColor(latest.role).opacity(0.8))
                            .lineLimit(1)

                        Text("▾")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(glassBackground)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 320, alignment: .leading)
            }
        }
        .onAppear { startRefresh() }
        .onDisappear { stopRefresh() }
    }

    // MARK: - Expanded

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("MESSAGES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Button(action: { expanded = false }) {
                    Text("▴")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Agent tabs
            let agentIds = agentsWithMessages()
            if agentIds.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        tabButton(label: "All", isActive: activeTab == nil) {
                            activeTab = nil
                            refreshCache()
                        }
                        ForEach(agentIds, id: \.self) { agentId in
                            let name = state.agents[agentId]?.name ?? agentId
                            let displayName = name.count > 14 ? String(name.prefix(14)) + ".." : name
                            tabButton(label: displayName, isActive: activeTab == agentId) {
                                activeTab = agentId
                                refreshCache()
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.bottom, 6)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    let filtered = filteredMessages()
                    if filtered.isEmpty {
                        Text("No messages yet")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filtered) { msg in
                                messageRow(msg, showAgent: activeTab == nil)
                                    .id(msg.id)
                                    .onTapGesture {
                                        onAgentClick(msg.agentId)
                                        expanded = false
                                    }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .onChange(of: filtered.count) { _, _ in
                            if let last = filtered.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
        .frame(width: 320)
        .background(glassBackground)
        .onAppear { startRefresh() }
        .onDisappear { stopRefresh() }
    }

    // MARK: - Message Row

    private func messageRow(_ msg: FeedMessage, showAgent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(roleLabel(msg.role))
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(roleColor(msg.role).opacity(0.7))

                if showAgent {
                    Text(msg.agentName)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Text(msg.text)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(expanded ? 6 : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(roleBgColor(msg.role))
        )
    }

    // MARK: - Tab Button

    private func tabButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(isActive ? state.theme.uiAccent : .white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? state.theme.uiAccent.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private struct FeedMessage: Identifiable {
        let id: UUID
        let agentId: String
        let agentName: String
        let role: MessageBubble.MessageRole
        let text: String
        let timestamp: Double
    }

    /// Only include text messages (user, assistant, thinking) — not tool call summaries
    private static let textRoles: Set<String> = ["user", "assistant", "thinking"]

    private func isTextMessage(_ msg: MessageBubble) -> Bool {
        // Filter out tool call summary lines (prefixed with → or ←)
        !msg.text.hasPrefix("→ ") && !msg.text.hasPrefix("← ")
    }

    private func refreshCache() {
        var all: [FeedMessage] = []
        for (agentId, messages) in state.messageHistory {
            let agentName = state.agents[agentId]?.name ?? agentId
            for msg in messages where isTextMessage(msg) {
                all.append(FeedMessage(
                    id: msg.id,
                    agentId: agentId,
                    agentName: agentName,
                    role: msg.role,
                    text: msg.text,
                    timestamp: msg.createdAt
                ))
            }
        }
        all.sort { $0.timestamp < $1.timestamp }
        if all.count > maxMessages {
            all = Array(all.suffix(maxMessages))
        }
        cachedMessages = all
    }

    private func filteredMessages() -> [FeedMessage] {
        guard let tab = activeTab else { return cachedMessages }
        return cachedMessages.filter { $0.agentId == tab }
    }

    private func agentsWithMessages() -> [String] {
        var ids: [String] = []
        for (agentId, messages) in state.messageHistory {
            if messages.contains(where: { isTextMessage($0) }) {
                ids.append(agentId)
            }
        }
        return ids.sorted { a, b in
            let aMain = state.agents[a]?.isMain == true
            let bMain = state.agents[b]?.isMain == true
            if aMain != bMain { return aMain }
            return (state.agents[a]?.name ?? a) < (state.agents[b]?.name ?? b)
        }
    }

    // MARK: - Refresh Timer

    private func startRefresh() {
        refreshCache()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in refreshCache() }
        }
    }

    private func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Styling

    private func roleLabel(_ role: MessageBubble.MessageRole) -> String {
        switch role {
        case .user: return "USER"
        case .assistant: return "CLAUDE"
        case .thinking: return "THINKING"
        }
    }

    private func roleColor(_ role: MessageBubble.MessageRole) -> Color {
        switch role {
        case .user: return state.theme.ctxUser
        case .assistant: return state.theme.primary
        case .thinking: return state.theme.thinking
        }
    }

    private func roleBgColor(_ role: MessageBubble.MessageRole) -> Color {
        switch role {
        case .user: return state.theme.bubbleUser.opacity(0.8)
        case .assistant: return state.theme.bubbleAssistant.opacity(0.8)
        case .thinking: return state.theme.bubbleThinking.opacity(0.6)
        }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(state.theme.agentFillTop.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(state.theme.uiBorder.opacity(0.12), lineWidth: 0.5)
            )
    }
}
