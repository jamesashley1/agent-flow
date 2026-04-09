import Foundation

// MARK: - Event Source

enum EventSource: String, CaseIterable {
    case cli = "CLI"
    case xcode = "Xcode"
    case codex = "Codex"
}

// MARK: - Watched Session

private enum SessionParser {
    case claude(TranscriptParser)
    case codex(CodexTranscriptParser)

    func processLine(_ line: String, sessionId: String?) -> [AgentEvent] {
        switch self {
        case .claude(let p): return p.processLine(line, sessionId: sessionId)
        case .codex(let p): return p.processLine(line, sessionId: sessionId)
        }
    }
}

private struct WatchedSession {
    let filePath: String
    let sessionId: String
    let source: EventSource
    let label: String
    var fileHandle: FileHandle?
    var fileOffset: UInt64 = 0
    var parser: SessionParser
}

// MARK: - Session Watcher

/// Watches Claude Code JSONL transcript files for real-time events.
/// All session state is accessed exclusively on the main thread to avoid races.
@Observable
final class SessionWatcher {
    var isConnected: Bool = false
    var activeSessions: Int = 0
    var sessionSources: [String: EventSource] = [:]

    private var sessions: [String: WatchedSession] = [:]
    private var pollTimer: DispatchSourceTimer?
    private var onEvent: ((AgentEvent, String, String, EventSource) -> Void)?

