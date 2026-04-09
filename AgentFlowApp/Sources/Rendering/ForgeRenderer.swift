import SwiftUI

// MARK: - Forge Theme Renderer

/// Industrial mechanical hologram: stacked cylinder coils with concentric rings,
/// pipe-style edges, 3D perspective wireframe platform grid, amber/orange on black.
struct ForgeRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        // Grid toggle: 3D perspective wireframe platform
        if state.showGrid && state.detail(0.2) {
            drawPerspectiveGrid(context: &context, size: size, state: state)
        }

        // Scattered sparks/embers
        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2
                guard sx > -5 && sx < size.width + 5 && sy > -5 && sy < size.height + 5 else { continue }
                let flicker = (sin(state.time * 5 + particle.brightness * 15) + 1) / 2 * 0.5 + 0.5
                let alpha = particle.brightness * flicker * 0.4
                let s = particle.size * 0.7
                // Orange-tinted sparks
                context.fill(Circle().path(in: CGRect(x: sx - s/2, y: sy - s/2, width: s, height: s)),
                             with: .color(t.starColor.opacity(alpha)))
            }
        }

        // Warm industrial glow
        if state.detail(0.4) {
            guard let active = state.agents.values.first(where: { $0.isActive }) ?? state.agents.values.first else { return }
            let sp = state.camera.worldToScreen(active.position, viewSize: size)
            let r: CGFloat = 350
            let grad = Gradient(stops: [
                .init(color: t.spotlightColor.opacity(0.1), location: 0),
                .init(color: t.secondary.opacity(0.03), location: 0.5),
                .init(color: .clear, location: 1)
            ])
            context.fill(Circle().path(in: CGRect(x: sp.x - r, y: sp.y - r, width: r*2, height: r*2)),
                         with: .radialGradient(grad, center: sp, startRadius: 0, endRadius: r))
        }
    }

    // MARK: - 3D Perspective Wireframe Platform

    private func drawPerspectiveGrid(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme; let cam = state.camera
        let gridSize: CGFloat = 50 * cam.zoom
        guard gridSize > 6 else { return }

        let oX = cam.offset.x * cam.zoom + size.width / 2
        let oY = cam.offset.y * cam.zoom + size.height / 2
        let cols = Int(size.width / gridSize) + 6; let rows = Int(size.height / gridSize) + 6
        let startCol = Int(-oX / gridSize) - 3; let startRow = Int(-oY / gridSize) - 3

        // Perspective transform: Y lines converge toward a vanishing point above center
        let vanishY: CGFloat = -size.height * 0.5
        let perspStrength: CGFloat = 0.15

        func perspPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let normalY = (y - size.height / 2) / size.height
            let squeeze = 1.0 - normalY * perspStrength
            let px = size.width / 2 + (x - size.width / 2) * squeeze
            let py = size.height / 2 + (y - size.height / 2) * (1.0 + normalY * perspStrength * 0.3)
            return CGPoint(x: px, y: py)
        }

        // Horizontal lines (receding into distance)
        for row in startRow..<(startRow + rows) {
            let baseY = CGFloat(row) * gridSize + oY
            let linePath = Path { p in
                for col in startCol..<(startCol + cols + 1) {
                    let baseX = CGFloat(col) * gridSize + oX
                    let pt = perspPoint(baseX, baseY)
                    if col == startCol { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            let distFromCenter = abs(baseY - size.height / 2) / size.height
            let alpha = 0.08 * max(0, 1.0 - distFromCenter * 1.5)
            context.stroke(linePath, with: .color(t.primary.opacity(Double(alpha))), lineWidth: 0.5)
        }

        // Vertical lines (converging upward)
        for col in startCol..<(startCol + cols) {
            let baseX = CGFloat(col) * gridSize + oX
            let linePath = Path { p in
                for row in startRow..<(startRow + rows + 1) {
                    let baseY = CGFloat(row) * gridSize + oY
                    let pt = perspPoint(baseX, baseY)
                    if row == startRow { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            let distFromCenter = abs(baseX - size.width / 2) / size.width
            let alpha = 0.08 * max(0, 1.0 - distFromCenter * 1.5)
            context.stroke(linePath, with: .color(t.primary.opacity(Double(alpha))), lineWidth: 0.5)
        }

        // Platform border frame (bright orange rectangle with chevrons)
        let frameInset: CGFloat = 60
        let frameRect = CGRect(x: frameInset, y: frameInset, width: size.width - frameInset * 2, height: size.height - frameInset * 2)
        let tl = perspPoint(frameRect.minX, frameRect.minY)
        let tr = perspPoint(frameRect.maxX, frameRect.minY)
        let bl = perspPoint(frameRect.minX, frameRect.maxY)
        let br = perspPoint(frameRect.maxX, frameRect.maxY)
        let framePath = Path { p in
            p.move(to: tl); p.addLine(to: tr); p.addLine(to: br); p.addLine(to: bl); p.closeSubpath()
        }
        context.stroke(framePath, with: .color(t.primary.opacity(0.1)), lineWidth: 1)

        // Chevron markers at bottom center
        let chevronY = bl.y - 15
        let chevronX = (bl.x + br.x) / 2
        for i in 0..<3 {
            let offset = CGFloat(i - 1) * 20
            let chev = Path { p in
                p.move(to: CGPoint(x: chevronX + offset - 6, y: chevronY))
                p.addLine(to: CGPoint(x: chevronX + offset, y: chevronY - 5))
                p.addLine(to: CGPoint(x: chevronX + offset + 6, y: chevronY))
            }
            context.stroke(chev, with: .color(t.primary.opacity(0.15)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Agent: Stacked Cylinder Coil

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let accent = resolveClusterColor(agent: agent, state: state)

        // Warm glow
        if state.detail(0.2) {
            let glowR = radius * 2.2
            let glowA = agent.opacity * (agent.isActive ? 0.2 : 0.06)
            let grad = Gradient(stops: [
                .init(color: accent.opacity(glowA), location: 0),
                .init(color: t.secondary.opacity(glowA * 0.3), location: 0.6),
                .init(color: .clear, location: 1)
            ])
            context.fill(Circle().path(in: CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR*2, height: glowR*2)),
                         with: .radialGradient(grad, center: center, startRadius: 0, endRadius: glowR))
        }

        // Stacked cylinder levels (3 for main, 2 for sub)
        let levels = agent.isMain ? 3 : 2
        let levelHeight: CGFloat = radius * 0.4
        let baseY = center.y + CGFloat(levels - 1) * levelHeight * 0.5

        for level in 0..<levels {
            let ly = baseY - CGFloat(level) * levelHeight
            let levelScale: CGFloat = 1.0 - CGFloat(level) * 0.12  // slightly narrower higher up
            let cylW = radius * 1.4 * levelScale
            let cylH = radius * 0.35

            // Cylinder body (two horizontal lines + connecting verticals)
            let topEllipseRect = CGRect(x: center.x - cylW, y: ly - cylH, width: cylW * 2, height: cylH)
            let botEllipseRect = CGRect(x: center.x - cylW, y: ly, width: cylW * 2, height: cylH)

            // Side walls
            let leftWall = Path { p in
                p.move(to: CGPoint(x: center.x - cylW, y: ly - cylH / 2))
                p.addLine(to: CGPoint(x: center.x - cylW, y: ly + cylH / 2))
            }
            let rightWall = Path { p in
                p.move(to: CGPoint(x: center.x + cylW, y: ly - cylH / 2))
                p.addLine(to: CGPoint(x: center.x + cylW, y: ly + cylH / 2))
            }

            let wallAlpha = agent.opacity * 0.3
            context.stroke(leftWall, with: .color(accent.opacity(wallAlpha)), lineWidth: 1)
            context.stroke(rightWall, with: .color(accent.opacity(wallAlpha)), lineWidth: 1)

            // Bottom ellipse (darker)
            context.stroke(Ellipse().path(in: botEllipseRect), with: .color(accent.opacity(agent.opacity * 0.2)), lineWidth: 0.8)

            // Fill the cylinder face
            let fillGrad = Gradient(stops: [
                .init(color: t.agentFillTop.opacity(agent.opacity * 1.5), location: 0),
                .init(color: t.agentFillBottom.opacity(agent.opacity), location: 1)
            ])
            context.fill(Ellipse().path(in: topEllipseRect),
                         with: .linearGradient(fillGrad, startPoint: CGPoint(x: center.x, y: topEllipseRect.minY), endPoint: CGPoint(x: center.x, y: topEllipseRect.maxY)))

            // Top ellipse (bright) — topmost cylinder pulses brighter
            let topStrokeOpacity: Double
            if level == levels - 1 {
                topStrokeOpacity = agent.opacity * (0.6 + sin(state.time * 1.5) * 0.2)
            } else {
                topStrokeOpacity = agent.opacity * 0.6
            }
            context.stroke(Ellipse().path(in: topEllipseRect), with: .color(accent.opacity(topStrokeOpacity)),
                           lineWidth: level == levels - 1 ? 1.5 : 0.8)
        }

        // Concentric rings around the stack (rotating)
        if state.detail(0.2) {
            let ringConfigs: [(r: CGFloat, speed: Double, segments: Int)] = [
                (radius * 1.6, 0.4, 20),
                (radius * 1.9, -0.25, 16),
            ]
            for cfg in ringConfigs {
                let ringY = center.y
                let ringW = cfg.r; let ringH = cfg.r * 0.3
                let ringRect = CGRect(x: center.x - ringW, y: ringY - ringH, width: ringW * 2, height: ringH * 2)

                // Draw as dotted ring (dot pattern like the reference)
                let dotCount = cfg.segments
                for d in 0..<dotCount {
                    let angle = CGFloat(d) * (2 * .pi / CGFloat(dotCount)) + CGFloat(state.time * cfg.speed)
                    let dx = center.x + CoreGraphics.cos(angle) * ringW
                    let dy = ringY + CoreGraphics.sin(angle) * ringH
                    let dotR: CGFloat = 1.5
                    context.fill(Circle().path(in: CGRect(x: dx - dotR, y: dy - dotR, width: dotR * 2, height: dotR * 2)),
                                 with: .color(accent.opacity(agent.opacity * 0.4)))
                }

                // Thin ring outline
                context.stroke(Ellipse().path(in: ringRect), with: .color(accent.opacity(agent.opacity * 0.12)), lineWidth: 0.5)
            }
        }

        // Red accent ring (like in the reference) for active agents
        if agent.isActive && state.detail(0.4) {
            let redR = radius * 1.3; let redH = redR * 0.25
            let redRect = CGRect(x: center.x - redR, y: center.y - levelHeight - redH, width: redR * 2, height: redH * 2)
            context.stroke(Ellipse().path(in: redRect), with: .color(t.error.opacity(agent.opacity * 0.3)), lineWidth: 1)
        }

        // Rising sparks from active agents
        if agent.isActive && state.detail(0.4) {
            let sparkZoom = state.camera.zoom
            let sparkBaseY = center.y - radius
            for i in 0..<3 {
                let phase = (state.time * 20).truncatingRemainder(dividingBy: 30) * Double(sparkZoom)
                let sy = sparkBaseY - CGFloat(i * 8) * sparkZoom - CGFloat(phase)
                let fadeDistance = abs(sy - sparkBaseY) / (30 * sparkZoom)
                let sparkAlpha = agent.opacity * max(0, 0.7 - Double(fadeDistance))
                let sparkR: CGFloat = 1.5 * sparkZoom
                context.fill(
                    Circle().path(in: CGRect(x: center.x - sparkR, y: sy - sparkR, width: sparkR * 2, height: sparkR * 2)),
                    with: .color(t.primary.opacity(sparkAlpha))
                )
            }
        }

        // Data readout
        if state.detail(0.4) && state.camera.zoom > 0.4 {
            let label = Text(String(format: "T-%02d", abs(agent.id.hashValue % 100)))
                .font(.system(size: max(7, 8 * state.camera.zoom), weight: .regular, design: .monospaced))
                .foregroundStyle(accent.opacity(agent.opacity * 0.5))
            context.draw(context.resolve(label),
                         at: CGPoint(x: center.x, y: center.y + radius + 8), anchor: .top)
        }
    }

    // MARK: - Edges: Industrial Pipe Connectors

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let dx = target.x - source.x; let dy = target.y - source.y
        let dist = sqrt(dx * dx + dy * dy)

        // Pipe-style: slight curve with parallel lines (double stroke for pipe feel)
        let curv = min(dist * 0.15, 40)
        let nx = -dy / max(dist, 1) * curv; let ny = dx / max(dist, 1) * curv
        let c1 = CGPoint(x: source.x + dx * 0.33 + nx, y: source.y + dy * 0.33 + ny)
        let c2 = CGPoint(x: source.x + dx * 0.66 + nx * 0.5, y: source.y + dy * 0.66 + ny * 0.5)
        let path = Path { p in p.move(to: source); p.addCurve(to: target, control1: c1, control2: c2) }

        let w: CGFloat = (edge.type == .parentChild ? 2.0 : 1.2) * state.camera.zoom
        let a = edge.opacity * (edge.isActive ? 0.5 : 0.15)
        let color = edge.type == .parentChild ? t.primary : t.secondary

        // Outer pipe wall
        context.stroke(path, with: .color(color.opacity(a * 0.4)), style: StrokeStyle(lineWidth: w * 2.5, lineCap: .round))
        // Inner bright core
        context.stroke(path, with: .color(color.opacity(a)), style: StrokeStyle(lineWidth: w, lineCap: .round))

        // Measurement ticks along edge
        if state.detail(0.4) {
            let zoom = state.camera.zoom
            for i in 1..<4 {
                let et = Double(i) * 0.25
                let mt = 1 - et; let mt2 = mt * mt; let mt3 = mt2 * mt
                let et2 = et * et; let et3 = et2 * et
                let px = mt3 * source.x + 3 * mt2 * et * c1.x + 3 * mt * et2 * c2.x + et3 * target.x
                let py = mt3 * source.y + 3 * mt2 * et * c1.y + 3 * mt * et2 * c2.y + et3 * target.y
                let tickLen: CGFloat = 4 * zoom
                let perpA = atan2(dy, dx) + .pi / 2
                let tick = Path { p in
                    p.move(to: CGPoint(x: px - CoreGraphics.cos(perpA) * tickLen, y: py - CoreGraphics.sin(perpA) * tickLen))
                    p.addLine(to: CGPoint(x: px + CoreGraphics.cos(perpA) * tickLen, y: py + CoreGraphics.sin(perpA) * tickLen))
                }
                context.stroke(tick, with: .color(color.opacity(a * 0.4)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Particles: Bright Sparks

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch; case .return: color = t.particleReturn
        case .toolCall: color = t.particleToolCall; case .toolReturn: color = t.particleToolReturn
        }

        // Hot spark with radial glow
        let s: CGFloat = 4 * zoom
        let glowR: CGFloat = 8 * zoom
        let grad = Gradient(stops: [
            .init(color: color.opacity(particle.opacity * 0.5), location: 0),
            .init(color: t.secondary.opacity(particle.opacity * 0.15), location: 0.5),
            .init(color: .clear, location: 1)
        ])
        context.fill(Circle().path(in: CGRect(x: position.x - glowR, y: position.y - glowR, width: glowR*2, height: glowR*2)),
                     with: .radialGradient(grad, center: position, startRadius: 0, endRadius: glowR))
        context.fill(Circle().path(in: CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
                     with: .color(color.opacity(particle.opacity)))
    }

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = tool.opacity
        let gaugeR: CGFloat = 18 * zoom

        // 270-degree arc (pressure gauge) — thick amber arc
        let startAngle = Angle.degrees(135)  // bottom-left
        let endAngle = Angle.degrees(45)     // bottom-right (270 deg sweep)
        let arcPath = Path { p in
            p.addArc(center: center, radius: gaugeR, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        }
        context.stroke(arcPath, with: .color(t.primary.opacity(alpha * 0.6)),
                       style: StrokeStyle(lineWidth: 3 * zoom, lineCap: .round))

        // Tick marks at 0, 90, 180, 270 degrees along the gauge arc
        let tickAngles: [Angle] = [.degrees(135), .degrees(225), .degrees(315), .degrees(45)]
        for tickAngle in tickAngles {
            let innerR = gaugeR - 4 * zoom
            let outerR = gaugeR + 3 * zoom
            let cosA = CoreGraphics.cos(tickAngle.radians)
            let sinA = CoreGraphics.sin(tickAngle.radians)
            let tick = Path { p in
                p.move(to: CGPoint(x: center.x + cosA * innerR, y: center.y + sinA * innerR))
                p.addLine(to: CGPoint(x: center.x + cosA * outerR, y: center.y + sinA * outerR))
            }
            context.stroke(tick, with: .color(t.primary.opacity(alpha * 0.4)), lineWidth: 1)
        }

        // Needle — animated sweep when running, pointing to ~80% when complete
        let needleAngle: Angle
        switch tool.state {
        case .running:
            // Animated sweep across the 270-degree range
            let sweep = (state.time * 1.5).truncatingRemainder(dividingBy: 1.0)
            needleAngle = .degrees(135 + sweep * 270)
        case .complete:
            needleAngle = .degrees(135 + 0.8 * 270) // ~80%
        case .error:
            needleAngle = .degrees(135 + 0.15 * 270) // low position for error
        }
        let needleLen = gaugeR * 0.85
        let needlePath = Path { p in
            p.move(to: center)
            p.addLine(to: CGPoint(
                x: center.x + CoreGraphics.cos(needleAngle.radians) * needleLen,
                y: center.y + CoreGraphics.sin(needleAngle.radians) * needleLen
            ))
        }
        context.stroke(needlePath, with: .color(t.secondary.opacity(alpha * 0.8)),
                       style: StrokeStyle(lineWidth: 1.5 * zoom, lineCap: .round))

        // Center pivot dot
        let pivotR: CGFloat = 2 * zoom
        context.fill(Circle().path(in: CGRect(x: center.x - pivotR, y: center.y - pivotR, width: pivotR * 2, height: pivotR * 2)),
                     with: .color(t.primary.opacity(alpha * 0.7)))

        // Tool name below
        if state.detail(0.6) && zoom > 0.3 {
            let label = Text(tool.name)
                .font(.system(size: max(6, 7 * zoom), weight: .medium, design: .monospaced))
                .foregroundStyle(t.primary.opacity(alpha * 0.7))
            context.draw(context.resolve(label),
                         at: CGPoint(x: center.x, y: center.y + gaugeR + 6 * zoom), anchor: .top)
        }
    }

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = discovery.opacity
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: t)

        // Industrial plate: rectangle with bright amber top border
        let plateW: CGFloat = 40 * zoom; let plateH: CGFloat = 20 * zoom
        let plateRect = CGRect(x: center.x - plateW / 2, y: center.y - plateH / 2, width: plateW, height: plateH)

        // Darker fill
        context.fill(Path(plateRect), with: .color(t.agentFillBottom.opacity(alpha * 0.8)))

        // Full border (subtle)
        context.stroke(Path(plateRect), with: .color(t.primary.opacity(alpha * 0.3)), lineWidth: 0.5)

        // Bright amber top border (3px)
        let topBorder = Path { p in
            p.move(to: CGPoint(x: plateRect.minX, y: plateRect.minY))
            p.addLine(to: CGPoint(x: plateRect.maxX, y: plateRect.minY))
        }
        context.stroke(topBorder, with: .color(t.primary.opacity(alpha * 0.8)), lineWidth: 3 * zoom)

        // Rivet dots at two top corners
        let rivetR: CGFloat = 2 * zoom
        let rivetY = plateRect.minY + 3 * zoom
        context.fill(Circle().path(in: CGRect(x: plateRect.minX + 2 * zoom - rivetR, y: rivetY - rivetR, width: rivetR * 2, height: rivetR * 2)),
                     with: .color(t.primary.opacity(alpha * 0.5)))
        context.fill(Circle().path(in: CGRect(x: plateRect.maxX - 2 * zoom - rivetR, y: rivetY - rivetR, width: rivetR * 2, height: rivetR * 2)),
                     with: .color(t.primary.opacity(alpha * 0.5)))

        // Discovery label as monospace text inside
        if state.detail(0.6) && zoom > 0.3 {
            let label = Text(discovery.label)
                .font(.system(size: max(5, 7 * zoom), weight: .medium, design: .monospaced))
                .foregroundStyle(typeColor.opacity(alpha * 0.8))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y + 2 * zoom), anchor: .center)
        }
    }
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount

        // Trapezoid: top edge narrower than bottom (perspective effect)
        let inset = rect.width * 0.1
        var trap = Path()
        trap.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))     // top-left
        trap.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))  // top-right
        trap.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))          // bottom-right
        trap.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))          // bottom-left
        trap.closeSubpath()

        context.fill(trap, with: .color(accentColor.opacity(0.03 * dim)))

        let strokeStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1.5)
            : StrokeStyle(lineWidth: 1, dash: [6, 4])
        context.stroke(trap, with: .color(accentColor.opacity(0.2 * dim)), style: strokeStyle)
    }

    // MARK: - Effects

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let t = state.theme; let zoom = state.camera.zoom; let alpha = 1.0 - progress

        // Forge ignition: expanding rings + rising sparks
        let r1 = 30 * progress * zoom; let r2 = 50 * progress * zoom
        let ellH1 = r1 * 0.3; let ellH2 = r2 * 0.3
        context.stroke(Ellipse().path(in: CGRect(x: screenPos.x - r1, y: screenPos.y - ellH1, width: r1*2, height: ellH1*2)),
                       with: .color(t.primary.opacity(alpha * 0.5)), lineWidth: 1.5)
        context.stroke(Ellipse().path(in: CGRect(x: screenPos.x - r2, y: screenPos.y - ellH2, width: r2*2, height: ellH2*2)),
                       with: .color(t.secondary.opacity(alpha * 0.3)), lineWidth: 1)

        // Rising sparks
        for i in 0..<4 {
            let sparkAngle = Double(i) * .pi / 2 + progress * 3
            let sparkDist = 20 * progress * Double(zoom)
            let sx = screenPos.x + CGFloat(cos(sparkAngle) * sparkDist)
            let sy = screenPos.y - CGFloat(progress * 30 * Double(zoom)) + CGFloat(sin(sparkAngle) * sparkDist * 0.3)
            let sr: CGFloat = 2 * zoom * CGFloat(alpha)
            context.fill(Circle().path(in: CGRect(x: sx - sr, y: sy - sr, width: sr*2, height: sr*2)),
                         with: .color(t.secondary.opacity(alpha * 0.6)))
        }
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        let s: CGFloat = 2 * state.camera.zoom
        context.fill(Circle().path(in: CGRect(x: position.x - s, y: position.y - s, width: s*2, height: s*2)),
                     with: .color(state.theme.secondary.opacity(opacity)))
    }

    private func resolveClusterColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid] {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.primary
    }
}
