import SwiftUI

// MARK: - Agent Detail Overlay

/// Isolated view that shows the agent detail panel.
/// Uses @State caching so the panel data is only recomputed when
/// the selection changes, not on every simulation frame.
struct AgentDetailOverlay: View {
    @Bindable var state: SimulationState

    @State private var cachedAgent: AgentModel?
    @State private var cachedToolCalls: [ToolCallModel] = []
    @State private var cachedMessages: [MessageBubble] = []
    @State private var refreshTimer: Timer?

    var body: some View {
        Group {
            if let agent = cachedAgent {
                AgentDetailPanel(
                    agent: agent,
                    toolCalls: cachedToolCalls,
                    messages: cachedMessages,
                    theme: state.theme,
                    onClose: { state.selectedAgentId = nil }
                )
                .padding(16)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.selectedAgentId)
        .onChange(of: state.selectedAgentId) { _, newId in
            updateCache(for: newId)
            startRefreshTimer(for: newId)
        }
        .onAppear {
            updateCache(for: state.selectedAgentId)
            startRefreshTimer(for: state.selectedAgentId)
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    /// Refresh the cached data from state (called on selection change + periodic timer)
    private func updateCache(for agentId: String?) {
        guard let agentId, let agent = state.agents[agentId] else {
            cachedAgent = nil
            cachedToolCalls = []
            cachedMessages = []
            return
        }

        cachedAgent = agent
        cachedToolCalls = Array(state.toolCalls.values
            .filter { $0.agentId == agentId }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(10))
        cachedMessages = Array((state.messageHistory[agentId] ?? []).suffix(50))
    }

    /// Refresh panel data every 2 seconds (not every frame) to pick up new messages/tools
    private func startRefreshTimer(for agentId: String?) {
        refreshTimer?.invalidate()
        guard agentId != nil else { refreshTimer = nil; return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                updateCache(for: state.selectedAgentId)
            }
        }
    }
}
