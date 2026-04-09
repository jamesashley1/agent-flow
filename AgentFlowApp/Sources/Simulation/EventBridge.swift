import Foundation

// MARK: - Event Bridge

/// Bridges AgentEvent objects from the session watcher
/// into SimulationEngine calls. Namespaces agent IDs by session
/// so multiple sessions can coexist without collisions.
final class EventBridge {
    private let engine: SimulationEngine
    private var knownAgents: Set<String> = []
    private var toolCallCounter: Int = 0

    init(engine: SimulationEngine) {
        self.engine = engine
    }

    func process(_ event: AgentEvent, sessionId: String, sessionLabel: String, source: EventSource) {
        switch event.type {
        case .agentSpawn:
            handleAgentSpawn(event.payload, sessionId: sessionId, sessionLabel: sessionLabel, source: source)

        case .agentComplete:
            handleAgentComplete(event.payload, sessionId: sessionId)

        case .agentIdle:
            if let name = event.payload["name"] as? String {
                let id = namespacedId(name, session: sessionId)
                engine.state.agents[id]?.state = .idle
            }

        case .message:
            handleMessage(event.payload, sessionId: sessionId)

        case .toolCallStart:
            handleToolCallStart(event.payload, sessionId: sessionId)

        case .toolCallEnd:
            handleToolCallEnd(event.payload, sessionId: sessionId)

        case .subagentDispatch:
            handleSubagentDispatch(event.payload, sessionId: sessionId, sessionLabel: sessionLabel, source: source)

        case .subagentReturn:
            handleSubagentReturn(event.payload, sessionId: sessionId)

        case .contextUpdate:
            handleContextUpdate(event.payload, sessionId: sessionId)

        case .modelDetected:
            if let model = event.payload["model"] as? String {
                engine.state.currentModel = model
            }

        case .planUpdate:
            handlePlanUpdate(event.payload)

        case .taskCreate:
            handleTaskCreate(event.payload)

        case .taskUpdate:
            handleTaskUpdate(event.payload)

        case .permissionRequested:
            if let name = event.payload["agent"] as? String {
                let id = namespacedId(name, session: sessionId)
                engine.state.agents[id]?.state = .waitingPermission
            }

        case .error:
            if let name = event.payload["agent"] as? String {
                let id = namespacedId(name, session: sessionId)
                engine.state.agents[id]?.state = .error
            }
        }
    }

    // MARK: - Handlers

    private func handleAgentSpawn(_ payload: [String: Any], sessionId: String, sessionLabel: String, source: EventSource) {
        let name = payload["name"] as? String ?? "agent"
        let isMain = payload["isMain"] as? Bool ?? false
        let parentName = payload["parent"] as? String

        let id = namespacedId(name, session: sessionId)
        let parentId = parentName.map { namespacedId($0, session: sessionId) }

        guard !knownAgents.contains(id) else { return }
        knownAgents.insert(id)

        engine.spawnAgent(
            id: id,
            name: name,
            parentId: parentId.flatMap { engine.state.agents[$0] != nil ? $0 : nil },
            isMain: isMain,
            sessionId: sessionId,
            sessionLabel: sessionLabel,
            source: source
        )
        engine.state.agents[id]?.state = .thinking
    }

    private func handleAgentComplete(_ payload: [String: Any], sessionId: String) {
        let name = payload["name"] as? String ?? "agent"
        let id = namespacedId(name, session: sessionId)
        guard engine.state.agents[id] != nil else { return }
        engine.completeAgent(id: id)
    }

    private func handleMessage(_ payload: [String: Any], sessionId: String) {
        let agentName = payload["agent"] as? String ?? "orchestrator"
        let roleStr = payload["role"] as? String ?? "assistant"
        let content = payload["content"] as? String ?? ""

        let id = namespacedId(agentName, session: sessionId)
        guard engine.state.agents[id] != nil else { return }

        let role: MessageBubble.MessageRole
        switch roleStr {
        case "user": role = .user
        case "thinking": role = .thinking
        default: role = .assistant
        }

        engine.addMessage(agentId: id, role: role, text: content)
    }

    private func handleToolCallStart(_ payload: [String: Any], sessionId: String) {
        let agentName = payload["agent"] as? String ?? "orchestrator"
        let toolName = payload["tool"] as? String ?? "unknown"
        let args = payload["args"] as? String ?? ""
        let toolId = payload["id"] as? String ?? generateToolId()

        let agentId = namespacedId(agentName, session: sessionId)
        guard engine.state.agents[agentId] != nil else { return }

        // Namespace tool ID too
        let nsToolId = "\(sessionId):\(toolId)"
        engine.startToolCall(id: nsToolId, agentId: agentId, name: toolName, args: args)
    }

