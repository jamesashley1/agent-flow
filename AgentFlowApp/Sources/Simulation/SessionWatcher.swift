import Foundation

// MARK: - Event Source

enum EventSource: String, CaseIterable {
    case cli = "CLI"
    case xcode = "Xcode"
}

// MARK: - Watched Session

private struct WatchedSession {
    let filePath: String
    let sessionId: String
    let source: EventSource
    let label: String
    var fileHandle: FileHandle?
    var fileOffset: UInt64 = 0
    var parser = TranscriptParser()
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
            ("\(home)/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/projects", .xcode)
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

    private func deriveLabel(projectDir: String, source: EventSource) -> String {
        let parts = projectDir.split(separator: "-").map(String.init)
        let meaningful = parts.last ?? projectDir
        let prefix = source == .xcode ? "Xcode" : "CLI"
        return "\(prefix): \(meaningful)"
    }

    // MARK: - File Tailing

    private func startTailing(filePath: String, sessionId: String, source: EventSource, label: String) {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { return }

        var session = WatchedSession(
            filePath: filePath, sessionId: sessionId, source: source, label: label, fileHandle: handle
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
        guard let session = sessions[sessionId] else { return }

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let events = session.parser.processLine(trimmed, sessionId: sessionId)
            for event in events {
                onEvent?(event, sessionId, session.label, session.source)
            }
        }
    }
}
