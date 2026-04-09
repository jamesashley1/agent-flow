import Foundation

// MARK: - Codex Transcript Parser

/// Parses OpenAI Codex CLI JSONL transcript entries into AgentEvent objects.
/// Codex writes entries with a different schema from Claude Code:
///   - session_meta: session start with model info
///   - event_msg: user_message, agent_message, task_started, task_complete, token_count
///   - response_item: message (user/assistant), function_call, function_call_output, reasoning
///   - response_completed: usage stats
final class CodexTranscriptParser {
    private var startTime: Date?
    private var mainAgentSpawned = false
    private var seenCallIds: Set<String> = []
    private var pendingToolCalls: [String: (name: String, args: String)] = [:]
    private var seenMessageHashes: Set<String> = []
    private var currentModel: String?

    // Token tracking
    private var inputTokens: Int = 0
    private var outputTokens: Int = 0
    private var reasoningTokens: Int = 0

    private let agentName = "orchestrator"

    /// Project name extracted from session_meta cwd (e.g. "DrawThis")
    private(set) var projectName: String?

    func reset() {
        startTime = nil
        mainAgentSpawned = false
        seenCallIds.removeAll()
        pendingToolCalls.removeAll()
        seenMessageHashes.removeAll()
        currentModel = nil
        inputTokens = 0
        outputTokens = 0
        reasoningTokens = 0
    }

    func processLine(_ line: String, sessionId: String?) -> [AgentEvent] {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        guard let entryType = json["type"] as? String else { return [] }

        if startTime == nil {
            startTime = Date()
        }
        let elapsed = Date().timeIntervalSince(startTime!)

        switch entryType {
        case "session_meta":
            return handleSessionMeta(json, elapsed: elapsed, sessionId: sessionId)
        case "event_msg":
            return handleEventMsg(json, elapsed: elapsed, sessionId: sessionId)
        case "response_item":
            return handleResponseItem(json, elapsed: elapsed, sessionId: sessionId)
        case "response_completed":
            return handleResponseCompleted(json, elapsed: elapsed, sessionId: sessionId)
        default:
            return []
        }
    }

    // MARK: - Session Meta

    private func handleSessionMeta(_ json: [String: Any], elapsed: Double, sessionId: String?) -> [AgentEvent] {
        let payload = json["payload"] as? [String: Any] ?? [:]
        let model = payload["model_provider"] as? String ?? "codex"

        // Extract project name from cwd (e.g. "/Users/james/source/repos/DrawThis" → "DrawThis")
        if projectName == nil, let cwd = payload["cwd"] as? String {
            projectName = (cwd as NSString).lastPathComponent
        }

        var events: [AgentEvent] = []

        if !mainAgentSpawned {
            mainAgentSpawned = true
            events.append(AgentEvent(
                time: elapsed,
                type: .agentSpawn,
                payload: ["name": agentName, "isMain": true],
                sessionId: sessionId
            ))
        }

        if currentModel != model {
            currentModel = model
            events.append(AgentEvent(
                time: elapsed,
                type: .modelDetected,
                payload: ["agent": agentName, "model": model],
                sessionId: sessionId
            ))
        }

        return events
    }

    // MARK: - Event Messages

    private func handleEventMsg(_ json: [String: Any], elapsed: Double, sessionId: String?) -> [AgentEvent] {
        let payload = json["payload"] as? [String: Any] ?? [:]
        guard let msgType = payload["type"] as? String else { return [] }

        var events = ensureSpawned(elapsed: elapsed, sessionId: sessionId)

        switch msgType {
        case "user_message":
            let text = payload["message"] as? String ?? ""
            if !text.isEmpty {
                let hash = "user:\(String(text.prefix(100)))"
                if !seenMessageHashes.contains(hash) {
                    seenMessageHashes.insert(hash)
                    events.append(AgentEvent(
                        time: elapsed,
                        type: .message,
                        payload: ["agent": agentName, "role": "user", "content": String(text.prefix(2000))],
                        sessionId: sessionId
                    ))
                }
            }

        case "agent_message":
            let text = payload["message"] as? String ?? ""
            if !text.isEmpty {
                let hash = "assistant:\(String(text.prefix(100)))"
                if !seenMessageHashes.contains(hash) {
                    seenMessageHashes.insert(hash)
                    events.append(AgentEvent(
                        time: elapsed,
                        type: .message,
                        payload: ["agent": agentName, "role": "assistant", "content": String(text.prefix(2000))],
                        sessionId: sessionId
                    ))
                }
            }

        case "token_count":
            if let info = payload["info"] as? [String: Any],
               let usage = info["total_token_usage"] as? [String: Any] {
                inputTokens = usage["input_tokens"] as? Int ?? inputTokens
                outputTokens = usage["output_tokens"] as? Int ?? outputTokens
                reasoningTokens = usage["reasoning_tokens"] as? Int ?? reasoningTokens
                events.append(makeContextUpdate(elapsed: elapsed, sessionId: sessionId))
            }

        case "task_complete":
            events.append(AgentEvent(
                time: elapsed,
                type: .agentComplete,
                payload: ["name": agentName],
                sessionId: sessionId
            ))

        default:
            break
        }

        return events
    }

    // MARK: - Response Items

