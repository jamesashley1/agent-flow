import SwiftUI

// MARK: - Tron Theme Renderer

/// Tron Legacy digital frontier: identity disc agents, light cycle trail edges,
/// perspective Grid floor, neon outlines on pure black, electric blue + orange.
struct TronRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme

        // Pure black void
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        // Grid toggle: Full Tron Grid with perspective floor
        if state.showGrid && state.detail(0.2) {
            drawTronGrid(context: &context, size: size, state: state)
        }

        // Sparse glowing data points
        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2
                guard sx > -5 && sx < size.width + 5 && sy > -5 && sy < size.height + 5 else { continue }
                // Only show bright ones — sparse like the Grid
                guard particle.brightness > 0.4 else { continue }
                let alpha = (particle.brightness - 0.4) * 0.5
                let s: CGFloat = 1.5
                context.fill(
                    Path(CGRect(x: sx - s/2, y: sy - s/2, width: s, height: s)),
                    with: .color(t.primary.opacity(alpha))
                )
            }
        }
    }

    // MARK: - Tron Grid (Perspective Floor)

    private func drawTronGrid(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme; let cam = state.camera

        // Horizon line at 1/3 from top
        let horizonY = size.height * 0.33
        let vanishX = size.width / 2 + cam.offset.x * cam.zoom * 0.3

        // Horizon glow
        let horizonGrad = Gradient(stops: [
            .init(color: t.primary.opacity(0.06), location: 0),
            .init(color: .clear, location: 1)
        ])
        context.fill(
            Path(CGRect(x: 0, y: horizonY - 40, width: size.width, height: 80)),
            with: .linearGradient(horizonGrad, startPoint: CGPoint(x: 0, y: horizonY), endPoint: CGPoint(x: 0, y: horizonY - 40))
        )

        // Floor grid: horizontal lines (receding)
        let lineCount = 20
        for i in 1...lineCount {
            let progress = CGFloat(i) / CGFloat(lineCount)
            let y = horizonY + (size.height - horizonY) * progress
            let alpha = 0.08 * progress // brighter closer to camera
            let line = Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) }
            context.stroke(line, with: .color(t.primary.opacity(Double(alpha))), lineWidth: 0.5)
        }

        // Floor grid: vertical lines (converging to vanishing point)
        let vLineCount = 16
        for i in 0...vLineCount {
            let spread = CGFloat(i) / CGFloat(vLineCount)
            let bottomX = size.width * spread
            // Lines converge toward vanishing point
            let topX = vanishX + (bottomX - vanishX) * 0.05
            let line = Path { p in
                p.move(to: CGPoint(x: topX, y: horizonY))
                p.addLine(to: CGPoint(x: bottomX, y: size.height))
            }
            let distFromCenter = abs(spread - 0.5) * 2
            let alpha = 0.06 * (1.0 - distFromCenter * 0.5)
            context.stroke(line, with: .color(t.primary.opacity(Double(alpha))), lineWidth: 0.5)
        }

        // Cylindrical horizon glow (portal effect)
        let portalW: CGFloat = 200; let portalH: CGFloat = 60
        let portalRect = CGRect(x: vanishX - portalW/2, y: horizonY - portalH, width: portalW, height: portalH * 2)
        let portalGrad = Gradient(stops: [
            .init(color: t.primary.opacity(0.04), location: 0),
            .init(color: .clear, location: 1)
        ])
        context.fill(Ellipse().path(in: portalRect),
                     with: .radialGradient(portalGrad, center: CGPoint(x: vanishX, y: horizonY), startRadius: 0, endRadius: portalW/2))
    }

    // MARK: - Agent: Identity Disc

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let accent = resolveColor(agent: agent, state: state)
        let time = state.time

        // Outer disc ring (bright neon outline)
        let outerR = radius
        context.stroke(
            Circle().path(in: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR*2, height: outerR*2)),
            with: .color(accent.opacity(agent.opacity * 0.8)), lineWidth: 2.5)

        // Neon glow around disc
        if state.detail(0.2) {
            let glowR = radius * 1.5
            let glowGrad = Gradient(stops: [
                .init(color: accent.opacity(agent.opacity * 0.15), location: 0.5),
                .init(color: .clear, location: 1)
            ])
            context.fill(Circle().path(in: CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR*2, height: glowR*2)),
                         with: .radialGradient(glowGrad, center: center, startRadius: outerR * 0.8, endRadius: glowR))
        }

        // Inner ring (main agents get double ring)
        if agent.isMain {
            let innerR = radius * 0.75
            context.stroke(
                Circle().path(in: CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR*2, height: innerR*2)),
                with: .color(accent.opacity(agent.opacity * 0.5)), lineWidth: 1.5)
        }

        // Cross/T interior pattern
        if state.detail(0.2) {
            let crossR = radius * 0.5
            // Rotate when active
            let rot = agent.isActive ? time * 1.5 : 0
            let arms: [(Double, CGFloat)] = [(0, crossR), (.pi/2, crossR), (.pi, crossR), (.pi * 1.5, crossR * 0.6)]
            for (baseAngle, length) in arms {
                let angle = baseAngle + rot
                let path = Path { p in
                    p.move(to: center)
                    p.addLine(to: CGPoint(
                        x: center.x + cos(angle) * Double(length),
                        y: center.y + sin(angle) * Double(length)
                    ))
                }
                context.stroke(path, with: .color(accent.opacity(agent.opacity * 0.4)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }

        // Center dot
        let dotR = radius * 0.1
        context.fill(Circle().path(in: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR*2, height: dotR*2)),
                     with: .color(accent.opacity(agent.opacity * 0.9)))

        // Spinning edge highlight (bright arc that rotates around the disc)
        if agent.isActive && state.detail(0.4) {
            let arcStart = Angle(radians: time * 3)
            let arcEnd = arcStart + .degrees(60)
            let arc = Path { p in
                p.addArc(center: center, radius: outerR + 1, startAngle: arcStart, endAngle: arcEnd, clockwise: false)
            }
            context.stroke(arc, with: .color(accent.opacity(agent.opacity * 0.6)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    // MARK: - Edges: Light Cycle Trails

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let dx = target.x - source.x; let dy = target.y - source.y

        // Light cycle routing: horizontal then vertical (right-angle only)
        let elbowX = source.x + dx * 0.5
        let path = Path { p in
            p.move(to: source)
            p.addLine(to: CGPoint(x: elbowX, y: source.y))
            p.addLine(to: CGPoint(x: elbowX, y: target.y))
            p.addLine(to: target)
        }

        let w: CGFloat = (edge.type == .parentChild ? 2.0 : 1.2) * state.camera.zoom
        let a = edge.opacity * (edge.isActive ? 0.7 : 0.2)
        let color = edge.type == .parentChild ? t.primary : t.secondary

        // Trail glow (wider, dimmer)
        if state.detail(0.2) {
            context.stroke(path, with: .color(color.opacity(a * 0.2)), style: StrokeStyle(lineWidth: w * 4, lineCap: .square, lineJoin: .miter))
        }

        // Main bright trail
        context.stroke(path, with: .color(color.opacity(a)), style: StrokeStyle(lineWidth: w, lineCap: .square, lineJoin: .miter))

        // Corner flash (bright dot at the elbow)
        if state.detail(0.4) {
            let cornerR: CGFloat = 3 * state.camera.zoom
            let corners = [CGPoint(x: elbowX, y: source.y), CGPoint(x: elbowX, y: target.y)]
            for c in corners {
                context.fill(Circle().path(in: CGRect(x: c.x - cornerR, y: c.y - cornerR, width: cornerR*2, height: cornerR*2)),
                             with: .color(color.opacity(a * 0.8)))
            }
        }
    }

    // MARK: - Particles: Light Runners

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch; case .return: color = t.particleReturn
        case .toolCall: color = t.particleToolCall; case .toolReturn: color = t.particleToolReturn
        }

        // Bright square head
        let s: CGFloat = 4 * zoom
        context.fill(Path(CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
                     with: .color(color.opacity(particle.opacity)))

        // Neon glow around head
        let glowR: CGFloat = 8 * zoom
        let grad = Gradient(stops: [
            .init(color: color.opacity(particle.opacity * 0.3), location: 0),
            .init(color: .clear, location: 1)
        ])
        context.fill(Circle().path(in: CGRect(x: position.x - glowR, y: position.y - glowR, width: glowR*2, height: glowR*2)),
                     with: .radialGradient(grad, center: position, startRadius: 0, endRadius: glowR))

        // 1px trail line behind (short)
        if state.detail(0.6) {
            // Approximate trail direction from edge
            let trailLen: CGFloat = 12 * zoom
            let source = state.agents[edge.sourceId]?.position ?? .zero
            let target = state.agents[edge.targetId]?.position ?? .zero
            let cam = state.camera
            let ss = cam.worldToScreen(source, viewSize: CGSize(width: 1, height: 1))
            let ts = cam.worldToScreen(target, viewSize: CGSize(width: 1, height: 1))
            let edx = ts.x - ss.x; let edy = ts.y - ss.y
            let edist = max(sqrt(edx * edx + edy * edy), 1)
            let trail = Path { p in
                p.move(to: position)
                p.addLine(to: CGPoint(x: position.x - edx/edist * trailLen, y: position.y - edy/edist * trailLen))
            }
            context.stroke(trail, with: .color(color.opacity(particle.opacity * 0.4)), lineWidth: 1)
        }
    }

    // MARK: - Tool Cards: Neon Program Cards

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = tool.opacity
        let cardW: CGFloat = 50 * zoom; let cardH: CGFloat = 20 * zoom
        let cardRect = CGRect(x: center.x - cardW/2, y: center.y - cardH/2, width: cardW, height: cardH)

        let borderColor: Color
        switch tool.state {
        case .running: borderColor = t.secondary; case .complete: borderColor = t.success; case .error: borderColor = t.error
        }

        // Neon border (no fill, just outline — Tron style)
        context.stroke(Path(cardRect), with: .color(borderColor.opacity(alpha * 0.7)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))

        // Glow
        if state.detail(0.2) {
            context.stroke(Path(cardRect), with: .color(borderColor.opacity(alpha * 0.15)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .square, lineJoin: .miter))
        }

        // Running: pulsing inner line
        if tool.state == .running {
            let pulse = (sin(tool.pulsePhase) + 1) / 2
            let innerW = cardW * CGFloat(pulse) * 0.8
            let barRect = CGRect(x: center.x - innerW/2, y: center.y + cardH/2 - 2 * zoom, width: innerW, height: 1.5 * zoom)
            context.fill(Path(barRect), with: .color(borderColor.opacity(alpha * 0.5)))
        }

        // Label
        if state.detail(0.6) && zoom > 0.4 {
            let label = Text(tool.name)
                .font(.system(size: max(6, 8 * zoom), weight: .light, design: .monospaced))
                .foregroundStyle(borderColor.opacity(alpha * 0.8))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y), anchor: .center)
        }
    }

    // MARK: - Discoveries: Glowing Data Cubes

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let alpha = discovery.opacity
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: state.theme)
        let s: CGFloat = 10 * zoom

        // Neon cube outline
        let cubeRect = CGRect(x: center.x - s/2, y: center.y - s/2, width: s, height: s)
        context.stroke(Path(cubeRect), with: .color(typeColor.opacity(alpha * 0.7)),
                       style: StrokeStyle(lineWidth: 1.2, lineCap: .square, lineJoin: .miter))

        // Glow
        context.stroke(Path(cubeRect), with: .color(typeColor.opacity(alpha * 0.15)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .square, lineJoin: .miter))

        // Inner bright pixel
        let innerS: CGFloat = 3 * zoom
        context.fill(Path(CGRect(x: center.x - innerS/2, y: center.y - innerS/2, width: innerS, height: innerS)),
                     with: .color(typeColor.opacity(alpha * 0.5)))

        // Label
        if state.detail(0.6) && zoom > 0.4 {
            let label = Text(discovery.label)
                .font(.system(size: max(6, 7 * zoom), weight: .light, design: .monospaced))
                .foregroundStyle(typeColor.opacity(alpha * 0.6))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y + s/2 + 4 * zoom), anchor: .top)
        }
    }

    // MARK: - Clusters: Arena Boundaries

    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount

        // Sharp rectangle arena
        let strokeStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter)
            : StrokeStyle(lineWidth: 1, lineCap: .square, lineJoin: .miter, dash: [6, 4])
        context.stroke(Path(rect), with: .color(accentColor.opacity(0.2 * dim)), style: strokeStyle)

        // Glow on border
        context.stroke(Path(rect), with: .color(accentColor.opacity(0.04 * dim)),
                       style: StrokeStyle(lineWidth: 6, lineCap: .square, lineJoin: .miter))

        // Bright corner nodes
        let nodeR: CGFloat = 4 * state.camera.zoom
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        for c in corners {
            context.fill(Circle().path(in: CGRect(x: c.x - nodeR, y: c.y - nodeR, width: nodeR*2, height: nodeR*2)),
                         with: .color(accentColor.opacity(0.5 * dim)))
            // Corner glow
            let glowR = nodeR * 3
            let grad = Gradient(stops: [
                .init(color: accentColor.opacity(0.15 * dim), location: 0),
                .init(color: .clear, location: 1)
            ])
            context.fill(Circle().path(in: CGRect(x: c.x - glowR, y: c.y - glowR, width: glowR*2, height: glowR*2)),
                         with: .radialGradient(grad, center: c, startRadius: 0, endRadius: glowR))
        }
    }

    // MARK: - Effects

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let t = state.theme; let zoom = state.camera.zoom

        // Derez-in-reverse: pixels assembling inward
        let particleCount = 12
        let rng = SeededRNG(seed: UInt64(abs(effect.position.x.hashValue &+ effect.position.y.hashValue)))
        var r = rng
        for _ in 0..<particleCount {
            let angle = r.next() * 2 * .pi
            let maxDist = 50 * Double(zoom)
            let dist = maxDist * (1.0 - progress) // converge inward
            let px = screenPos.x + CGFloat(cos(angle) * dist)
            let py = screenPos.y + CGFloat(sin(angle) * dist)
            let s: CGFloat = CGFloat(2 + r.next() * 2) * zoom
            let alpha = progress // brighter as they converge
            context.fill(Path(CGRect(x: px - s/2, y: py - s/2, width: s, height: s)),
                         with: .color(t.primary.opacity(alpha * 0.6)))
        }

        // Forming disc outline
        let discR = 20 * zoom * CGFloat(progress)
        let discAlpha = progress * 0.5
        context.stroke(Circle().path(in: CGRect(x: screenPos.x - discR, y: screenPos.y - discR, width: discR*2, height: discR*2)),
                       with: .color(t.primary.opacity(discAlpha)), lineWidth: 1.5)
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        // Derez: square pixel fragments
        let s: CGFloat = 3 * state.camera.zoom
        context.fill(Path(CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
                     with: .color(state.theme.primary.opacity(opacity)))
    }

    private func resolveColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid], state.clusters.count > 1 {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        // Main agents blue, subagents orange (like Flynn vs programs)
        return agent.isMain ? state.theme.primary : state.theme.secondary
    }
}

// MARK: - Seeded RNG (deterministic spawn effects)
private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
    }
}
