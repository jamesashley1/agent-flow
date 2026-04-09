import Foundation

// MARK: - Agent Event

struct AgentEvent {
    var time: Double
    var type: AgentEventType
    var payload: [String: Any]
    var sessionId: String?
}

enum AgentEventType: String {
    case agentSpawn = "agent_spawn"
    case agentComplete = "agent_complete"
    case agentIdle = "agent_idle"
    case message = "message"
    case contextUpdate = "context_update"
    case modelDetected = "model_detected"
    case toolCallStart = "tool_call_start"
    case toolCallEnd = "tool_call_end"
    case subagentDispatch = "subagent_dispatch"
    case subagentReturn = "subagent_return"
    case permissionRequested = "permission_requested"
    case error = "error"
    case planUpdate = "plan_update"
    case taskCreate = "task_create"
    case taskUpdate = "task_update"
}

// MARK: - Transcript Parser

/// Parses raw Claude Code JSONL transcript entries into AgentEvent objects.
/// Claude Code writes entries where:
///   - assistant entries contain text, thinking, and tool_use blocks
///   - user entries contain plain text or tool_result blocks
///   - other types (permission-mode, file-history-snapshot, attachment) are skipped
final class TranscriptParser {
    private var startTime: Date?
    private var seenToolUseIds: Set<String> = []
    private var pendingToolCalls: [String: (name: String, agent: String, args: String)] = [:]
    private var seenMessageHashes: Set<String> = []
    private var mainAgentSpawned = false
    private var currentModel: String?
    private var currentAgent: String = "orchestrator"

    // Token tracking
    private var userTokens: Int = 0
    private var assistantTokens: Int = 0
    private var toolResultTokens: Int = 0
    private var thinkingTokens: Int = 0

    func reset() {
        startTime = nil
        seenToolUseIds.removeAll()
        pendingToolCalls.removeAll()
        seenMessageHashes.removeAll()
        mainAgentSpawned = false
        currentModel = nil
        currentAgent = "orchestrator"
        userTokens = 0
        assistantTokens = 0
        toolResultTokens = 0
        thinkingTokens = 0
    }

    func processLine(_ line: String, sessionId: String?) -> [AgentEvent] {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        guard let entryType = json["type"] as? String else { return [] }

        // Check if this is a pre-processed AgentEvent (from test files or dev relay)
        if let eventType = AgentEventType(rawValue: entryType), json["payload"] != nil {
            return [parsePreProcessedEvent(json, type: eventType, sessionId: sessionId)]
        }

        // Skip non-message entry types
        guard entryType == "user" || entryType == "assistant" else { return [] }

        if startTime == nil {
            startTime = Date()
        }

        let elapsed = Date().timeIntervalSince(startTime!)
        let sid = sessionId ?? json["sessionId"] as? String
        let message = json["message"] as? [String: Any] ?? [:]

        var events: [AgentEvent] = []

        // Ensure main agent is spawned
        if !mainAgentSpawned {
            mainAgentSpawned = true
            events.append(AgentEvent(
                time: elapsed,
                type: .agentSpawn,
                payload: ["name": "orchestrator", "isMain": true],
                sessionId: sid
            ))
        }

        // Get content - can be a string or array of blocks
        let content = message["content"]

        if entryType == "assistant" {
            // Detect model
            if let model = message["model"] as? String, currentModel != model {
                currentModel = model
                events.append(AgentEvent(
                    time: elapsed,
                    type: .modelDetected,
                    payload: ["agent": currentAgent, "model": model],
                    sessionId: sid
                ))
            }
        }

        // Process content
        if let text = content as? String, !text.isEmpty {
            // Simple string content (user messages typically)
            events.append(contentsOf: processTextContent(
                text: text,
                role: entryType == "user" ? "user" : "assistant",
                elapsed: elapsed,
                sessionId: sid
            ))
        } else if let blocks = content as? [[String: Any]] {
            // Array of content blocks
            for block in blocks {
                guard let blockType = block["type"] as? String else { continue }

                switch blockType {
                case "text":
                    if let text = block["text"] as? String, !text.isEmpty {
                        events.append(contentsOf: processTextContent(
                            text: text,
                            role: entryType == "user" ? "user" : "assistant",
                            elapsed: elapsed,
                            sessionId: sid
                        ))
                    }

                case "thinking":
                    if let text = block["thinking"] as? String, !text.isEmpty {
                        let hash = "thinking:\(String(text.prefix(100)))"
                        guard !seenMessageHashes.contains(hash) else { continue }
                        seenMessageHashes.insert(hash)

                        thinkingTokens += estimateTokens(text)
                        events.append(AgentEvent(
                            time: elapsed,
                            type: .message,
                            payload: ["agent": currentAgent, "role": "thinking", "content": String(text.prefix(2000))],
                            sessionId: sid
                        ))
                    }

                case "tool_use":
                    events.append(contentsOf: processToolUse(block, elapsed: elapsed, sessionId: sid))

                case "tool_result":
                    events.append(contentsOf: processToolResult(block, elapsed: elapsed, sessionId: sid))

                default:
                    break
                }
            }
        }

        // Emit context update after processing content
        if !events.isEmpty {
            events.append(makeContextUpdate(elapsed: elapsed, sessionId: sid))
        }

        return events
    }

