import Foundation
import SwiftUI

// MARK: - Simulation Engine

/// Manages the simulation loop: processes events, runs physics, updates animations.
@Observable
final class SimulationEngine {
    var state: SimulationState
    var forceSimulation = ForceSimulation()
    private var lastTime: Double?

    init(state: SimulationState) {
        self.state = state
    }

    // MARK: - Frame Update

    func update(currentTime: Double) {
        guard state.isPlaying else {
            lastTime = currentTime
            return
        }

        let dt: Double
        if let last = lastTime {
            dt = min(currentTime - last, 0.1) * state.playbackSpeed
        } else {
            dt = 1.0 / 60.0
        }
        lastTime = currentTime

        state.time += dt
        state.deltaTime = dt

        // Run force simulation
        let links = state.edges.values
            .filter { $0.type == .parentChild }
            .map { ForceSimulation.Link(sourceId: $0.sourceId, targetId: $0.targetId) }
        forceSimulation.tick(agents: &state.agents, links: links, clusters: &state.clusters, dt: dt)

        // Update all entities
        updateAgents(dt: dt)
        updateToolCalls(dt: dt)
        updateEdges(dt: dt)
        updateParticles(dt: dt)
        updateDiscoveries(dt: dt)
        updateEffects(dt: dt)
        updateMessages(dt: dt)
        updateCamera(dt: dt)
        updateClusters(dt: dt)
    }

    // MARK: - Agent Updates

    private func updateAgents(dt: Double) {
        let agentIds = Array(state.agents.keys)
        for id in agentIds {
            guard var agent = state.agents[id] else { continue }

            if agent.opacity < 1.0 { agent.opacity = min(agent.opacity + dt * 3.0, 1.0) }
            if agent.scale < 1.0 { agent.scale = min(agent.scale + dt * 4.0, 1.0) }
            if agent.state == .thinking || agent.state == .idle { agent.breathPhase += dt * 2.0 }
            if agent.state == .thinking { agent.scanlineOffset += dt * 30.0 }

            if agent.state == .complete, let completeTime = agent.completeTime {
                if state.time - completeTime > 3.0 {
                    agent.opacity = max(agent.opacity - dt * 0.5, 0.1)
                }
            }

            state.agents[id] = agent
        }
    }

    // MARK: - Tool Call Updates

    private func updateToolCalls(dt: Double) {
        // Snapshot keys to avoid mutating during iteration
        let toolIds = Array(state.toolCalls.keys)
        for id in toolIds {
            guard var tool = state.toolCalls[id] else { continue }

            if tool.opacity < 1.0 { tool.opacity = min(tool.opacity + dt * 4.0, 1.0) }
            if tool.state == .running { tool.pulsePhase += dt * 3.0 }

            // Position near parent agent
            if let agent = state.agents[tool.agentId] {
                let angle = Double(id.hashValue % 628) / 100.0
                let dist: CGFloat = agent.radius + 120
                let targetX = agent.position.x + cos(angle) * dist
                let targetY = agent.position.y + sin(angle) * dist
                tool.position.x += (targetX - tool.position.x) * min(dt * 5, 1)
                tool.position.y += (targetY - tool.position.y) * min(dt * 5, 1)
            }

            if tool.state == .complete || tool.state == .error {
                if let completedAt = tool.completedAt, state.time - completedAt > 2.0 {
                    tool.opacity = max(tool.opacity - dt * 1.0, 0)
                }
            }

            state.toolCalls[id] = tool
        }

        // Remove fully faded tool calls
        let fadeIds = toolIds.filter { state.toolCalls[$0]?.opacity ?? 0 <= 0.01 }
        for id in fadeIds { state.toolCalls.removeValue(forKey: id) }
    }

    // MARK: - Edge Updates

    private func updateEdges(dt: Double) {
        let edgeIds = Array(state.edges.keys)
        for id in edgeIds {
            guard var edge = state.edges[id] else { continue }
            let targetOpacity: Double = edge.isActive ? 0.8 : 0.3
            edge.opacity += (targetOpacity - edge.opacity) * min(dt * 3, 1)
            state.edges[id] = edge
        }
    }

    // MARK: - Particle Updates

