import Foundation
import SwiftUI

// MARK: - Camera State

struct CameraState {
    var offset: CGPoint = .zero
    var zoom: CGFloat = 1.0
    var velocity: CGPoint = .zero
    var targetZoom: CGFloat = 1.0

    static let minZoom: CGFloat = 0.15
    static let maxZoom: CGFloat = 4.0

    mutating func clampZoom() {
        zoom = min(max(zoom, Self.minZoom), Self.maxZoom)
        targetZoom = min(max(targetZoom, Self.minZoom), Self.maxZoom)
    }

    /// Zoom anchored around a screen point so that world position under cursor stays fixed.
    mutating func zoomAround(screenPoint: CGPoint, viewSize: CGSize, factor: CGFloat) {
        let worldBefore = screenToWorld(screenPoint, viewSize: viewSize)
        targetZoom *= factor
        clampZoom()
        zoom = targetZoom
        let worldAfter = screenToWorld(screenPoint, viewSize: viewSize)
        offset.x += worldAfter.x - worldBefore.x
        offset.y += worldAfter.y - worldBefore.y
    }

    func worldToScreen(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x + offset.x) * zoom + viewSize.width / 2,
            y: (point.y + offset.y) * zoom + viewSize.height / 2
        )
    }

    func screenToWorld(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - viewSize.width / 2) / zoom - offset.x,
            y: (point.y - viewSize.height / 2) / zoom - offset.y
        )
    }
}

// MARK: - Simulation State

@Observable
final class SimulationState {
    var agents: [String: AgentModel] = [:]
    var toolCalls: [String: ToolCallModel] = [:]
    var edges: [String: EdgeModel] = [:]
    var particles: [ParticleModel] = []
    var discoveries: [DiscoveryModel] = []
    var depthParticles: [DepthParticle] = []
    var spawnEffects: [SpawnEffect] = []
    var completeEffects: [CompleteEffect] = []
    var clusters: [String: SessionCluster] = [:]

    /// Full message history per agent (not faded like the visual bubbles)
    var messageHistory: [String: [MessageBubble]] = [:]

    /// Current model name detected from transcripts
    var currentModel: String?

    /// Active plan content (from plan mode)
    var activePlan: PlanState?

    /// Task list
    var tasks: [TaskItem] = []

    var camera = CameraState()
    var time: Double = 0
    var deltaTime: Double = 0
    var isPlaying: Bool = true
    var playbackSpeed: Double = 1.0

    var selectedAgentId: String?
    var hoveredAgentId: String?
    var selectedToolCallId: String?

    var theme: Theme = .holograph

    /// Returns the renderer for the current theme. No caching to avoid thread races.
    var renderer: ThemeRenderer { theme.style.renderer }
    var detailLevel: Double = 0.6
    var showGrid: Bool = false
    var showStats: Bool = false
    var showCost: Bool = false
    var showTimeline: Bool = false
    var showTranscript: Bool = false

    /// Check if current detail level meets a threshold.
    /// Thresholds: 0.0 Minimal, 0.2 Low, 0.4 Medium, 0.6 High, 0.8 Full
    func detail(_ threshold: Double) -> Bool { detailLevel >= threshold }

    var totalTokens: Int {
        agents.values.reduce(0) { $0 + $1.tokensUsed }
    }

    var activeAgentCount: Int {
        agents.values.filter { $0.isActive }.count
    }

    var selectedAgent: AgentModel? {
        guard let id = selectedAgentId else { return nil }
        return agents[id]
    }

    // Sorted agents for consistent rendering
    var sortedAgents: [AgentModel] {
        agents.values.sorted { a, b in
            if a.isMain != b.isMain { return a.isMain }
            return a.spawnTime < b.spawnTime
        }
    }

    var sortedEdges: [EdgeModel] {
        edges.values.sorted { $0.id < $1.id }
    }

    var sortedToolCalls: [ToolCallModel] {
        toolCalls.values.sorted { $0.createdAt < $1.createdAt }
    }

    init() {
        generateDepthParticles()
    }

    func generateDepthParticles() {
        depthParticles = (0..<80).map { _ in
            DepthParticle(
                position: CGPoint(
                    x: CGFloat.random(in: -2000...2000),
                    y: CGFloat.random(in: -2000...2000)
                ),
                brightness: Double.random(in: 0.1...0.7),
                depth: Double.random(in: 0.2...1.0),
                size: CGFloat.random(in: 1...3)
            )
        }
    }
}

// MARK: - Playback Speed

enum PlaybackSpeed: Double, CaseIterable {
    case half = 0.5
    case normal = 1.0
    case double = 2.0
    case quad = 4.0

    var label: String {
        switch self {
        case .half: return "0.5x"
        case .normal: return "1x"
        case .double: return "2x"
        case .quad: return "4x"
        }
    }
}
