import SwiftUI

// MARK: - Visualization Canvas

/// The main rendering view. Uses a display-link timer to drive the simulation
/// separately from SwiftUI's observation system to avoid cascading re-evaluations.
struct VisualizationCanvas: View {
    @Bindable var state: SimulationState
    var engine: SimulationEngine
    var viewSize: CGSize

    @State private var isDraggingAgent: Bool = false
    @State private var draggedAgentId: String?
    @State private var lastDragPosition: CGPoint = .zero
    @State private var isPanning: Bool = false
    @State private var frameCounter: Int = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas(opaque: true, colorMode: .linear, rendersAsynchronously: false) { context, size in
                // Update simulation inside the Canvas closure (not the view body)
                // Canvas closure is NOT tracked by SwiftUI observation
                engine.update(currentTime: timeline.date.timeIntervalSinceReferenceDate)

                BackgroundRenderer.draw(context: &context, size: size, state: state)
                ClusterRenderer.draw(context: &context, size: size, state: state)
                EdgeRenderer.draw(context: &context, size: size, state: state)

                if state.detail(0.6) {
                    DiscoveryRenderer.draw(context: &context, size: size, state: state)
                }
                if state.detail(0.5) {
                    ToolCallRenderer.draw(context: &context, size: size, state: state)
                }
                AgentRenderer.draw(context: &context, size: size, state: state)

                if state.showStats {
                    drawStats(context: &context, size: size)
                }
            }
            .gesture(dragGesture)
            .onTapGesture { location in
                handleTap(at: location, size: viewSize)
            }
            .overlay {
                MagnifyCaptureView { magnification in
                    let factor = 1.0 + magnification
                    state.camera.zoom = min(max(state.camera.zoom * factor, CameraState.minZoom), CameraState.maxZoom)
                    state.camera.targetZoom = state.camera.zoom
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                engine.zoomToFit(viewSize: viewSize)
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in handleDrag(value: value, size: viewSize) }
            .onEnded { value in handleDragEnd(value: value) }
    }

    // MARK: - Input Handling

    private func handleTap(at location: CGPoint, size: CGSize) {
        let worldPos = state.camera.screenToWorld(location, viewSize: size)

        // Use snapshot of keys to avoid issues
        let agentsList = Array(state.agents.values)
        for agent in agentsList {
            let dx = worldPos.x - agent.position.x
            let dy = worldPos.y - agent.position.y
            if dx * dx + dy * dy < agent.radius * agent.radius * 1.5 {
                state.selectedAgentId = (state.selectedAgentId == agent.id) ? nil : agent.id
                state.selectedToolCallId = nil
                return
            }
        }

        let toolsList = Array(state.toolCalls.values)
        for tool in toolsList {
            let dx = worldPos.x - tool.position.x
            let dy = worldPos.y - tool.position.y
            if abs(dx) < 70 && abs(dy) < 25 {
                state.selectedToolCallId = (state.selectedToolCallId == tool.id) ? nil : tool.id
                state.selectedAgentId = nil
                return
            }
        }

        state.selectedAgentId = nil
        state.selectedToolCallId = nil
    }

    private func handleDrag(value: DragGesture.Value, size: CGSize) {
        if !isDraggingAgent && !isPanning {
            let worldPos = state.camera.screenToWorld(value.startLocation, viewSize: size)
            let agentsList = Array(state.agents.values)
            for agent in agentsList {
                let dx = worldPos.x - agent.position.x
                let dy = worldPos.y - agent.position.y
                if dx * dx + dy * dy < agent.radius * agent.radius * 2 {
                    isDraggingAgent = true
                    draggedAgentId = agent.id
                    state.agents[agent.id]?.isPinned = true
                    lastDragPosition = value.location
                    return
                }
            }
            isPanning = true
        }

        if isDraggingAgent, let agentId = draggedAgentId {
            let worldPos = state.camera.screenToWorld(value.location, viewSize: size)
            state.agents[agentId]?.position = worldPos
        } else if isPanning {
            let prev = lastDragPosition == .zero ? value.startLocation : lastDragPosition
            let dx = (value.location.x - prev.x) / state.camera.zoom
            let dy = (value.location.y - prev.y) / state.camera.zoom
            state.camera.offset.x += dx
            state.camera.offset.y += dy
        }

        lastDragPosition = value.location
    }

    private func handleDragEnd(value: DragGesture.Value) {
        if isDraggingAgent, let agentId = draggedAgentId {
            state.agents[agentId]?.isPinned = false
        } else if isPanning {
            state.camera.velocity = CGPoint(
                x: value.velocity.width / state.camera.zoom * 0.01,
                y: value.velocity.height / state.camera.zoom * 0.01
            )
        }

        isDraggingAgent = false
        draggedAgentId = nil
        isPanning = false
        lastDragPosition = .zero
    }

    // MARK: - Stats Overlay

    private func drawStats(context: inout GraphicsContext, size: CGSize) {
        let text = Text("""
        Agents: \(state.agents.count) (\(state.activeAgentCount) active)
        Tool Calls: \(state.toolCalls.count)
        Edges: \(state.edges.count)
        Particles: \(state.particles.count)
        Tokens: \(AgentRenderer.formatTokens(state.totalTokens))
        Zoom: \(String(format: "%.1f", state.camera.zoom))x
        Detail: \(detailLevelName)
        """)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.6))

        let padding: CGFloat = 12
        let bgRect = CGRect(x: size.width - 200, y: padding, width: 188, height: 125)
        context.fill(
            RoundedRectangle(cornerRadius: 6).path(in: bgRect),
            with: .color(Color.black.opacity(0.6))
        )
        context.draw(
            context.resolve(text),
            at: CGPoint(x: bgRect.minX + 10, y: bgRect.minY + 10),
            anchor: .topLeading
        )
    }

    private var detailLevelName: String {
        switch state.detailLevel {
        case ..<0.2: return "Minimal"
        case ..<0.3: return "Low"
        case ..<0.5: return "Med-Low"
        case ..<0.6: return "Medium"
        case ..<0.8: return "High"
        default:     return "Full"
        }
    }
}