    private func updateParticles(dt: Double) {
        for i in state.particles.indices.reversed() {
            state.particles[i].progress += dt * 0.4
            state.particles[i].wobblePhase += dt * 5.0

            if state.particles[i].progress >= 1.0 {
                state.particles.remove(at: i)
            }
        }
    }

    // MARK: - Discovery Updates

    private func updateDiscoveries(dt: Double) {
        for i in state.discoveries.indices {
            // Lerp to target position
            let t = min(dt * 2.0, 1.0)
            state.discoveries[i].position.x += (state.discoveries[i].targetPosition.x - state.discoveries[i].position.x) * t
            state.discoveries[i].position.y += (state.discoveries[i].targetPosition.y - state.discoveries[i].position.y) * t

            // Fade in
            if state.discoveries[i].opacity < 1.0 {
                state.discoveries[i].opacity = min(state.discoveries[i].opacity + dt * 2.0, 1.0)
            }
        }
    }

    // MARK: - Effect Updates

    private func updateEffects(dt: Double) {
        // Spawn effects
        state.spawnEffects.removeAll { state.time - $0.createdAt > $0.duration }

        // Complete effects - update fragment positions
        for i in state.completeEffects.indices {
            for j in state.completeEffects[i].fragments.indices {
                state.completeEffects[i].fragments[j].position.x += state.completeEffects[i].fragments[j].velocity.x * dt
                state.completeEffects[i].fragments[j].position.y += state.completeEffects[i].fragments[j].velocity.y * dt
                state.completeEffects[i].fragments[j].opacity = max(state.completeEffects[i].fragments[j].opacity - dt * 1.5, 0)
            }
        }
        state.completeEffects.removeAll { state.time - $0.createdAt > $0.duration }
    }

    // MARK: - Message Updates

    private func updateMessages(dt: Double) {
        let agentIds = Array(state.agents.keys)
        for id in agentIds {
            guard var agent = state.agents[id] else { continue }
            if agent.messages.count > 1 {
                agent.messages = [agent.messages.last!]
            }
            agent.messages = agent.messages.compactMap { var msg = $0
                let age = state.time - msg.createdAt
                if age < 0.3 { msg.opacity = age / 0.3 }
                else if age > 4.0 { msg.opacity = max(1.0 - (age - 4.0) / 1.0, 0) }
                msg.offsetY = -10 - min(age * 3, 20)
                return msg.opacity > 0 ? msg : nil
            }
            state.agents[id] = agent
        }
    }

    // MARK: - Cluster Updates

    private func updateClusters(dt: Double) {
        let clusterIds = Array(state.clusters.keys)
        for cid in clusterIds {
            guard var cluster = state.clusters[cid] else { continue }

            // Check if all agents in this session are complete
            let sessionAgents = state.agents.values.filter { $0.sessionId == cid }
            let allComplete = !sessionAgents.isEmpty && sessionAgents.allSatisfy { $0.state == .complete }

            if allComplete && cluster.isActive {
                cluster.isActive = false
                cluster.completedTime = state.time
            }

            // Gradually dim inactive clusters
            if !cluster.isActive {
                cluster.dimAmount = min(cluster.dimAmount + dt * 0.3, 0.7)
            } else {
                cluster.dimAmount = max(cluster.dimAmount - dt * 1.0, 0)
            }

            state.clusters[cid] = cluster
        }

        // Apply dimming to agents in completed sessions
        let agentIds = Array(state.agents.keys)
        for aid in agentIds {
            guard var agent = state.agents[aid],
                  let sid = agent.sessionId,
                  let cluster = state.clusters[sid] else { continue }

            if !cluster.isActive && agent.state == .complete {
                // Fade agent down to dimmed level
                let targetOpacity = max(0.15, 1.0 - cluster.dimAmount)
                if agent.opacity > targetOpacity {
                    agent.opacity = max(agent.opacity - dt * 0.5, targetOpacity)
                    state.agents[aid] = agent
                }
            }
        }
    }

    // MARK: - Camera Updates

