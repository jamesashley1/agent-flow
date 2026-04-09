import SwiftUI

// MARK: - App Mode

enum AppMode: String, CaseIterable {
    case live = "Live"
    case demo = "Demo"
}

// MARK: - Content View

struct ContentView: View {
    @State private var state = SimulationState()
    @State private var engine: SimulationEngine?
    @State private var sessionWatcher: SessionWatcher?
    @State private var eventBridge: EventBridge?
    @State private var appMode: AppMode = .live
    @State private var hasReceivedEvents = false
    @State private var gestureMonitor = GestureMonitor()
    @State private var showPlanTaskPanel = false
    @State private var showMessageFeed = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                state.theme.voidColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TopBar(state: state, sessionWatcher: sessionWatcher)

                    ZStack(alignment: .leading) {
                        if let engine {
                            VisualizationCanvas(
                                state: state,
                                engine: engine,
                                viewSize: CGSize(
                                    width: geo.size.width,
                                    height: geo.size.height - 90
                                )
                            )
                        }

                        // Agent detail panel (left side)
                        AgentDetailOverlay(state: state)

                        // Plan & Task panel (right side)
                        if showPlanTaskPanel {
                            HStack {
                                Spacer()
                                PlanTaskPanel(
                                    plan: state.activePlan,
                                    tasks: state.tasks,
                                    theme: state.theme,
                                    onClose: { showPlanTaskPanel = false }
                                )
                                .padding(16)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                            .animation(.easeInOut(duration: 0.2), value: showPlanTaskPanel)
                        }

                        // Connection status overlay (when no events yet in live mode)
                        if appMode == .live && !hasReceivedEvents {
                            connectionOverlay
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topLeading) {
                        if showMessageFeed {
                            MessageFeedPanel(state: state) { agentId in
                                state.selectedAgentId = agentId
                            }
                            .padding(.leading, 12)
                            .padding(.top, 8)
                        }
                    }

                    if let engine {
                        ControlBar(state: state, engine: engine, showPlanTaskPanel: $showPlanTaskPanel)
                    }
                }

                // Mode switcher (top right)
                VStack {
                    HStack {
                        Spacer()
                        modeSwitcher
                            .padding(.trailing, 16)
                            .padding(.top, 44)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            setupSimulation()
            gestureMonitor.onZoom = { delta in
                let factor: CGFloat = 1.0 + delta
                state.camera.targetZoom *= factor
                state.camera.zoom *= factor
                state.camera.clampZoom()
            }
            gestureMonitor.onPan = { dx, dy in
                state.camera.offset.x += dx / state.camera.zoom
                state.camera.offset.y += dy / state.camera.zoom
            }
            gestureMonitor.start()
        }
        .onDisappear {
            sessionWatcher?.stop()
            gestureMonitor.stop()
        }
        .focusable()
        .onKeyPress(.space) { state.isPlaying.toggle(); return .handled }
        .onKeyPress("f") { engine?.zoomToFit(viewSize: .init(width: 800, height: 600)); return .handled }
        .onKeyPress("g") { state.showGrid.toggle(); return .handled }
        .onKeyPress("s") { state.showStats.toggle(); return .handled }
        .onKeyPress(.escape) { state.selectedAgentId = nil; state.selectedToolCallId = nil; return .handled }
        .onKeyPress("1") { state.playbackSpeed = 0.5; return .handled }
        .onKeyPress("2") { state.playbackSpeed = 1.0; return .handled }
        .onKeyPress("3") { state.playbackSpeed = 2.0; return .handled }
        .onKeyPress("4") { state.playbackSpeed = 4.0; return .handled }
        .onKeyPress("d") { state.detailLevel = max(0, state.detailLevel - 0.2); return .handled }
        .onKeyPress("D") { state.detailLevel = min(1, state.detailLevel + 0.2); return .handled }
        .onKeyPress("p") { showPlanTaskPanel.toggle(); return .handled }
        .onKeyPress("m") { showMessageFeed.toggle(); return .handled }
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(AppMode.allCases, id: \.rawValue) { mode in
                Button(action: { switchMode(to: mode) }) {
                    Text(mode.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(appMode == mode
                            ? state.theme.uiAccent
                            : Color.white.opacity(0.4))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(appMode == mode
                                    ? state.theme.uiAccent.opacity(0.15)
                                    : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Connection Overlay

    private var connectionOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.small)
                .tint(state.theme.uiAccent)

            Text("Watching for Claude Code sessions...")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            Text("~/.claude/projects/")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))

            if let watcher = sessionWatcher, watcher.activeSessions > 0 {
                Text("Found \(watcher.activeSessions) recent session(s)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(state.theme.success.opacity(0.6))
            }

            Text("Start a Claude Code session to see the visualization,\nor switch to Demo mode.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(state.theme.agentFillTop.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(state.theme.uiAccent.opacity(0.1), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Setup

    private func setupSimulation() {
        let eng = SimulationEngine(state: state)
        self.engine = eng
        self.eventBridge = EventBridge(engine: eng)

        if appMode == .live {
            startLiveMode()
        } else {
            startDemoMode(engine: eng)
        }
    }

    private func switchMode(to mode: AppMode) {
        guard mode != appMode else { return }
        appMode = mode
        hasReceivedEvents = false

        // Reset state
        sessionWatcher?.stop()
        sessionWatcher = nil
        state.agents.removeAll()
        state.toolCalls.removeAll()
        state.edges.removeAll()
        state.particles.removeAll()
        state.discoveries.removeAll()
        state.spawnEffects.removeAll()
        state.completeEffects.removeAll()
        state.clusters.removeAll()
        state.messageHistory.removeAll()
        state.activePlan = nil
        state.tasks.removeAll()
        state.currentModel = nil
        state.selectedAgentId = nil
        state.selectedToolCallId = nil

        guard let engine else { return }
        self.eventBridge = EventBridge(engine: engine)

        if mode == .live {
            startLiveMode()
        } else {
            startDemoMode(engine: engine)
        }
    }

    private func startLiveMode() {
        let watcher = SessionWatcher()
        self.sessionWatcher = watcher

        watcher.start { [eventBridge] event, sessionId, sessionLabel, source in
            hasReceivedEvents = true
            eventBridge?.process(event, sessionId: sessionId, sessionLabel: sessionLabel, source: source)
        }
    }

    private func startDemoMode(engine: SimulationEngine) {
        hasReceivedEvents = true
        let events = DemoScenario.generate()

        for event in events {
            DispatchQueue.main.asyncAfter(deadline: .now() + event.delay) {
                event.action(engine)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            engine.zoomToFit(viewSize: .init(width: 800, height: 600))
        }
    }
}