    private let searchDirs: [(String, EventSource)]
    private let recencyWindow: TimeInterval = 600

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.searchDirs = [
            ("\(home)/.claude/projects", .cli),
            ("\(home)/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/projects", .xcode),
            ("\(home)/.codex/sessions", .codex),
            ("\(home)/Library/Developer/Xcode/CodingAssistant/codex/sessions", .codex)
        ]
    }

    func start(onEvent: @escaping (AgentEvent, String, String, EventSource) -> Void) {
        self.onEvent = onEvent
        refreshSessions()

        // Timer fires on main queue to avoid thread races
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.resume()
        self.pollTimer = timer
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        for (_, session) in sessions {
            session.fileHandle?.closeFile()
        }
        sessions.removeAll()
        isConnected = false
    }

    // MARK: - Polling (main thread)

    private func poll() {
        // Read new data from all watched sessions
        for id in sessions.keys {
            readNewData(sessionId: id)
        }

        // Refresh session list every ~3s
        if Int(Date().timeIntervalSince1970) % 3 == 0 {
            refreshSessions()
        }
    }

    // MARK: - Session Discovery

    private func refreshSessions() {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-recencyWindow)
        var foundFiles: [(path: String, sessionId: String, date: Date, source: EventSource, label: String)] = []

        for (dir, source) in searchDirs {
            guard fm.fileExists(atPath: dir) else { continue }

            if source == .codex {
                // Codex uses nested date dirs: sessions/YYYY/MM/DD/*.jsonl
                findJsonlFiles(in: dir, source: source, cutoff: cutoff, fm: fm, into: &foundFiles)
            } else {
                // Claude Code uses: projects/<encoded-path>/*.jsonl
                guard let projectDirs = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                for projectDir in projectDirs {
                    let projectPath = "\(dir)/\(projectDir)"
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }

                    guard let files = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }
                    for file in files where file.hasSuffix(".jsonl") {
                        let filePath = "\(projectPath)/\(file)"
                        guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                              let modDate = attrs[.modificationDate] as? Date,
                              modDate > cutoff else { continue }

                        let sessionId = String(file.dropLast(6))
                        let label = deriveLabel(projectDir: projectDir, source: source)
                        foundFiles.append((filePath, sessionId, modDate, source, label))
                    }
                }
            }
        }

        let maxSessions = 8
        let recentFiles = foundFiles.sorted { $0.date > $1.date }.prefix(maxSessions)

        for file in recentFiles {
            if sessions[file.sessionId] == nil {
                startTailing(filePath: file.path, sessionId: file.sessionId, source: file.source, label: file.label)
            }
        }

        let recentIds = Set(recentFiles.map(\.sessionId))
        for id in sessions.keys where !recentIds.contains(id) {
            sessions[id]?.fileHandle?.closeFile()
            sessions.removeValue(forKey: id)
        }

        activeSessions = sessions.count
        isConnected = !sessions.isEmpty
    }

    /// Recursively find .jsonl files in a directory tree (for Codex's date-based layout)
    private func findJsonlFiles(
        in dir: String, source: EventSource, cutoff: Date,
        fm: FileManager, into results: inout [(path: String, sessionId: String, date: Date, source: EventSource, label: String)],
        depth: Int = 0
    ) {
        guard depth < 5 else { return }
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }

        for entry in entries {
            let fullPath = "\(dir)/\(entry)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                findJsonlFiles(in: fullPath, source: source, cutoff: cutoff, fm: fm, into: &results, depth: depth + 1)
            } else if entry.hasSuffix(".jsonl") {
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date,
                      modDate > cutoff else { continue }

                let sessionId = String(entry.dropLast(6))
                // Initial label from filename — will be updated with project name after parsing
                let label = "Codex"
                results.append((fullPath, sessionId, modDate, source, label))
            }
        }
    }

    private func deriveLabel(projectDir: String, source: EventSource) -> String {
        // projectDir is like "-Users-jamesashley1-source-repos-DrawThis"
        // Decode: split on path separators encoded as "-", take the last path component
        let decoded = projectDir
            .replacingOccurrences(of: "--", with: "\u{0}") // preserve double-dash
            .split(separator: "-")
            .joined(separator: "/")
            .replacingOccurrences(of: "\u{0}", with: "-")
        let projectName = (decoded as NSString).lastPathComponent
        let name = projectName.isEmpty ? projectDir : projectName
        switch source {
        case .xcode: return "Xcode Claude: \(name)"
        case .codex: return "Codex: \(name)"
        case .cli: return "Claude CLI: \(name)"
        }
    }

    // MARK: - File Tailing

    private func startTailing(filePath: String, sessionId: String, source: EventSource, label: String) {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { return }

        let parser: SessionParser = source == .codex
            ? .codex(CodexTranscriptParser())
            : .claude(TranscriptParser())

        var session = WatchedSession(
            filePath: filePath, sessionId: sessionId, source: source, label: label, fileHandle: handle, parser: parser
        )

        let existingData = handle.readDataToEndOfFile()
        session.fileOffset = handle.offsetInFile

        sessions[sessionId] = session
        sessionSources[sessionId] = source

        processData(existingData, sessionId: sessionId)
    }

    private func readNewData(sessionId: String) {
        guard let session = sessions[sessionId],
              let handle = session.fileHandle else { return }

        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: session.filePath),
              let fileSize = attrs[.size] as? UInt64,
              fileSize > session.fileOffset else { return }

        handle.seek(toFileOffset: session.fileOffset)
        let newData = handle.readDataToEndOfFile()
        sessions[sessionId]?.fileOffset = handle.offsetInFile

        if !newData.isEmpty {
            processData(newData, sessionId: sessionId)
        }
    }

    // MARK: - Data Processing

    private func processData(_ data: Data, sessionId: String) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        guard var session = sessions[sessionId] else { return }

        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        // Pre-scan: extract project name from Codex session_meta before emitting events,
        // so the first agent_spawn gets the correct label
        if case .codex(let parser) = session.parser, parser.projectName == nil {
            for line in lines {
                if line.contains("\"session_meta\""), let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let payload = json["payload"] as? [String: Any],
                   let cwd = payload["cwd"] as? String {
                    let name = (cwd as NSString).lastPathComponent
                    if !name.isEmpty {
                        let prefix = session.source == .xcode ? "Xcode Codex" : "Codex"
                        let newLabel = "\(prefix): \(name)"
                        session = WatchedSession(
                            filePath: session.filePath, sessionId: session.sessionId,
                            source: session.source, label: newLabel,
                            fileHandle: session.fileHandle, fileOffset: session.fileOffset,
                            parser: session.parser
                        )
                        sessions[sessionId] = session
                    }
                    break
                }
            }
        }

        for line in lines {
            let events = session.parser.processLine(line, sessionId: sessionId)
            for event in events {
                onEvent?(event, sessionId, session.label, session.source)
            }
        }
    }
}