    private func updateCamera(dt: Double) {
        // Smooth zoom
        state.camera.zoom += (state.camera.targetZoom - state.camera.zoom) * min(dt * 8, 1)

        // Pan inertia
        state.camera.offset.x += state.camera.velocity.x * dt
        state.camera.offset.y += state.camera.velocity.y * dt
        state.camera.velocity.x *= pow(0.94, dt * 60)
        state.camera.velocity.y *= pow(0.94, dt * 60)

        // Stop tiny velocities
        if abs(state.camera.velocity.x) < 0.01 { state.camera.velocity.x = 0 }
        if abs(state.camera.velocity.y) < 0.01 { state.camera.velocity.y = 0 }
    }

    // MARK: - Event Processing

    func spawnAgent(id: String, name: String, parentId: String? = nil, isMain: Bool = false, sessionId: String? = nil, sessionLabel: String? = nil, source: EventSource = .cli) {
        var agent = AgentModel(id: id, name: name, parentId: parentId, sessionId: sessionId)
        agent.isMain = isMain
        agent.radius = isMain ? 32 : 22
        agent.spawnTime = state.time

        // Ensure cluster exists for this session
        if let sessionId, state.clusters[sessionId] == nil {
            let clusterIndex = state.clusters.count
            let totalClusters = max(CGFloat(clusterIndex + 1), 3.0)
            let angle = CGFloat(clusterIndex) * (2.0 * .pi / totalClusters)
            let spread: CGFloat = max(CGFloat(clusterIndex), 1) * 500
            let center = CGPoint(
                x: CoreGraphics.cos(angle) * spread,
                y: CoreGraphics.sin(angle) * spread
            )
            state.clusters[sessionId] = SessionCluster(
                id: sessionId,
                label: sessionLabel ?? "Session \(clusterIndex + 1)",
                source: source,
                center: center
            )
        }
        if let sessionId {
            state.clusters[sessionId]?.lastEventTime = state.time
        }

        // Position near parent, or near cluster center, or at origin
        if let parentId, let parent = state.agents[parentId] {
            let angle: CGFloat = CGFloat.random(in: 0...(2 * .pi))
            let dist: CGFloat = parent.radius + 120
            agent.position = CGPoint(
                x: parent.position.x + CoreGraphics.cos(angle) * dist,
                y: parent.position.y + CoreGraphics.sin(angle) * dist
            )

            // Create edge
            let edgeId = "\(parentId)->\(id)"
            state.edges[edgeId] = EdgeModel(id: edgeId, sourceId: parentId, targetId: id, type: .parentChild)

            // Spawn particle
            state.particles.append(ParticleModel(
                edgeId: edgeId,
                type: .dispatch,
                label: name
            ))
        } else if let sessionId, let cluster = state.clusters[sessionId] {
            agent.position = CGPoint(
                x: cluster.center.x + CGFloat.random(in: -50...50),
                y: cluster.center.y + CGFloat.random(in: -50...50)
            )
        } else {
            agent.position = CGPoint(
                x: CGFloat.random(in: -50...50),
                y: CGFloat.random(in: -50...50)
            )
        }

        state.agents[id] = agent

        // Spawn effect
        var effect = SpawnEffect(position: agent.position, createdAt: state.time)
        for i in 0..<6 {
            let angle = Double(i) * (Double.pi / 3.0) + Double.pi / 6.0
            let length = Double.random(in: 20...50)
            effect.segments.append((angle: angle, length: length))
        }
        state.spawnEffects.append(effect)
    }

    func completeAgent(id: String) {
        state.agents[id]?.state = .complete
        state.agents[id]?.completeTime = state.time

        if let agent = state.agents[id] {
            // Complete effect
            var effect = CompleteEffect(position: agent.position, createdAt: state.time)
            effect.fragments = (0..<12).map { _ in
                let angle = Double.random(in: 0...(2 * .pi))
                let speed = Double.random(in: 30...80)
                return (
                    position: agent.position,
                    velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                    opacity: 1.0
                )
            }
            state.completeEffects.append(effect)

            // Return particle to parent
            if let parentId = agent.parentId,
               let edgeId = state.edges.keys.first(where: { $0.contains(parentId) && $0.contains(id) }) {
                state.particles.append(ParticleModel(
                    edgeId: edgeId,
                    progress: 1.0,
                    type: .return,
                    label: "result"
                ))
                // Return particles go backward
                if let idx = state.particles.indices.last {
                    state.particles[idx].progress = 0.99
                }
            }
        }
    }

