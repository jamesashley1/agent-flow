import Foundation

// MARK: - Force-Directed Graph Layout

/// A force simulation inspired by D3-force.
/// Applies charge (repulsion), center, collision, link, and cluster forces.
struct ForceSimulation {
    var chargeStrength: Double = -1200
    var centerStrength: Double = 0.008
    var clusterStrength: Double = 0.06
    var clusterRepulsion: Double = -20000
    var collisionRadius: Double = 60
    var linkDistance: Double = 350
    var linkStrength: Double = 0.2
    var damping: Double = 0.82
    var ticksPerFrame: Int = 8

    struct Link {
        var sourceId: String
        var targetId: String
    }

    /// Run one frame of simulation (multiple ticks)
    mutating func tick(
        agents: inout [String: AgentModel],
        links: [Link],
        clusters: inout [String: SessionCluster],
        dt: Double
    ) {
        let ids = Array(agents.keys)
        guard !ids.isEmpty else { return }

        // Update cluster centers based on current agent positions
        updateClusterCenters(agents: agents, clusters: &clusters)

        // Arrange cluster centers so they don't overlap
        if clusters.count > 1 {
            applyClusterRepulsion(clusters: &clusters)
        }

        for _ in 0..<ticksPerFrame {
            // Charge force (repulsion between all pairs)
            applyChargeForce(agents: &agents, ids: ids)

            // Cluster force (pull agents toward their cluster center)
            if clusters.count > 1 {
                applyClusterForce(agents: &agents, ids: ids, clusters: clusters)
            } else {
                // Single session: pull toward origin
                applyCenterForce(agents: &agents, ids: ids)
            }

            // Collision force (prevent overlap)
            applyCollisionForce(agents: &agents, ids: ids)

            // Link force (attract connected agents)
            applyLinkForce(agents: &agents, links: links)

            // Integrate velocity -> position
            integrate(agents: &agents, ids: ids, dt: dt / Double(ticksPerFrame))
        }
    }

    // MARK: - Cluster Management

    private func updateClusterCenters(agents: [String: AgentModel], clusters: inout [String: SessionCluster]) {
        // Compute centroid of each cluster's agents
        var sums: [String: (x: CGFloat, y: CGFloat, count: Int)] = [:]

        for agent in agents.values {
            guard let sid = agent.sessionId else { continue }
            var entry = sums[sid] ?? (x: 0, y: 0, count: 0)
            entry.x += agent.position.x
            entry.y += agent.position.y
            entry.count += 1
            sums[sid] = entry
        }

        for (sid, sum) in sums {
            guard sum.count > 0 else { continue }
            let centroid = CGPoint(x: sum.x / CGFloat(sum.count), y: sum.y / CGFloat(sum.count))
            // Smooth update - don't snap
            if clusters[sid] != nil {
                clusters[sid]!.center.x += (centroid.x - clusters[sid]!.center.x) * 0.1
                clusters[sid]!.center.y += (centroid.y - clusters[sid]!.center.y) * 0.1
                clusters[sid]!.agentCount = sum.count
            }
        }
    }

