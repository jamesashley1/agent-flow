//
//  AgentFlowCompanionApp.swift
//
//  macOS menu-bar companion for Agent Flow.
//  • Launches `pnpm run dev` from the agent-flow repo
//  • Streams its stdout into an in-memory log viewer
//  • Opens http://localhost:3000 in your browser
//  • Shows running status in the menu bar
//
//  Build:  open in Xcode as a macOS App target, or
//          `swift build` after wrapping in a Package.swift.
//

import SwiftUI
import AppKit

// ─── App entry ──────────────────────────────────────────────────────────────

@main
struct AgentFlowCompanionApp: App {
    @StateObject private var controller = DevServerController()

    var body: some Scene {
        MenuBarExtra("Agent Flow", systemImage: controller.isRunning ? "waveform" : "waveform.slash") {
            MenuBarView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}

// ─── Menu content ───────────────────────────────────────────────────────────

struct MenuBarView: View {
    @ObservedObject var controller: DevServerController
    @AppStorage("repoPath") private var repoPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(controller.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(controller.statusText)
                    .font(.headline)
            }

            if repoPath.isEmpty {
                Button("Choose agent-flow repo…") { chooseRepo() }
            } else {
                Text(repoPath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Button(controller.isRunning ? "Stop" : "Start") {
                        controller.isRunning ? controller.stop() : controller.start(repo: repoPath)
                    }
                    Button("Open") { openBrowser() }.disabled(!controller.isRunning)
                    Button("Change…") { chooseRepo() }
                }
            }

            Divider()
            ScrollView {
                Text(controller.recentLog)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 360, height: 140)

            Divider()
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 380)
    }

    func chooseRepo() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
        }
    }

    func openBrowser() {
        NSWorkspace.shared.open(URL(string: "http://localhost:3000")!)
    }
}

// ─── Dev-server process controller ──────────────────────────────────────────

final class DevServerController: ObservableObject {
    @Published var isRunning = false
    @Published var statusText = "Stopped"
    @Published var recentLog = ""

    private var process: Process?
    private var logBuffer: [String] = []
    private let maxLines = 200

    func start(repo: String) {
        guard !isRunning else { return }
        statusText = "Starting…"

        let task = Process()
        // Use login shell so user PATH (pnpm, node) is resolved.
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-l", "-c", "cd '\(repo)' && pnpm run dev"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self.append(log: s) }
        }

        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.statusText = "Stopped"
            }
        }

        do {
            try task.run()
            process = task
            isRunning = true
            statusText = "Running — localhost:3000"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        statusText = "Stopped"
    }

    private func append(log chunk: String) {
        for line in chunk.split(separator: "\n", omittingEmptySubsequences: false) {
            logBuffer.append(String(line))
        }
        if logBuffer.count > maxLines {
            logBuffer.removeFirst(logBuffer.count - maxLines)
        }
        recentLog = logBuffer.suffix(40).joined(separator: "\n")
    }
}