    func startToolCall(id: String, agentId: String, name: String, args: String) {
        var tool = ToolCallModel(id: id, agentId: agentId, name: name, args: args)
        tool.createdAt = state.time

        if let agent = state.agents[agentId] {
            tool.position = agent.position
        }

        state.toolCalls[id] = tool
        state.agents[agentId]?.state = .toolCalling
        state.agents[agentId]?.toolCallCount += 1

        // Log tool call to message history
        let toolMsg = MessageBubble(role: .assistant, text: "→ \(name): \(String(args.prefix(120)))", createdAt: state.time)
        state.messageHistory[agentId, default: []].append(toolMsg)
    }

    func completeToolCall(id: String, result: String?, tokenCost: Int = 0, error: String? = nil) {
        state.toolCalls[id]?.state = error != nil ? .error : .complete
        state.toolCalls[id]?.result = result
        state.toolCalls[id]?.tokenCost = tokenCost
        state.toolCalls[id]?.errorMessage = error
        state.toolCalls[id]?.completedAt = state.time

        if let agentId = state.toolCalls[id]?.agentId {
            state.agents[agentId]?.state = .thinking
            state.agents[agentId]?.tokensUsed += tokenCost

            // Log tool result to message history
            let toolName = state.toolCalls[id]?.name ?? "tool"
            let resultText = error ?? result ?? "done"
            let resultMsg = MessageBubble(role: .user, text: "← \(toolName): \(String(resultText.prefix(200)))", createdAt: state.time)
            state.messageHistory[agentId, default: []].append(resultMsg)
        }
    }

    func addMessage(agentId: String, role: MessageBubble.MessageRole, text: String) {
        let bubble = MessageBubble(role: role, text: text, createdAt: state.time)
        state.agents[agentId]?.messages.append(bubble)
        // Keep recent history for the detail panel (cap at 100 per agent)
        state.messageHistory[agentId, default: []].append(bubble)
        if let count = state.messageHistory[agentId]?.count, count > 100 {
            state.messageHistory[agentId]?.removeFirst(count - 100)
        }
    }

    func addDiscovery(agentId: String, type: DiscoveryType, label: String, content: String) {
        guard let agent = state.agents[agentId] else { return }

        // Cap discoveries per agent to prevent clutter
        let existing = state.discoveries.filter { $0.agentId == agentId }
        if existing.count >= 4 {
            // Remove the oldest one
            if let oldestIdx = state.discoveries.firstIndex(where: { $0.agentId == agentId }) {
                state.discoveries.remove(at: oldestIdx)
            }
        }
        let count = state.discoveries.filter { $0.agentId == agentId }.count
        let angle: CGFloat = CGFloat(count) * 1.1 + .pi / 4
        let dist: CGFloat = agent.radius + 180 + CGFloat(count) * 45

        var discovery = DiscoveryModel(agentId: agentId, type: type, label: label, content: content)
        discovery.position = agent.position
        discovery.targetPosition = CGPoint(
            x: agent.position.x + CoreGraphics.cos(angle) * dist,
            y: agent.position.y + CoreGraphics.sin(angle) * dist
        )
        discovery.createdAt = state.time
        state.discoveries.append(discovery)
    }

    func updateContext(agentId: String, breakdown: ContextBreakdown) {
        state.agents[agentId]?.context = breakdown
        state.agents[agentId]?.tokensUsed = breakdown.total
    }

    // MARK: - Camera Controls

    func zoomToFit(viewSize: CGSize) {
        let agents = Array(state.agents.values)
        guard !agents.isEmpty else { return }

        let minX = agents.map(\.position.x).min()! - 100
        let maxX = agents.map(\.position.x).max()! + 100
        let minY = agents.map(\.position.y).min()! - 100
        let maxY = agents.map(\.position.y).max()! + 100

        let width = maxX - minX
        let height = maxY - minY

        let zoomX = viewSize.width / max(width, 1)
        let zoomY = viewSize.height / max(height, 1)

        state.camera.targetZoom = min(zoomX, zoomY) * 0.85
        state.camera.offset = CGPoint(
            x: -(minX + maxX) / 2,
            y: -(minY + maxY) / 2
        )
    }
}