    // MARK: - Text Content

    private func processTextContent(text: String, role: String, elapsed: Double, sessionId: String?) -> [AgentEvent] {
        // Skip command/system messages
        if text.hasPrefix("<local-command") || text.hasPrefix("<command-name") || text.hasPrefix("<system-reminder") {
            return []
        }

        let hash = "\(role):\(String(text.prefix(100)))"
        guard !seenMessageHashes.contains(hash) else { return [] }
        seenMessageHashes.insert(hash)

        let truncated = String(text.prefix(2000))

        if role == "user" {
            userTokens += estimateTokens(text)
        } else {
            assistantTokens += estimateTokens(text)
        }

        return [AgentEvent(
            time: elapsed,
            type: .message,
            payload: ["agent": currentAgent, "role": role, "content": truncated],
            sessionId: sessionId
        )]
    }

    // MARK: - Tool Use

    private func processToolUse(_ block: [String: Any], elapsed: Double, sessionId: String?) -> [AgentEvent] {
        guard let toolId = block["id"] as? String,
              let toolName = block["name"] as? String else { return [] }

        guard !seenToolUseIds.contains(toolId) else { return [] }
        seenToolUseIds.insert(toolId)

        let input = block["input"] as? [String: Any] ?? [:]
        let args = summarizeToolArgs(name: toolName, input: input)

        var events: [AgentEvent] = []

        // Plan mode tools
        if toolName == "EnterPlanMode" || toolName == "ExitPlanMode" {
            let content = input["plan"] as? String ?? input["content"] as? String ?? ""
            events.append(AgentEvent(
                time: elapsed,
                type: .planUpdate,
                payload: ["action": toolName == "EnterPlanMode" ? "enter" : "exit", "content": String(content.prefix(5000))],
                sessionId: sessionId
            ))
            pendingToolCalls[toolId] = (name: toolName, agent: currentAgent, args: "plan")
            return events
        }

        // Task tools
        if toolName == "TaskCreate" {
            let subject = input["subject"] as? String ?? ""
            let desc = input["description"] as? String ?? ""
            events.append(AgentEvent(
                time: elapsed,
                type: .taskCreate,
                payload: ["id": toolId, "subject": subject, "description": String(desc.prefix(500))],
                sessionId: sessionId
            ))
            pendingToolCalls[toolId] = (name: toolName, agent: currentAgent, args: subject)
            return events
        }

        if toolName == "TaskUpdate" {
            let taskId = input["taskId"] as? String ?? toolId
            let status = input["status"] as? String ?? ""
            let subject = input["subject"] as? String
            events.append(AgentEvent(
                time: elapsed,
                type: .taskUpdate,
                payload: ["taskId": taskId, "status": status, "subject": subject as Any],
                sessionId: sessionId
            ))
            pendingToolCalls[toolId] = (name: toolName, agent: currentAgent, args: status)
            return events
        }

        // Check if this is a subagent dispatch
        if toolName == "Agent" || toolName == "dispatch_agent" {
            let childName = input["description"] as? String
                ?? input["name"] as? String
                ?? "subagent"
            let task = input["prompt"] as? String
                ?? input["task"] as? String
                ?? ""

            events.append(AgentEvent(
                time: elapsed,
                type: .subagentDispatch,
                payload: ["parent": currentAgent, "child": childName, "task": String(task.prefix(200))],
                sessionId: sessionId
            ))
            events.append(AgentEvent(
                time: elapsed,
                type: .agentSpawn,
                payload: ["name": childName, "parent": currentAgent, "task": String(task.prefix(200))],
                sessionId: sessionId
            ))

            pendingToolCalls[toolId] = (name: toolName, agent: currentAgent, args: childName)
        } else {
            events.append(AgentEvent(
                time: elapsed,
                type: .toolCallStart,
                payload: [
                    "id": toolId,
                    "agent": currentAgent,
                    "tool": toolName,
                    "args": args,
                    "preview": "\(toolName): \(String(args.prefix(60)))"
                ],
                sessionId: sessionId
            ))

            pendingToolCalls[toolId] = (name: toolName, agent: currentAgent, args: args)
        }

        return events
    }