    private func handleResponseItem(_ json: [String: Any], elapsed: Double, sessionId: String?) -> [AgentEvent] {
        let payload = json["payload"] as? [String: Any] ?? [:]
        guard let itemType = payload["type"] as? String else { return [] }

        var events = ensureSpawned(elapsed: elapsed, sessionId: sessionId)

        switch itemType {
        case "function_call":
            let name = payload["name"] as? String ?? "unknown"
            let callId = payload["call_id"] as? String ?? UUID().uuidString
            let argsJson = payload["arguments"] as? String ?? "{}"

            guard !seenCallIds.contains(callId) else { return events }
            seenCallIds.insert(callId)

            let args = summarizeCodexArgs(name: name, argsJson: argsJson)
            pendingToolCalls[callId] = (name: name, args: args)

            events.append(AgentEvent(
                time: elapsed,
                type: .toolCallStart,
                payload: [
                    "id": callId,
                    "agent": agentName,
                    "tool": name,
                    "args": args,
                    "preview": "\(name): \(String(args.prefix(60)))"
                ],
                sessionId: sessionId
            ))

        case "function_call_output":
            let callId = payload["call_id"] as? String ?? ""
            let output = payload["output"] as? String ?? ""

            guard let pending = pendingToolCalls[callId] else { return events }
            pendingToolCalls.removeValue(forKey: callId)

            let resultText = String(output.prefix(500))
            let isError = output.lowercased().contains("error") && output.count < 200

            var toolPayload: [String: Any] = [
                "id": callId,
                "agent": agentName,
                "tool": pending.name,
                "result": String(resultText.prefix(200))
            ]

            if isError {
                toolPayload["isError"] = true
                toolPayload["errorMessage"] = String(resultText.prefix(200))
            }

            events.append(AgentEvent(
                time: elapsed,
                type: .toolCallEnd,
                payload: toolPayload,
                sessionId: sessionId
            ))

        case "reasoning":
            // Codex reasoning is encrypted, but the summary may have content
            if let summaries = payload["summary"] as? [[String: Any]] {
                for summary in summaries {
                    if let text = summary["text"] as? String, !text.isEmpty {
                        let hash = "thinking:\(String(text.prefix(100)))"
                        if !seenMessageHashes.contains(hash) {
                            seenMessageHashes.insert(hash)
                            events.append(AgentEvent(
                                time: elapsed,
                                type: .message,
                                payload: ["agent": agentName, "role": "thinking", "content": String(text.prefix(2000))],
                                sessionId: sessionId
                            ))
                        }
                    }
                }
            }

        default:
            // Skip message response_items — we get those from event_msg already
            break
        }

        return events
    }

    // MARK: - Response Completed

    private func handleResponseCompleted(_ json: [String: Any], elapsed: Double, sessionId: String?) -> [AgentEvent] {
        let payload = json["payload"] as? [String: Any] ?? [:]
        if let response = payload["response"] as? [String: Any],
           let usage = response["usage"] as? [String: Any] {
            inputTokens = usage["input_tokens"] as? Int ?? inputTokens
            outputTokens = usage["output_tokens"] as? Int ?? outputTokens
            reasoningTokens = usage["reasoning_tokens"] as? Int ?? reasoningTokens
            return [makeContextUpdate(elapsed: elapsed, sessionId: sessionId)]
        }
        return []
    }

    // MARK: - Helpers

    private func ensureSpawned(elapsed: Double, sessionId: String?) -> [AgentEvent] {
        if !mainAgentSpawned {
            mainAgentSpawned = true
            return [AgentEvent(
                time: elapsed,
                type: .agentSpawn,
                payload: ["name": agentName, "isMain": true],
                sessionId: sessionId
            )]
        }
        return []
    }

    private func summarizeCodexArgs(name: String, argsJson: String) -> String {
        guard let data = argsJson.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(argsJson.prefix(100))
        }

        switch name {
        case "exec_command", "shell":
            let cmd = args["cmd"] as? String ?? args["command"] as? String ?? ""
            return String(cmd.prefix(120))
        case "read_file":
            return args["path"] as? String ?? args["file_path"] as? String ?? ""
        case "write_file":
            let path = args["path"] as? String ?? args["file_path"] as? String ?? ""
            return path
        case "edit_file":
            return args["path"] as? String ?? args["file_path"] as? String ?? ""
        case "search":
            let pattern = args["pattern"] as? String ?? args["query"] as? String ?? ""
            let path = args["path"] as? String ?? ""
            return "'\(pattern)' in \(path)"
        case "list_directory":
            return args["path"] as? String ?? "."
        default:
            if let first = args.first {
                return "\(first.key): \(String(describing: first.value).prefix(80))"
            }
            return ""
        }
    }

    private func makeContextUpdate(elapsed: Double, sessionId: String?) -> AgentEvent {
        AgentEvent(
            time: elapsed,
            type: .contextUpdate,
            payload: [
                "agent": agentName,
                "tokens": inputTokens + outputTokens,
                "breakdown": [
                    "systemPrompt": 4000,
                    "userMessages": max(0, inputTokens - 4000),
                    "toolResults": 0,
                    "reasoning": reasoningTokens,
                    "subagentResults": outputTokens - reasoningTokens
                ] as [String: Int]
            ],
            sessionId: sessionId
        )
    }
}
