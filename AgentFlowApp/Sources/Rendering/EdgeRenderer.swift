import SwiftUI

// MARK: - Edge Renderer

/// Handles edge/particle culling and iteration, dispatches shape drawing to theme renderer.
struct EdgeRenderer {
    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        state: SimulationState
    ) {
        let camera = state.camera
        let renderer = state.renderer

        for edge in state.sortedEdges {
            guard let source = state.agents[edge.sourceId],
                  let target = state.agents[edge.targetId] else { continue }

            let sourceScreen = camera.worldToScreen(source.position, viewSize: size)
            let targetScreen = camera.worldToScreen(target.position, viewSize: size)

            renderer.drawEdge(context: &context, source: sourceScreen, target: targetScreen, edge: edge, state: state)
        }

        // Particles
        if state.detail(0.4) {
            drawParticles(context: &context, size: size, state: state)
        }
    }

    private static func drawParticles(
        context: inout GraphicsContext,
        size: CGSize,
        state: SimulationState
    ) {
        let camera = state.camera
        let renderer = state.renderer

        for particle in state.particles {
            guard let edge = state.edges[particle.edgeId],
                  let source = state.agents[edge.sourceId],
                  let target = state.agents[edge.targetId] else { continue }

            let sourceScreen = camera.worldToScreen(source.position, viewSize: size)
            let targetScreen = camera.worldToScreen(target.position, viewSize: size)

            let dx = targetScreen.x - sourceScreen.x; let dy = targetScreen.y - sourceScreen.y
            let dist = sqrt(dx * dx + dy * dy)
            let curv = min(dist * 0.2, 60)
            let nx = -dy / max(dist, 1) * curv; let ny = dx / max(dist, 1) * curv

            let progress: Double
            switch particle.type {
            case .return, .toolReturn: progress = 1.0 - particle.progress
            default: progress = particle.progress
            }

            let c1 = CGPoint(x: sourceScreen.x + dx * 0.33 + nx, y: sourceScreen.y + dy * 0.33 + ny)
            let c2 = CGPoint(x: sourceScreen.x + dx * 0.66 + nx, y: sourceScreen.y + dy * 0.66 + ny)
            let pos = bezierPoint(start: sourceScreen, control1: c1, control2: c2, end: targetScreen, t: progress)

            let wobble = sin(particle.wobblePhase) * 3 * camera.zoom
            let perpX = -dy / max(dist, 1) * wobble; let perpY = dx / max(dist, 1) * wobble
            let finalPos = CGPoint(x: pos.x + perpX, y: pos.y + perpY)

            renderer.drawParticle(context: &context, position: finalPos, particle: particle, edge: edge, state: state)
        }
    }

    static func bezierPoint(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, t: Double) -> CGPoint {
        let t = max(0, min(1, t))
        let mt = 1 - t; let mt2 = mt * mt; let mt3 = mt2 * mt
        let t2 = t * t; let t3 = t2 * t
        return CGPoint(
            x: mt3 * start.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * end.x,
            y: mt3 * start.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * end.y
        )
    }
}