    private func handleToolCallEnd(_ payload: [String: Any], sessionId: String) {
        let toolId = payload["id"] as? String ?? ""
        let nsToolId = "\(sessionId):\(toolId)"
        let result = payload["result"] as? String
        let isError = payload["isError"] as? Bool ?? false
        let errorMessage = payload["errorMessage"] as? String
        let tokenCost = payload["tokenCost"] as? Int ?? 0

        // Find tool by namespaced ID, or by matching agent+tool name
        let matchedId: String
        if engine.state.toolCalls[nsToolId] != nil {
            matchedId = nsToolId
        } else if let toolName = payload["tool"] as? String,
                  let agentName = payload["agent"] as? String {
            let aId = namespacedId(agentName, session: sessionId)
            if let match = engine.state.toolCalls.values.first(where: {
                $0.agentId == aId && $0.name == toolName && $0.state == .running
            }) {
                matchedId = match.id
            } else {
                return
            }
        } else {
            return
        }

        engine.completeToolCall(
            id: matchedId,
            result: result,
            tokenCost: tokenCost,
            error: isError ? (errorMessage ?? "Error") : nil
        )

        // Handle discovery
        if let discovery = payload["discovery"] as? [String: Any],
           let path = discovery["path"] as? String,
           let agentName = payload["agent"] as? String {
            let aId = namespacedId(agentName, session: sessionId)
            guard engine.state.agents[aId] != nil else { return }
            let typeStr = discovery["type"] as? String ?? "file_read"
            let discoveryType: DiscoveryType
            switch typeStr {
            case "file_create": discoveryType = .code
            case "file_modify": discoveryType = .code
            default: discoveryType = .file
            }
            engine.addDiscovery(
                agentId: aId,
                type: discoveryType,
                label: URL(fileURLWithPath: path).lastPathComponent,
                content: result ?? path
            )
        }
    }

    private func handleSubagentDispatch(_ payload: [String: Any], sessionId: String, sessionLabel: String, source: EventSource) {
        let childName = payload["child"] as? String ?? "subagent"
        let parentName = payload["parent"] as? String ?? "orchestrator"

        let childId = namespacedId(childName, session: sessionId)
        let parentId = namespacedId(parentName, session: sessionId)

        guard !knownAgents.contains(childId) else { return }
        knownAgents.insert(childId)

        engine.spawnAgent(
            id: childId,
            name: childName,
            parentId: engine.state.agents[parentId] != nil ? parentId : nil,
            sessionId: sessionId,
            sessionLabel: sessionLabel,
            source: source
        )
        engine.state.agents[childId]?.state = .thinking
    }

    private func handleSubagentReturn(_ payload: [String: Any], sessionId: String) {
        let childName = payload["child"] as? String ?? "subagent"
        let childId = namespacedId(childName, session: sessionId)
        guard engine.state.agents[childId] != nil else { return }
        engine.completeAgent(id: childId)
    }

    private func handleContextUpdate(_ payload: [String: Any], sessionId: String) {
        let agentName = payload["agent"] as? String ?? "orchestrator"
        let id = namespacedId(agentName, session: sessionId)
        guard engine.state.agents[id] != nil else { return }

        if let breakdown = payload["breakdown"] as? [String: Any] {
            let ctx = ContextBreakdown(
                systemPrompt: breakdown["systemPrompt"] as? Int ?? 0,
                userMessages: breakdown["userMessages"] as? Int ?? 0,
                toolResults: breakdown["toolResults"] as? Int ?? 0,
                reasoning: breakdown["reasoning"] as? Int ?? 0,
                subagentResults: breakdown["subagentResults"] as? Int ?? 0
            )
            engine.updateContext(agentId: id, breakdown: ctx)
        } else if let tokens = payload["tokens"] as? Int {
            engine.state.agents[id]?.tokensUsed = tokens
        }
    }

    // MARK: - Plan & Task Handlers

    private func handlePlanUpdate(_ payload: [String: Any]) {
        let action = payload["action"] as? String ?? ""
        let content = payload["content"] as? String ?? ""

        if action == "enter" {
            engine.state.activePlan = PlanState(content: content, isActive: true, updatedAt: engine.state.time)
        } else if action == "exit" {
            engine.state.activePlan?.isActive = false
        }

        // Also update plan content from thinking blocks that follow
        if !content.isEmpty {
            engine.state.activePlan?.content = content
            engine.state.activePlan?.updatedAt = engine.state.time
        }
    }

    private func handleTaskCreate(_ payload: [String: Any]) {
        let id = payload["id"] as? String ?? UUID().uuidString
        let subject = payload["subject"] as? String ?? "Task"
        let desc = payload["description"] as? String ?? ""

        let task = TaskItem(
            id: id, subject: subject, description: desc,
            status: .pending, createdAt: engine.state.time, updatedAt: engine.state.time
        )
        engine.state.tasks.append(task)
    }

    private func handleTaskUpdate(_ payload: [String: Any]) {
        let taskId = payload["taskId"] as? String ?? ""
        let statusStr = payload["status"] as? String ?? ""
        let subject = payload["subject"] as? String

        if let idx = engine.state.tasks.firstIndex(where: { $0.id == taskId }) {
            if let status = TaskItem.TaskStatus(rawValue: statusStr) {
                engine.state.tasks[idx].status = status
            }
            if let subject { engine.state.tasks[idx].subject = subject }
            engine.state.tasks[idx].updatedAt = engine.state.time
        }
    }

    // MARK: - Helpers

    /// Namespace an agent name with session ID to prevent collisions
    private func namespacedId(_ name: String, session: String) -> String {
        let sanitized = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "\(session):\(sanitized)"
    }

    private func generateToolId() -> String {
        toolCallCounter += 1
        return "tc-\(toolCallCounter)"
    }
}