    // MARK: - Tool Result

    private func processToolResult(_ block: [String: Any], elapsed: Double, sessionId: String?) -> [AgentEvent] {
        guard let toolUseId = block["tool_use_id"] as? String,
              let pending = pendingToolCalls[toolUseId] else { return [] }

        let resultText = extractToolResult(block)
        let isError = block["is_error"] as? Bool ?? false
        toolResultTokens += estimateTokens(resultText)

        var events: [AgentEvent] = []

        // Check if this was a subagent
        if pending.name == "Agent" || pending.name == "Task" || pending.name == "dispatch_agent" {
            let childName = pending.args
            events.append(AgentEvent(
                time: elapsed,
                type: .subagentReturn,
                payload: ["parent": pending.agent, "child": childName, "summary": String(resultText.prefix(80))],
                sessionId: sessionId
            ))
            events.append(AgentEvent(
                time: elapsed,
                type: .agentComplete,
                payload: ["name": childName],
                sessionId: sessionId
            ))
        } else {
            var payload: [String: Any] = [
                "id": toolUseId,
                "agent": pending.agent,
                "tool": pending.name,
                "result": String(resultText.prefix(200))
            ]

            if isError {
                payload["isError"] = true
                payload["errorMessage"] = String(resultText.prefix(200))
            }

            // File discovery for file-related tools
            if ["Read", "Write", "Edit", "Glob", "Grep"].contains(pending.name) {
                let discoveryType: String
                switch pending.name {
                case "Write": discoveryType = "file_create"
                case "Edit": discoveryType = "file_modify"
                default: discoveryType = "file_read"
                }
                payload["discovery"] = [
                    "type": discoveryType,
                    "path": pending.args
                ]
            }

            events.append(AgentEvent(
                time: elapsed,
                type: .toolCallEnd,
                payload: payload,
                sessionId: sessionId
            ))
        }

        pendingToolCalls.removeValue(forKey: toolUseId)
        return events
    }

    // MARK: - Pre-processed Events

    private func parsePreProcessedEvent(_ json: [String: Any], type: AgentEventType, sessionId: String?) -> AgentEvent {
        AgentEvent(
            time: json["time"] as? Double ?? 0,
            type: type,
            payload: json["payload"] as? [String: Any] ?? [:],
            sessionId: sessionId ?? json["sessionId"] as? String
        )
    }

    // MARK: - Helpers

    private func summarizeToolArgs(name: String, input: [String: Any]) -> String {
        switch name {
        case "Read":
            return input["file_path"] as? String ?? input["path"] as? String ?? ""
        case "Write":
            let path = input["file_path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            return "\(path) (\(content.count) chars)"
        case "Edit":
            return input["file_path"] as? String ?? ""
        case "Bash":
            return input["command"] as? String ?? ""
        case "Grep":
            let pattern = input["pattern"] as? String ?? ""
            let path = input["path"] as? String ?? ""
            return "'\(pattern)' in \(path)"
        case "Glob":
            return input["pattern"] as? String ?? ""
        case "Agent", "Task", "dispatch_agent":
            return input["description"] as? String ?? input["name"] as? String ?? ""
        default:
            if let first = input.first {
                return "\(first.key): \(String(describing: first.value).prefix(60))"
            }
            return ""
        }
    }

    private func extractToolResult(_ block: [String: Any]) -> String {
        if let content = block["content"] as? String {
            return content
        }
        if let contentBlocks = block["content"] as? [[String: Any]] {
            return contentBlocks.compactMap { b -> String? in
                if b["type"] as? String == "text" { return b["text"] as? String }
                return nil
            }.joined(separator: "\n")
        }
        return ""
    }

    private func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    private func makeContextUpdate(elapsed: Double, sessionId: String?) -> AgentEvent {
        AgentEvent(
            time: elapsed,
            type: .contextUpdate,
            payload: [
                "agent": currentAgent,
                "tokens": userTokens + assistantTokens + toolResultTokens + thinkingTokens,
                "breakdown": [
                    "systemPrompt": 4000,
                    "userMessages": userTokens,
                    "toolResults": toolResultTokens,
                    "reasoning": thinkingTokens + assistantTokens,
                    "subagentResults": 0
                ] as [String: Int]
            ],
            sessionId: sessionId
        )
    }
}
