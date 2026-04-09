import SwiftUI

// MARK: - Tactical Theme Renderer

/// Ender's Game-style holographic tactical display: concentric ring agents,
/// arc-line edges, glowing data points, amber core to ice-blue outer rings.
struct TacticalRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme

        // Deep void
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        // Faint circular grid arcs (radar-like)
        if state.detail(0.2) {
            let cam = state.camera
            let center = CGPoint(
                x: cam.offset.x * cam.zoom + size.width / 2,
                y: cam.offset.y * cam.zoom + size.height / 2
            )
            let maxR: CGFloat = max(size.width, size.height) * 1.5
            let ringSpacing: CGFloat = 120 * cam.zoom
            guard ringSpacing > 10 else { return }

            var r: CGFloat = ringSpacing
            while r < maxR {
                let alpha = 0.04 * (1.0 - r / maxR)
                context.stroke(
                    Circle().path(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(t.primary.opacity(alpha)),
                    style: StrokeStyle(lineWidth: 0.5)
                )
                r += ringSpacing
            }

            // Crosshair lines through center
            let crossAlpha = 0.03
            let hLine = Path { p in p.move(to: CGPoint(x: 0, y: center.y)); p.addLine(to: CGPoint(x: size.width, y: center.y)) }
            let vLine = Path { p in p.move(to: CGPoint(x: center.x, y: 0)); p.addLine(to: CGPoint(x: center.x, y: size.height)) }
            context.stroke(hLine, with: .color(t.primary.opacity(crossAlpha)), lineWidth: 0.5)
            context.stroke(vLine, with: .color(t.primary.opacity(crossAlpha)), lineWidth: 0.5)

            // Grid toggle: Radial spoke lines + rotating sweep line
            if state.showGrid {
                let spokeCount = 12
                for i in 0..<spokeCount {
                    let angle = Double(i) * (2.0 * .pi / Double(spokeCount))
                    let endX = center.x + cos(angle) * maxR; let endY = center.y + sin(angle) * maxR
                    let spoke = Path { p in p.move(to: center); p.addLine(to: CGPoint(x: endX, y: endY)) }
                    context.stroke(spoke, with: .color(t.primary.opacity(0.03)), lineWidth: 0.5)
                }
                // Rotating sweep line (like radar)
                let sweepAngle: CGFloat = CGFloat(state.time * 0.5)
                let sweepEnd = CGPoint(x: center.x + CoreGraphics.cos(sweepAngle) * maxR, y: center.y + CoreGraphics.sin(sweepAngle) * maxR)
                let sweep = Path { p in p.move(to: center); p.addLine(to: sweepEnd) }
                context.stroke(sweep, with: .color(t.secondary.opacity(0.08)), lineWidth: 1.5)
                // Sweep fade trail
                for trail in 1..<6 {
                    let trailAngle: CGFloat = sweepAngle - CGFloat(trail) * 0.04
                    let trailEnd = CGPoint(x: center.x + CoreGraphics.cos(trailAngle) * maxR, y: center.y + CoreGraphics.sin(trailAngle) * maxR)
                    let trailPath = Path { p in p.move(to: center); p.addLine(to: trailEnd) }
                    context.stroke(trailPath, with: .color(t.secondary.opacity(0.08 * (1.0 - Double(trail) / 6.0))), lineWidth: 1)
                }

                // Ghost blips: bright dot when sweep passes near an agent
                for agent in state.agents.values {
                    let agentScreen = cam.worldToScreen(agent.position, viewSize: size)
                    let dx = agentScreen.x - center.x
                    let dy = agentScreen.y - center.y
                    let agentAngle = atan2(dy, dx)
                    // Normalize sweep angle to [-pi, pi]
                    let normalizedSweep = atan2(CoreGraphics.sin(sweepAngle), CoreGraphics.cos(sweepAngle))
                    var angleDiff = abs(Double(normalizedSweep - agentAngle))
                    if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }
                    // Ghost blip fades over 0.5s after sweep passes
                    let fadeAlpha: Double
                    if angleDiff < 0.1 {
                        fadeAlpha = 1.0
                    } else {
                        // Calculate how long ago the sweep passed (angular distance / angular speed)
                        let angularSpeed = 0.5 // radians per second, matches sweepAngle = time * 0.5
                        let timeSincePass = angleDiff / angularSpeed
                        fadeAlpha = timeSincePass < 0.5 ? max(0, 1.0 - timeSincePass / 0.5) : 0
                    }
                    if fadeAlpha > 0.01 {
                        let ghostR: CGFloat = 3 * cam.zoom
                        context.fill(
                            Circle().path(in: CGRect(x: agentScreen.x - ghostR, y: agentScreen.y - ghostR, width: ghostR * 2, height: ghostR * 2)),
                            with: .color(t.secondary.opacity(fadeAlpha * 0.6))
                        )
                    }
                }
            }
        }

        // Scattered data points (small dots like star chart)
        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2
                guard sx > -5 && sx < size.width + 5 && sy > -5 && sy < size.height + 5 else { continue }
                let twinkle = (sin(state.time * 2.5 + particle.brightness * 10) + 1) / 2 * 0.3 + 0.7
                let alpha = particle.brightness * twinkle * 0.5
                let s = particle.size * 0.8
                context.fill(
                    Circle().path(in: CGRect(x: sx - s/2, y: sy - s/2, width: s, height: s)),
                    with: .color(t.primary.opacity(alpha))
                )
            }
        }

        // Ambient glow at active agent
        if state.detail(0.4) {
            guard let active = state.agents.values.first(where: { $0.isActive }) ?? state.agents.values.first else { return }
            let sp = state.camera.worldToScreen(active.position, viewSize: size)
            let r: CGFloat = 400
            let grad = Gradient(stops: [
                .init(color: t.secondary.opacity(0.06), location: 0),
                .init(color: t.primary.opacity(0.03), location: 0.4),
                .init(color: .clear, location: 1)
            ])
            context.fill(
                Circle().path(in: CGRect(x: sp.x - r, y: sp.y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(grad, center: sp, startRadius: 0, endRadius: r)
            )
        }
    }

    // MARK: - Agent: Concentric Rings with Glowing Core

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let accent = resolveClusterColor(agent: agent, state: state)
        let time = state.time

        // Number of rings based on agent role
        let ringCount = agent.isMain ? 5 : 3

        // Outer rings (ice blue, thin, some rotating)
        for i in 0..<ringCount {
            let ringR = radius * (0.6 + CGFloat(i) * 0.35)
            let ringAlpha = agent.opacity * (0.15 + Double(ringCount - i) * 0.06)

            // Some rings rotate
            let rotSpeed = Double(i) * 0.15 * (i % 2 == 0 ? 1 : -1)
            let rotation = Angle(radians: time * rotSpeed)

            // Draw as partial arcs for visual interest
            let arcStart = Angle(degrees: Double(i * 30)) + rotation
            let arcEnd = arcStart + .degrees(280 + Double(i) * 15)

            let arcPath = Path { p in
                p.addArc(center: center, radius: ringR, startAngle: arcStart, endAngle: arcEnd, clockwise: false)
            }

            // Outer rings are blue, inner ring transitions to amber
            let ringColor = i < ringCount - 1 ? t.primary : accent
            context.stroke(arcPath, with: .color(ringColor.opacity(ringAlpha)),
                           style: StrokeStyle(lineWidth: i == 0 ? 1.5 : 0.8, lineCap: .round))

            // Small tick marks along the outermost ring
            if i == 0 && state.detail(0.4) {
                let tickCount = 12
                for ti in 0..<tickCount {
                    let tickAngle = arcStart.radians + Double(ti) * (arcEnd.radians - arcStart.radians) / Double(tickCount)
                    let inner = ringR - 3
                    let outer = ringR + 3
                    let tickPath = Path { p in
                        p.move(to: CGPoint(x: center.x + cos(tickAngle) * inner, y: center.y + sin(tickAngle) * inner))
                        p.addLine(to: CGPoint(x: center.x + cos(tickAngle) * outer, y: center.y + sin(tickAngle) * outer))
                    }
                    context.stroke(tickPath, with: .color(t.primary.opacity(ringAlpha * 0.5)), lineWidth: 0.5)
                }
            }
        }

        // Inner glow (amber/orange radial gradient)
        let coreR = radius * 0.45
        let coreGrad = Gradient(stops: [
            .init(color: t.secondary.opacity(agent.opacity * 0.6), location: 0),
            .init(color: t.secondary.opacity(agent.opacity * 0.15), location: 0.5),
            .init(color: t.primary.opacity(agent.opacity * 0.05), location: 1)
        ])
        context.fill(
            Circle().path(in: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)),
            with: .radialGradient(coreGrad, center: center, startRadius: 0, endRadius: coreR)
        )

        // Core dot
        let dotR = radius * 0.08
        context.fill(
            Circle().path(in: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2)),
            with: .color(t.secondary.opacity(agent.opacity * 0.9))
        )

        // Breathing pulse ring (when active)
        if agent.isActive {
            let pulseR = radius * (0.5 + sin(agent.breathPhase) * 0.1)
            let pulseAlpha = agent.opacity * (0.1 + sin(agent.breathPhase) * 0.05)
            context.stroke(
                Circle().path(in: CGRect(x: center.x - pulseR, y: center.y - pulseR, width: pulseR * 2, height: pulseR * 2)),
                with: .color(t.secondary.opacity(pulseAlpha)),
                lineWidth: 1.5
            )
        }

        // Small data readout near agent
        if state.detail(0.4) && state.camera.zoom > 0.4 {
            let readoutY = center.y - radius * 1.6
            let numText = Text(String(format: "%03d.%02d", agent.tokensUsed / 1000, (agent.tokensUsed / 10) % 100))
                .font(.system(size: max(7, 8 * state.camera.zoom), weight: .light, design: .monospaced))
                .foregroundStyle(t.primary.opacity(agent.opacity * 0.4))
            context.draw(context.resolve(numText), at: CGPoint(x: center.x, y: readoutY), anchor: .center)
        }
    }

    // MARK: - Edges: Thin Arc Lines

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let dx = target.x - source.x; let dy = target.y - source.y
        let dist = sqrt(dx * dx + dy * dy)

        // Arc-style connection (quadratic curve with offset)
        let perpOffset = dist * 0.15
        let nx = -dy / max(dist, 1) * perpOffset; let ny = dx / max(dist, 1) * perpOffset
        let control = CGPoint(x: (source.x + target.x) / 2 + nx, y: (source.y + target.y) / 2 + ny)

        let path = Path { p in
            p.move(to: source)
            p.addQuadCurve(to: target, control: control)
        }

        let w: CGFloat = (edge.type == .parentChild ? 1.2 : 0.7) * state.camera.zoom
        let a = edge.opacity * (edge.isActive ? 0.4 : 0.12)
        let color = t.primary

        context.stroke(path, with: .color(color.opacity(a)), style: StrokeStyle(lineWidth: w, lineCap: .round))

        // Glow for active
        if edge.isActive && state.detail(0.2) {
            context.stroke(path, with: .color(color.opacity(a * 0.3)), style: StrokeStyle(lineWidth: w * 3, lineCap: .round))
        }

        // Small dot markers along the edge
        if state.detail(0.4) {
            let markerCount = 3
            for i in 1..<markerCount {
                let mt = Double(i) / Double(markerCount)
                // Quadratic bezier point
                let mx = (1 - mt) * (1 - mt) * source.x + 2 * (1 - mt) * mt * control.x + mt * mt * target.x
                let my = (1 - mt) * (1 - mt) * source.y + 2 * (1 - mt) * mt * control.y + mt * mt * target.y
                let mr: CGFloat = 1.5 * state.camera.zoom
                context.fill(
                    Circle().path(in: CGRect(x: mx - mr, y: my - mr, width: mr * 2, height: mr * 2)),
                    with: .color(color.opacity(a * 0.5))
                )
            }
        }
    }

    // MARK: - Particles: Glowing Data Points

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch
        case .return:   color = t.particleReturn
        case .toolCall: color = t.particleToolCall
        case .toolReturn: color = t.particleToolReturn
        }

        // Glowing dot with halo
        let s: CGFloat = 4 * zoom
        let haloR: CGFloat = 10 * zoom
        let haloGrad = Gradient(stops: [
            .init(color: color.opacity(particle.opacity * 0.4), location: 0),
            .init(color: color.opacity(0), location: 1)
        ])
        context.fill(
            Circle().path(in: CGRect(x: position.x - haloR, y: position.y - haloR, width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(haloGrad, center: position, startRadius: 0, endRadius: haloR)
        )
        context.fill(
            Circle().path(in: CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
            with: .color(color.opacity(particle.opacity))
        )

        // Tiny crosshair on the particle
        if state.detail(0.6) {
            let cr: CGFloat = 6 * zoom
            let crossPath = Path { p in
                p.move(to: CGPoint(x: position.x - cr, y: position.y)); p.addLine(to: CGPoint(x: position.x + cr, y: position.y))
                p.move(to: CGPoint(x: position.x, y: position.y - cr)); p.addLine(to: CGPoint(x: position.x, y: position.y + cr))
            }
            context.stroke(crossPath, with: .color(color.opacity(particle.opacity * 0.2)), lineWidth: 0.5)
        }
    }

    // MARK: - Tool Cards: Circular Indicator Icons

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        // Small circular icons (like the left-side icons in the reference)
        let t = state.theme
        let r: CGFloat = 14 * zoom
        let alpha = tool.opacity

        let borderColor: Color
        switch tool.state {
        case .running: borderColor = t.secondary
        case .complete: borderColor = t.success
        case .error:   borderColor = t.error
        }

        // Outer ring
        context.stroke(
            Circle().path(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .color(borderColor.opacity(alpha * 0.6)), lineWidth: 1.2
        )

        // Inner dot pattern (3 small dots in a triangle)
        let dotR: CGFloat = 2 * zoom
        let innerR = r * 0.4
        for i in 0..<3 {
            let a = Double(i) * (2.0 * .pi / 3.0) - .pi / 2
            let dx = center.x + cos(a) * innerR; let dy = center.y + sin(a) * innerR
            context.fill(
                Circle().path(in: CGRect(x: dx - dotR, y: dy - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(borderColor.opacity(alpha * 0.5))
            )
        }

        // Spinning arc when running
        if tool.state == .running {
            let spinAngle = Angle(radians: state.time * 3)
            let spinPath = Path { p in
                p.addArc(center: center, radius: r + 3 * zoom, startAngle: spinAngle, endAngle: spinAngle + .degrees(90), clockwise: false)
            }
            context.stroke(spinPath, with: .color(borderColor.opacity(alpha * 0.4)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }

        // Label
        if state.detail(0.6) && zoom > 0.4 {
            let label = Text(tool.name)
                .font(.system(size: max(7, 8 * zoom), weight: .light, design: .monospaced))
                .foregroundStyle(borderColor.opacity(alpha * 0.7))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y + r + 6 * zoom), anchor: .top)
        }
    }

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = discovery.opacity
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: t)

        // Radar blip: filled circle
        let blipR: CGFloat = 6 * zoom
        context.fill(
            Circle().path(in: CGRect(x: center.x - blipR, y: center.y - blipR, width: blipR * 2, height: blipR * 2)),
            with: .color(typeColor.opacity(alpha * 0.8))
        )

        // Fading sonar ring expanding outward
        let expandR = blipR + CGFloat(sin(state.time * 2) * 8 * zoom)
        let ringAlpha = alpha * max(0, 1.0 - (expandR - blipR) / (8 * zoom))
        context.stroke(
            Circle().path(in: CGRect(x: center.x - expandR, y: center.y - expandR, width: expandR * 2, height: expandR * 2)),
            with: .color(typeColor.opacity(ringAlpha * 0.5)),
            lineWidth: 1.0
        )

        // Label below
        if zoom > 0.3 {
            let fontSize = max(7, 8 * zoom)
            let label = Text(discovery.label)
                .font(.system(size: fontSize, weight: .light, design: .monospaced))
                .foregroundStyle(typeColor.opacity(alpha * 0.7))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y + blipR + 4 * zoom), anchor: .top)
        }
    }
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount

        let cx = rect.midX, cy = rect.midY
        let radius = max(rect.width, rect.height) / 2
        let innerRadius = radius * 0.85

        let outerCircle = Circle().path(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
        let innerCircle = Circle().path(in: CGRect(x: cx - innerRadius, y: cy - innerRadius, width: innerRadius * 2, height: innerRadius * 2))

        context.fill(outerCircle, with: .color(accentColor.opacity(0.03 * dim)))

        let outerStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1.5)
            : StrokeStyle(lineWidth: 1, dash: [6, 4])
        context.stroke(outerCircle, with: .color(accentColor.opacity(0.2 * dim)), style: outerStyle)

        // Inner ring is always dashed
        context.stroke(innerCircle, with: .color(accentColor.opacity(0.12 * dim)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    // MARK: - Effects

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let t = state.theme; let zoom = state.camera.zoom
        let alpha = 1.0 - progress

        // Expanding concentric rings (like sonar ping)
        for i in 0..<3 {
            let delay = Double(i) * 0.15
            let ringProgress = max(0, progress - delay) / (1.0 - delay)
            guard ringProgress > 0 && ringProgress < 1 else { continue }
            let r = 60 * ringProgress * zoom
            let ringAlpha = alpha * (1.0 - ringProgress) * 0.5
            context.stroke(
                Circle().path(in: CGRect(x: screenPos.x - r, y: screenPos.y - r, width: r * 2, height: r * 2)),
                with: .color(t.secondary.opacity(ringAlpha)),
                lineWidth: 1.5
            )
        }
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        let s: CGFloat = 2 * state.camera.zoom
        context.fill(
            Circle().path(in: CGRect(x: position.x - s, y: position.y - s, width: s * 2, height: s * 2)),
            with: .color(state.theme.success.opacity(opacity))
        )
    }

    private func resolveClusterColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid] {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.secondary
    }
}