    private func applyClusterRepulsion(clusters: inout [String: SessionCluster]) {
        let ids = Array(clusters.keys)
        guard ids.count > 1 else { return }

        let minDist: CGFloat = 600 // minimum distance between cluster centers

        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                guard var a = clusters[ids[i]], var b = clusters[ids[j]] else { continue }

                let dx = b.center.x - a.center.x
                let dy = b.center.y - a.center.y
                let distSq = max(dx * dx + dy * dy, 100)
                let dist = sqrt(distSq)

                // Strong repulsion when clusters are too close
                if dist < minDist {
                    let force = (minDist - dist) / dist * 0.05
                    let fx = dx * force
                    let fy = dy * force
                    a.center.x -= fx
                    a.center.y -= fy
                    b.center.x += fx
                    b.center.y += fy
                }

                // Gentle repulsion at distance
                let repulsionForce = clusterRepulsion / distSq
                let rfx = (dx / dist) * repulsionForce
                let rfy = (dy / dist) * repulsionForce
                a.center.x += rfx * 0.01
                a.center.y += rfy * 0.01
                b.center.x -= rfx * 0.01
                b.center.y -= rfy * 0.01

                clusters[ids[i]] = a
                clusters[ids[j]] = b
            }
        }
    }

    // MARK: - Forces

    private func applyChargeForce(agents: inout [String: AgentModel], ids: [String]) {
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                guard var a = agents[ids[i]], var b = agents[ids[j]] else { continue }
                if a.isPinned && b.isPinned { continue }

                // Weaker repulsion between agents in different sessions
                let sameSession = a.sessionId != nil && a.sessionId == b.sessionId
                let strength = sameSession ? chargeStrength : chargeStrength * 0.3

                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let distSq = max(dx * dx + dy * dy, 100)
                let dist = sqrt(distSq)
                let force = strength / distSq
                let fx = (dx / dist) * force
                let fy = (dy / dist) * force

                if !a.isPinned {
                    a.velocity.x -= fx
                    a.velocity.y -= fy
                }
                if !b.isPinned {
                    b.velocity.x += fx
                    b.velocity.y += fy
                }

                agents[ids[i]] = a
                agents[ids[j]] = b
            }
        }
    }

    private func applyCenterForce(agents: inout [String: AgentModel], ids: [String]) {
        for id in ids {
            guard var agent = agents[id], !agent.isPinned else { continue }
            agent.velocity.x -= agent.position.x * centerStrength
            agent.velocity.y -= agent.position.y * centerStrength
            agents[id] = agent
        }
    }

    private func applyClusterForce(agents: inout [String: AgentModel], ids: [String], clusters: [String: SessionCluster]) {
        for id in ids {
            guard var agent = agents[id], !agent.isPinned,
                  let sessionId = agent.sessionId,
                  let cluster = clusters[sessionId] else { continue }

            // Pull toward cluster center
            let dx = cluster.center.x - agent.position.x
            let dy = cluster.center.y - agent.position.y
            agent.velocity.x += dx * clusterStrength
            agent.velocity.y += dy * clusterStrength

            agents[id] = agent
        }
    }

    private func applyCollisionForce(agents: inout [String: AgentModel], ids: [String]) {
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                guard var a = agents[ids[i]], var b = agents[ids[j]] else { continue }
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let dist = max(sqrt(dx * dx + dy * dy), 1)
                let minDist = a.radius + b.radius + 80

                if dist < minDist {
                    let overlap = (minDist - dist) / dist * 0.5
                    let fx = dx * overlap
                    let fy = dy * overlap

                    if !a.isPinned {
                        a.position.x -= fx
                        a.position.y -= fy
                    }
                    if !b.isPinned {
                        b.position.x += fx
                        b.position.y += fy
                    }

                    agents[ids[i]] = a
                    agents[ids[j]] = b
                }
            }
        }
    }

    private func applyLinkForce(agents: inout [String: AgentModel], links: [Link]) {
        for link in links {
            guard var source = agents[link.sourceId],
                  var target = agents[link.targetId] else { continue }

            let dx = target.position.x - source.position.x
            let dy = target.position.y - source.position.y
            let dist = max(sqrt(dx * dx + dy * dy), 1)
            let force = (dist - linkDistance) * linkStrength / dist

            let fx = dx * force
            let fy = dy * force

            if !source.isPinned {
                source.velocity.x += fx * 0.5
                source.velocity.y += fy * 0.5
            }
            if !target.isPinned {
                target.velocity.x -= fx * 0.5
                target.velocity.y -= fy * 0.5
            }

            agents[link.sourceId] = source
            agents[link.targetId] = target
        }
    }

    private func integrate(agents: inout [String: AgentModel], ids: [String], dt: Double) {
        for id in ids {
            guard var agent = agents[id], !agent.isPinned else { continue }
            agent.velocity.x *= damping
            agent.velocity.y *= damping
            agent.position.x += agent.velocity.x * dt
            agent.position.y += agent.velocity.y * dt
            agents[id] = agent
        }
    }
}
