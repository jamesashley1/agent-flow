import SwiftUI

// MARK: - Ironman Theme Renderer

/// Jarvis-style HUD: chunky concentric ring gauges with segmented arcs,
/// angular circuit connectors, scanning lines, electric cyan on dark navy.
struct IronmanRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme

        // Dark navy void with subtle gradient
        let grad = Gradient(stops: [
            .init(color: t.voidColor, location: 0),
            .init(color: t.voidColorAlt, location: 0.5),
            .init(color: t.voidColor, location: 1)
        ])
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(grad, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height)))

        // Grid toggle: HUD panel frame with corner brackets, tick scales, scan lines
        if state.showGrid && state.detail(0.2) {
            drawHUDGrid(context: &context, size: size, state: state)
        }

        // Scattered data point particles
        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2
                guard sx > -5 && sx < size.width + 5 && sy > -5 && sy < size.height + 5 else { continue }
                let alpha = particle.brightness * 0.35
                let s = particle.size * 0.6
                context.fill(Circle().path(in: CGRect(x: sx - s/2, y: sy - s/2, width: s, height: s)),
                             with: .color(t.primary.opacity(alpha)))
            }
        }

        // Central ambient glow
        if state.detail(0.4) {
            guard let active = state.agents.values.first(where: { $0.isActive }) ?? state.agents.values.first else { return }
            let sp = state.camera.worldToScreen(active.position, viewSize: size)
            let r: CGFloat = 350
            let glowGrad = Gradient(stops: [
                .init(color: t.primary.opacity(0.08), location: 0),
                .init(color: t.primary.opacity(0.02), location: 0.5),
                .init(color: .clear, location: 1)
            ])
            context.fill(Circle().path(in: CGRect(x: sp.x - r, y: sp.y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(glowGrad, center: sp, startRadius: 0, endRadius: r))
        }
    }

    // MARK: - HUD Grid

    private func drawHUDGrid(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme
        let cam = state.camera

        // Corner brackets at screen edges
        let bracketLen: CGFloat = 40; let margin: CGFloat = 20; let lw: CGFloat = 1.5
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: margin, y: margin), 1, 1),
            (CGPoint(x: size.width - margin, y: margin), -1, 1),
            (CGPoint(x: margin, y: size.height - margin), 1, -1),
            (CGPoint(x: size.width - margin, y: size.height - margin), -1, -1)
        ]
        for (corner, dx, dy) in corners {
            let bracket = Path { p in
                p.move(to: CGPoint(x: corner.x + dx * bracketLen, y: corner.y))
                p.addLine(to: corner)
                p.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * bracketLen))
            }
            context.stroke(bracket, with: .color(t.primary.opacity(0.15)), style: StrokeStyle(lineWidth: lw, lineCap: .square))
        }

        // Measurement ticks along edges
        let tickSpacing: CGFloat = 50 * cam.zoom
        guard tickSpacing > 10 else { return }
        let oX = cam.offset.x * cam.zoom + size.width / 2
        let oY = cam.offset.y * cam.zoom + size.height / 2

        // Top edge ticks
        var x = (oX.truncatingRemainder(dividingBy: tickSpacing) + tickSpacing).truncatingRemainder(dividingBy: tickSpacing)
        while x < size.width {
            let isMajor = Int((x - oX) / tickSpacing) % 5 == 0
            let tickH: CGFloat = isMajor ? 10 : 5
            let tick = Path { p in p.move(to: CGPoint(x: x, y: margin)); p.addLine(to: CGPoint(x: x, y: margin + tickH)) }
            context.stroke(tick, with: .color(t.primary.opacity(isMajor ? 0.12 : 0.05)), lineWidth: 0.5)
            // Bottom edge
            let btick = Path { p in p.move(to: CGPoint(x: x, y: size.height - margin)); p.addLine(to: CGPoint(x: x, y: size.height - margin - tickH)) }
            context.stroke(btick, with: .color(t.primary.opacity(isMajor ? 0.12 : 0.05)), lineWidth: 0.5)
            x += tickSpacing
        }

        // Left/right edge ticks
        var y = (oY.truncatingRemainder(dividingBy: tickSpacing) + tickSpacing).truncatingRemainder(dividingBy: tickSpacing)
        while y < size.height {
            let isMajor = Int((y - oY) / tickSpacing) % 5 == 0
            let tickW: CGFloat = isMajor ? 10 : 5
            let ltick = Path { p in p.move(to: CGPoint(x: margin, y: y)); p.addLine(to: CGPoint(x: margin + tickW, y: y)) }
            context.stroke(ltick, with: .color(t.primary.opacity(isMajor ? 0.12 : 0.05)), lineWidth: 0.5)
            let rtick = Path { p in p.move(to: CGPoint(x: size.width - margin, y: y)); p.addLine(to: CGPoint(x: size.width - margin - tickW, y: y)) }
            context.stroke(rtick, with: .color(t.primary.opacity(isMajor ? 0.12 : 0.05)), lineWidth: 0.5)
            y += tickSpacing
        }

        // Horizontal scanning line that sweeps down
        let scanY = (CGFloat(state.time * 40).truncatingRemainder(dividingBy: size.height))
        // Holographic glitch: offset horizontally every ~3 seconds
        let glitchPhase = (state.time * 0.33).truncatingRemainder(dividingBy: 1.0)
        let glitchOffset: CGFloat = glitchPhase < 0.05 ? CGFloat(3 + sin(state.time * 17) * 2) : 0
        let scanGrad = Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: t.primary.opacity(0.06), location: 0.4),
            .init(color: t.primary.opacity(0.1), location: 0.5),
            .init(color: t.primary.opacity(0.06), location: 0.6),
            .init(color: .clear, location: 1)
        ])
        let scanRect = CGRect(x: glitchOffset, y: scanY - 30, width: size.width, height: 60)
        context.fill(Path(scanRect), with: .linearGradient(scanGrad, startPoint: CGPoint(x: 0, y: scanRect.minY), endPoint: CGPoint(x: 0, y: scanRect.maxY)))

        // Panel divider lines (faint horizontal/vertical mid-lines)
        let hMid = Path { p in p.move(to: CGPoint(x: margin + bracketLen, y: size.height / 2)); p.addLine(to: CGPoint(x: size.width - margin - bracketLen, y: size.height / 2)) }
        context.stroke(hMid, with: .color(t.primary.opacity(0.03)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 8]))
    }

    // MARK: - Agent: Concentric Ring Gauge

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let accent = resolveClusterColor(agent: agent, state: state)
        let time = state.time

        // Outer bold ring (segmented with gaps)
        let outerR = radius * 1.1
        let segments = agent.isMain ? 8 : 6
        let gapDeg: Double = 12
        let segDeg = (360.0 / Double(segments)) - gapDeg
        for i in 0..<segments {
            let start = Angle(degrees: Double(i) * (segDeg + gapDeg) + time * 10)
            let end = start + .degrees(segDeg)
            let arc = Path { p in
                p.addArc(center: center, radius: outerR, startAngle: start, endAngle: end, clockwise: false)
            }
            context.stroke(arc, with: .color(accent.opacity(agent.opacity * 0.6)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .butt))
        }

        // Middle ring (thinner, counter-rotating)
        let midR = radius * 0.85
        let midSegments = agent.isMain ? 12 : 8
        let midGap: Double = 5; let midSeg = (360.0 / Double(midSegments)) - midGap
        for i in 0..<midSegments {
            let start = Angle(degrees: Double(i) * (midSeg + midGap) - time * 15)
            let end = start + .degrees(midSeg)
            let arc = Path { p in
                p.addArc(center: center, radius: midR, startAngle: start, endAngle: end, clockwise: false)
            }
            context.stroke(arc, with: .color(accent.opacity(agent.opacity * 0.35)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .butt))
        }

        // Inner ring (solid, slight pulse)
        let innerR = radius * 0.6
        let innerAlpha = agent.isActive ? 0.4 + sin(agent.breathPhase) * 0.1 : 0.25
        context.stroke(
            Circle().path(in: CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)),
            with: .color(accent.opacity(agent.opacity * innerAlpha)), lineWidth: 1.5)

        // Core glow
        let coreR = radius * 0.4
        let coreGrad = Gradient(stops: [
            .init(color: t.primary.opacity(agent.opacity * 0.5), location: 0),
            .init(color: t.primary.opacity(agent.opacity * 0.1), location: 0.6),
            .init(color: .clear, location: 1)
        ])
        context.fill(
            Circle().path(in: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)),
            with: .radialGradient(coreGrad, center: center, startRadius: 0, endRadius: coreR))

        // Chevron/diamond in center
        if state.detail(0.2) {
            let chevR = radius * 0.22
            let chevPath = Path { p in
                p.move(to: CGPoint(x: center.x, y: center.y - chevR))
                p.addLine(to: CGPoint(x: center.x + chevR * 0.7, y: center.y))
                p.addLine(to: CGPoint(x: center.x, y: center.y + chevR))
                p.addLine(to: CGPoint(x: center.x - chevR * 0.7, y: center.y))
                p.closeSubpath()
            }
            context.stroke(chevPath, with: .color(t.primary.opacity(agent.opacity * 0.7)), lineWidth: 1.2)
        }

        // Token arc (progress indicator on outer ring)
        if agent.tokensMax > 0 && state.detail(0.4) {
            let progress = min(Double(agent.tokensUsed) / Double(agent.tokensMax), 1.0)
            if progress > 0 {
                let tokenArc = Path { p in
                    p.addArc(center: center, radius: outerR + 5, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
                }
                let tokenColor = progress > 0.8 ? t.error : t.secondary
                context.stroke(tokenArc, with: .color(tokenColor.opacity(agent.opacity * 0.5)), lineWidth: 2)
            }
        }

        // Small data readouts (floating numbers like in the reference)
        if state.detail(0.4) && state.camera.zoom > 0.4 {
            let numText = Text(String(format: "%.1f", Double(agent.tokensUsed) / 1000.0))
                .font(.system(size: max(7, 8 * state.camera.zoom), weight: .regular, design: .monospaced))
                .foregroundStyle(t.primary.opacity(agent.opacity * 0.5))
            context.draw(context.resolve(numText),
                         at: CGPoint(x: center.x + outerR + 10, y: center.y - outerR * 0.3), anchor: .leading)
        }
    }

    // MARK: - Edges: Angular Circuit Connectors

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let dx = target.x - source.x; let dy = target.y - source.y

        // Angular connector: horizontal from source, then angled line to target
        // Similar to the circuit-board lines in the reference
        let midX = source.x + dx * 0.5
        let elbowY = source.y + dy * 0.3
        let path = Path { p in
            p.move(to: source)
            p.addLine(to: CGPoint(x: midX, y: source.y))       // horizontal
            p.addLine(to: CGPoint(x: midX, y: elbowY))          // vertical
            p.addLine(to: CGPoint(x: target.x, y: elbowY))      // horizontal
            p.addLine(to: target)                                  // vertical to target
        }

        let w: CGFloat = (edge.type == .parentChild ? 1.5 : 1.0) * state.camera.zoom
        let a = edge.opacity * (edge.isActive ? 0.5 : 0.15)

        context.stroke(path, with: .color(t.primary.opacity(a)),
                       style: StrokeStyle(lineWidth: w, lineCap: .square, lineJoin: .miter))

        // Glow on active
        if edge.isActive && state.detail(0.2) {
            context.stroke(path, with: .color(t.primary.opacity(a * 0.2)),
                           style: StrokeStyle(lineWidth: w * 4, lineCap: .square))
        }

        // Small node dots at elbows
        if state.detail(0.4) {
            let dotR: CGFloat = 2 * state.camera.zoom
            let elbows = [CGPoint(x: midX, y: source.y), CGPoint(x: midX, y: elbowY), CGPoint(x: target.x, y: elbowY)]
            for e in elbows {
                context.fill(Circle().path(in: CGRect(x: e.x - dotR, y: e.y - dotR, width: dotR * 2, height: dotR * 2)),
                             with: .color(t.primary.opacity(a * 0.7)))
            }
        }
    }

    // MARK: - Particles: Bright Scan Points

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch; case .return: color = t.particleReturn
        case .toolCall: color = t.particleToolCall; case .toolReturn: color = t.particleToolReturn
        }

        // Bright dot with horizontal scan flare
        let s: CGFloat = 5 * zoom
        context.fill(Circle().path(in: CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
                     with: .color(color.opacity(particle.opacity)))

        // Horizontal flare
        let flareW: CGFloat = 12 * zoom
        let flarePath = Path { p in
            p.move(to: CGPoint(x: position.x - flareW, y: position.y))
            p.addLine(to: CGPoint(x: position.x + flareW, y: position.y))
        }
        context.stroke(flarePath, with: .color(color.opacity(particle.opacity * 0.3)), lineWidth: 1)

        // Glow
        let glowR: CGFloat = 8 * zoom
        let grad = Gradient(stops: [
            .init(color: color.opacity(particle.opacity * 0.3), location: 0),
            .init(color: .clear, location: 1)
        ])
        context.fill(Circle().path(in: CGRect(x: position.x - glowR, y: position.y - glowR, width: glowR * 2, height: glowR * 2)),
                     with: .radialGradient(grad, center: position, startRadius: 0, endRadius: glowR))
    }

    // MARK: - Tool Cards: Small Gauge Icons

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let r: CGFloat = 12 * zoom
        let alpha = tool.opacity

        let borderColor: Color
        switch tool.state {
        case .running: borderColor = t.secondary; case .complete: borderColor = t.success; case .error: borderColor = t.error
        }

        // Gauge arc (270 degrees)
        let gaugeArc = Path { p in
            p.addArc(center: center, radius: r, startAngle: .degrees(135), endAngle: .degrees(45), clockwise: false)
        }
        context.stroke(gaugeArc, with: .color(borderColor.opacity(alpha * 0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Needle (if running, animated)
        let needleAngle: Double
        if tool.state == .running {
            needleAngle = 135 + (state.time * 100).truncatingRemainder(dividingBy: 270)
        } else {
            needleAngle = 135 + 270 * 0.8 // near full
        }
        let nr = r * 0.7
        let needlePath = Path { p in
            p.move(to: center)
            p.addLine(to: CGPoint(
                x: center.x + CoreGraphics.cos(CGFloat(needleAngle * .pi / 180)) * nr,
                y: center.y + CoreGraphics.sin(CGFloat(needleAngle * .pi / 180)) * nr
            ))
        }
        context.stroke(needlePath, with: .color(borderColor.opacity(alpha * 0.7)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

        // Center dot
        let dotR: CGFloat = 2 * zoom
        context.fill(Circle().path(in: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2)),
                     with: .color(borderColor.opacity(alpha * 0.8)))

        // Label
        if state.detail(0.6) && zoom > 0.4 {
            let label = Text(tool.name)
                .font(.system(size: max(7, 8 * zoom), weight: .light, design: .monospaced))
                .foregroundStyle(borderColor.opacity(alpha * 0.6))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y + r + 6 * zoom), anchor: .top)
        }
    }

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = discovery.opacity
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: t)

        let panelWidth: CGFloat = 120 * zoom
        let panelHeight: CGFloat = 40 * zoom
        let rect = CGRect(x: center.x - panelWidth / 2, y: center.y - panelHeight / 2, width: panelWidth, height: panelHeight)
        let arm: CGFloat = 4 * zoom  // bracket arm length

        // Translucent background fill
        context.fill(Path(rect), with: .color(t.agentFillBottom.opacity(alpha * 0.15)))

        // Bracket corners (L-shapes at each corner)
        let bracketCorners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),     // top-left
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),    // top-right
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),    // bottom-left
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1)    // bottom-right
        ]
        for (corner, dx, dy) in bracketCorners {
            let bracket = Path { p in
                p.move(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
                p.addLine(to: corner)
                p.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
            }
            context.stroke(bracket, with: .color(typeColor.opacity(alpha * 0.8)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
        }

        // Label text inside panel
        if zoom > 0.3 {
            let fontSize = max(7, 8 * zoom)
            let label = Text(discovery.label)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(typeColor.opacity(alpha * 0.9))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y), anchor: .center)
        }
    }
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount

        let cx = rect.midX, cy = rect.midY
        // Circumscribe the bounding box: radius from center to corner
        let radius = hypot(rect.width / 2, rect.height / 2)

        var hex = Path()
        for i in 0..<6 {
            let angle = (Double(i) / 6.0) * 2.0 * .pi - .pi / 2
            let px = cx + radius * cos(angle)
            let py = cy + radius * sin(angle)
            if i == 0 {
                hex.move(to: CGPoint(x: px, y: py))
            } else {
                hex.addLine(to: CGPoint(x: px, y: py))
            }
        }
        hex.closeSubpath()

        context.fill(hex, with: .color(accentColor.opacity(0.03 * dim)))

        let strokeStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1.5)
            : StrokeStyle(lineWidth: 1, dash: [6, 4])
        context.stroke(hex, with: .color(accentColor.opacity(0.2 * dim)), style: strokeStyle)
    }

    // MARK: - Effects

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let t = state.theme; let zoom = state.camera.zoom; let alpha = 1.0 - progress

        // HUD targeting brackets that close in
        let bracketSize = 50 * (1.0 - progress) * zoom + 10 * zoom
        let corners: [(CGFloat, CGFloat)] = [(1,1), (-1,1), (1,-1), (-1,-1)]
        for (dx, dy) in corners {
            let cx = screenPos.x + dx * bracketSize; let cy = screenPos.y + dy * bracketSize
            let bracket = Path { p in
                p.move(to: CGPoint(x: cx - dx * 8 * zoom, y: cy))
                p.addLine(to: CGPoint(x: cx, y: cy))
                p.addLine(to: CGPoint(x: cx, y: cy - dy * 8 * zoom))
            }
            context.stroke(bracket, with: .color(t.primary.opacity(alpha * 0.6)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
        }
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        let s: CGFloat = 2 * state.camera.zoom
        context.fill(Path(CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
                     with: .color(state.theme.primary.opacity(opacity)))
    }

    private func resolveClusterColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid] {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.primary
    }
}
