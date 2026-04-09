import SwiftUI

// MARK: - Holograph Theme Renderer

/// Original sci-fi console: hexagonal nodes, bezier edges, comet particles, floating cards.
struct HolographRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2
                guard sx > -10 && sx < size.width + 10 && sy > -10 && sy < size.height + 10 else { continue }
                let twinkle = (sin(state.time * 2 + particle.brightness * 10) + 1) / 2 * 0.3 + 0.7
                let alpha = particle.brightness * twinkle
                let rect = CGRect(x: sx - particle.size / 2, y: sy - particle.size / 2, width: particle.size, height: particle.size)
                context.fill(Circle().path(in: rect), with: .color(t.starColor.opacity(alpha)))

                // Shooting star streak — only trigger for a few particles at any time
                if sin(state.time * 0.5 + particle.brightness * 7) > 0.95 {
                    let streakLen: CGFloat = 20 + particle.size * 4
                    let streakEnd = CGPoint(x: sx + streakLen * 0.7, y: sy - streakLen * 0.7)
                    let streakPath = Path { p in p.move(to: CGPoint(x: sx, y: sy)); p.addLine(to: streakEnd) }
                    let streakGrad = Gradient(stops: [
                        .init(color: t.starColor.opacity(alpha * 0.8), location: 0),
                        .init(color: t.starColor.opacity(0), location: 1)
                    ])
                    context.stroke(streakPath, with: .linearGradient(streakGrad, startPoint: CGPoint(x: sx, y: sy), endPoint: streakEnd), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
                }
            }
        }

        if state.showGrid && state.detail(0.2) {
            let cam = state.camera; let gridSize: CGFloat = 40 * cam.zoom
            guard gridSize > 8 else { return }
            let alpha = min((gridSize - 8) / 20, 0.15)
            let oX = cam.offset.x * cam.zoom + size.width / 2; let oY = cam.offset.y * cam.zoom + size.height / 2
            let cols = Int(size.width / gridSize) + 4; let rows = Int(size.height / (gridSize * 0.866)) + 4
            let startCol = Int(-oX / gridSize) - 2; let startRow = Int(-oY / (gridSize * 0.866)) - 2
            for row in startRow..<(startRow + rows) {
                for col in startCol..<(startCol + cols) {
                    let x = CGFloat(col) * gridSize + (row % 2 == 0 ? 0 : gridSize / 2) + oX
                    let y = CGFloat(row) * gridSize * 0.866 + oY
                    guard x > -gridSize && x < size.width + gridSize && y > -gridSize && y < size.height + gridSize else { continue }
                    context.stroke(BackgroundRenderer.hexagonPath(center: CGPoint(x: x, y: y), radius: gridSize * 0.5), with: .color(t.primary.opacity(alpha)), lineWidth: 0.5)
                }
            }
        }

        if state.detail(0.4) {
            guard let activeAgent = state.agents.values.first(where: { $0.isActive }) ?? state.agents.values.first else { return }
            let screenPos = state.camera.worldToScreen(activeAgent.position, viewSize: size)
            let radius: CGFloat = 300
            let grad = Gradient(stops: [.init(color: t.spotlightColor.opacity(0.15), location: 0), .init(color: .clear, location: 1)])
            context.fill(Circle().path(in: CGRect(x: screenPos.x - radius, y: screenPos.y - radius, width: radius * 2, height: radius * 2)),
                         with: .radialGradient(grad, center: screenPos, startRadius: 0, endRadius: radius))
        }
    }

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let hexPath = BackgroundRenderer.hexagonPath(center: center, radius: radius)
        let clusterAccent = resolveClusterColor(agent: agent, state: state)

        // Glow
        if state.detail(0.2) {
            let glowR = radius * 1.8
            let glowA = agent.opacity * (agent.isActive ? 0.25 : 0.1)
            context.fill(Circle().path(in: CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2)), with: .color(clusterAccent.opacity(glowA)))
        }

        // Fill
        let fillGrad = Gradient(stops: [
            .init(color: t.agentFillTop.opacity(agent.opacity), location: 0),
            .init(color: t.agentFillBottom.opacity(agent.opacity), location: 1)
        ])
        context.fill(hexPath, with: .linearGradient(fillGrad, startPoint: CGPoint(x: center.x, y: center.y - radius), endPoint: CGPoint(x: center.x, y: center.y + radius)))

        // Border
        context.stroke(hexPath, with: .color(clusterAccent.opacity(agent.opacity * 0.8)), lineWidth: agent.isMain ? 2.5 : 1.5)

        // Holographic scanline shimmer — 3 semi-transparent lines moving upward
        if state.detail(0.2) {
            var scanCtx = context
            scanCtx.clipToLayer { ctx in
                ctx.fill(hexPath, with: .color(.white))
            }
            let hexTop = center.y - radius
            let hexHeight = radius * 2
            for i in 0..<3 {
                let phase = fmod(state.time * 0.6 + Double(i) * 0.33, 1.0)
                let lineY = hexTop + CGFloat(phase) * hexHeight
                let lineAlpha = agent.opacity * 0.15 * (1.0 - abs(phase - 0.5) * 2)
                let linePath = Path { p in
                    p.move(to: CGPoint(x: center.x - radius, y: lineY))
                    p.addLine(to: CGPoint(x: center.x + radius, y: lineY))
                }
                scanCtx.stroke(linePath, with: .color(clusterAccent.opacity(lineAlpha)), lineWidth: 1.0)
            }
        }

        // Spark icon
        if state.detail(0.2) {
            drawSpark(context: &context, center: center, radius: radius * 0.4, color: t.sparkColor, opacity: agent.opacity)
        }
    }

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let dx = target.x - source.x; let dy = target.y - source.y
        let dist = sqrt(dx * dx + dy * dy)
        let curv = min(dist * 0.2, 60)
        let nx = -dy / max(dist, 1) * curv; let ny = dx / max(dist, 1) * curv
        let c1 = CGPoint(x: source.x + dx * 0.33 + nx, y: source.y + dy * 0.33 + ny)
        let c2 = CGPoint(x: source.x + dx * 0.66 + nx, y: source.y + dy * 0.66 + ny)
        let path = Path { p in p.move(to: source); p.addCurve(to: target, control1: c1, control2: c2) }
        let w: CGFloat = (edge.type == .parentChild ? 2.5 : 1.5) * state.camera.zoom
        let a = edge.opacity * (edge.isActive ? 0.7 : 0.25)
        let c: Color = edge.type == .parentChild ? t.primary.opacity(a) : t.secondary.opacity(a)
        context.stroke(path, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round))
        if edge.isActive && state.detail(0.2) {
            context.stroke(path, with: .color(c.opacity(a * 0.3)), style: StrokeStyle(lineWidth: w * 3, lineCap: .round))
        }
    }

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom; let ps: CGFloat = 6 * zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch; case .return: color = t.particleReturn
        case .toolCall: color = t.particleToolCall; case .toolReturn: color = t.particleToolReturn
        }
        context.fill(Circle().path(in: CGRect(x: position.x - ps/2, y: position.y - ps/2, width: ps, height: ps)), with: .color(color.opacity(particle.opacity)))
        context.fill(Circle().path(in: CGRect(x: position.x - ps, y: position.y - ps, width: ps*2, height: ps*2)), with: .color(color.opacity(particle.opacity * 0.3)))
    }

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let fontSize = max(8, 10 * zoom); let padding: CGFloat = 6 * zoom
        let cardWidth: CGFloat = 140 * zoom; let cardHeight: CGFloat = 44 * zoom

        let rect = CGRect(x: center.x - cardWidth / 2, y: center.y - cardHeight / 2, width: cardWidth, height: cardHeight)

        let pulseAlpha: Double = tool.state == .running ? 0.7 + sin(tool.pulsePhase) * 0.3 : 1.0
        let alpha = tool.opacity * pulseAlpha

        let bgColor: Color
        let borderColor: Color
        switch tool.state {
        case .running: bgColor = t.toolRunningBg; borderColor = t.secondary
        case .complete: bgColor = t.toolCompleteBg; borderColor = t.success
        case .error:   bgColor = t.toolErrorBg; borderColor = t.error
        }

        let cornerRadius = 6 * zoom
        let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
        context.fill(roundedRect.path(in: rect), with: .color(bgColor.opacity(alpha * 0.9)))

        // Pulsing border when running
        let borderWidth: CGFloat = tool.state == .running ? 1.5 + CGFloat(sin(tool.pulsePhase)) * 0.5 : 1.0
        context.stroke(roundedRect.path(in: rect), with: .color(borderColor.opacity(alpha * 0.7)), lineWidth: borderWidth)

        // Tool name
        let nameText = Text(tool.name).font(.system(size: fontSize, weight: .semibold, design: .monospaced)).foregroundStyle(borderColor.opacity(alpha))
        context.draw(context.resolve(nameText), at: CGPoint(x: rect.minX + padding, y: rect.midY), anchor: .leading)
    }

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = discovery.opacity
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: t)

        // Hexagonal badge (matching agent hexagons)
        let badgeRadius: CGFloat = 18 * zoom
        let badgeCenterX = center.x - 50 * zoom
        let badgeCenter = CGPoint(x: badgeCenterX, y: center.y)
        let hexPath = BackgroundRenderer.hexagonPath(center: badgeCenter, radius: badgeRadius)
        context.fill(hexPath, with: .color(t.agentFillBottom.opacity(alpha * 0.8)))
        context.stroke(hexPath, with: .color(typeColor.opacity(alpha * 0.7)), lineWidth: 1.5)

        // Colored left border stripe
        let stripeWidth: CGFloat = 3 * zoom
        let stripeHeight: CGFloat = badgeRadius * 2
        let stripeRect = CGRect(x: badgeCenterX + badgeRadius + 4 * zoom, y: center.y - stripeHeight / 2, width: stripeWidth, height: stripeHeight)
        context.fill(Path(roundedRect: stripeRect, cornerRadius: stripeWidth / 2), with: .color(typeColor.opacity(alpha)))

        // Label text
        let fontSize = max(7, 9 * zoom)
        let labelText = Text(discovery.label).font(.system(size: fontSize, weight: .semibold, design: .monospaced)).foregroundStyle(typeColor.opacity(alpha * 0.9))
        let labelX = stripeRect.maxX + 4 * zoom
        context.draw(context.resolve(labelText), at: CGPoint(x: labelX, y: center.y), anchor: .leading)
    }

    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount
        ClusterRenderer.drawDefaultCluster(context: &context, cluster: cluster, rect: rect, accentColor: accentColor, dim: dim, zoom: state.camera.zoom)
    }

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let alpha = 1.0 - progress
        for seg in effect.segments {
            let length = seg.length * progress * state.camera.zoom
            let path = Path { p in p.move(to: screenPos); p.addLine(to: CGPoint(x: screenPos.x + cos(seg.angle) * length, y: screenPos.y + sin(seg.angle) * length)) }
            context.stroke(path, with: .color(state.theme.primary.opacity(alpha)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        let s: CGFloat = 3 * state.camera.zoom
        context.fill(Circle().path(in: CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)), with: .color(state.theme.success.opacity(opacity)))
    }

    // MARK: - Helpers

    private func drawSpark(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        for i in 0..<4 {
            let angle = Double(i) * (.pi / 4)
            let path = Path { p in
                p.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.2, y: center.y + sin(angle) * radius * 0.2))
                p.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                p.move(to: CGPoint(x: center.x + cos(angle + .pi) * radius * 0.2, y: center.y + sin(angle + .pi) * radius * 0.2))
                p.addLine(to: CGPoint(x: center.x + cos(angle + .pi) * radius, y: center.y + sin(angle + .pi) * radius))
            }
            context.stroke(path, with: .color(color.opacity(opacity * 0.8)), style: StrokeStyle(lineWidth: max(1, radius * 0.15), lineCap: .round))
        }
        let d = radius * 0.3
        context.fill(Circle().path(in: CGRect(x: center.x - d/2, y: center.y - d/2, width: d, height: d)), with: .color(color.opacity(opacity)))
    }

    private func resolveClusterColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid] {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.primary
    }
}
