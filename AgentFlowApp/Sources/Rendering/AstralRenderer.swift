import SwiftUI

// MARK: - Astral Theme Renderer

/// Deep space orrery with 3D spatial feel: planet spheres with multiple tilted orbital rings,
/// wide gravitational arc edges, satellite particles, curved space-warp grid, nebula clouds.
struct AstralRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        // Grid toggle: Curved space-warp grid — a perspective-distorted grid that curves toward a gravity well
        if state.showGrid && state.detail(0.2) {
            drawWarpGrid(context: &context, size: size, state: state)
        }

        // Multi-layer starfield with depth-based size and flares
        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2
                guard sx > -10 && sx < size.width + 10 && sy > -10 && sy < size.height + 10 else { continue }
                let twinkle = (sin(state.time * 3 + particle.brightness * 12) + 1) / 2 * 0.4 + 0.6
                let alpha = particle.brightness * twinkle
                let s = particle.size * (particle.depth > 0.7 ? 1.8 : 0.7)
                context.fill(Circle().path(in: CGRect(x: sx - s/2, y: sy - s/2, width: s, height: s)), with: .color(t.starColor.opacity(alpha)))
                // Cross flare on bright stars
                if particle.brightness > 0.5 && state.detail(0.4) {
                    let flareLen = s * 3
                    // 4-point flare with rotation
                    let rot = state.time * 0.1 + particle.brightness * 5
                    for f in 0..<4 {
                        let fa = rot + Double(f) * .pi / 4
                        let fp = Path { p in
                            p.move(to: CGPoint(x: sx, y: sy))
                            p.addLine(to: CGPoint(x: sx + cos(fa) * Double(flareLen), y: sy + sin(fa) * Double(flareLen)))
                        }
                        context.stroke(fp, with: .color(t.starColor.opacity(alpha * 0.2)), lineWidth: 0.4)
                    }
                }
            }
        }

        // Nebula clouds (multiple layered gradients)
        if state.detail(0.4) {
            guard let active = state.agents.values.first(where: { $0.isActive }) ?? state.agents.values.first else { return }
            let sp = state.camera.worldToScreen(active.position, viewSize: size)
            let clouds: [(Color, CGFloat, Double, CGFloat)] = [
                (t.spotlightColor, 0, 0.3, 300),
                (Color(red: 0.15, green: 0.05, blue: 0.3), 25, 0.2, 250),
                (Color(red: 0.05, green: 0.12, blue: 0.25), -20, 0.4, 320),
            ]
            for (c, offset, freq, radius) in clouds {
                let drift = sin(state.time * freq) * 15
                let center = CGPoint(x: sp.x + offset + drift, y: sp.y + offset * 0.4 + drift * 0.6)
                let grad = Gradient(stops: [.init(color: c.opacity(0.08), location: 0), .init(color: .clear, location: 1)])
                context.fill(Circle().path(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius*2, height: radius*2)),
                             with: .radialGradient(grad, center: center, startRadius: 0, endRadius: radius))
            }
        }
    }

    // MARK: - Curved Space-Warp Grid

    private func drawWarpGrid(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme; let cam = state.camera
        let gridSize: CGFloat = 60 * cam.zoom
        guard gridSize > 8 else { return }

        let oX = cam.offset.x * cam.zoom + size.width / 2
        let oY = cam.offset.y * cam.zoom + size.height / 2
        let cols = Int(size.width / gridSize) + 6; let rows = Int(size.height / gridSize) + 6
        let startCol = Int(-oX / gridSize) - 3; let startRow = Int(-oY / gridSize) - 3

        // Find gravity well center (active agent position on screen)
        let wellCenter: CGPoint
        if let active = state.agents.values.first(where: { $0.isActive }) ?? state.agents.values.first {
            wellCenter = cam.worldToScreen(active.position, viewSize: size)
        } else {
            wellCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let wellStrength: CGFloat = 40 * cam.zoom
        let wellRadius: CGFloat = 300 * cam.zoom

        // Compute warped grid positions
        func warpPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let dx = x - wellCenter.x; let dy = y - wellCenter.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < 1 { return CGPoint(x: x, y: y) }
            // Pull points toward well, stronger when closer
            let pull = wellStrength / (1 + dist / wellRadius)
            let nx = dx / dist; let ny = dy / dist
            return CGPoint(x: x - nx * pull, y: y - ny * pull)
        }

        // Draw warped horizontal curves
        for row in startRow..<(startRow + rows) {
            let baseY = CGFloat(row) * gridSize + oY
            let curvePath = Path { p in
                for col in startCol..<(startCol + cols + 1) {
                    let baseX = CGFloat(col) * gridSize + oX
                    let warped = warpPoint(baseX, baseY)
                    if col == startCol { p.move(to: warped) }
                    else { p.addLine(to: warped) }
                }
            }
            let distToWell = abs(baseY - wellCenter.y)
            let alpha = 0.06 * max(0, 1.0 - distToWell / (size.height * 0.7))
            context.stroke(curvePath, with: .color(t.primary.opacity(Double(alpha))), lineWidth: 0.5)
        }

        // Draw warped vertical curves
        for col in startCol..<(startCol + cols) {
            let baseX = CGFloat(col) * gridSize + oX
            let curvePath = Path { p in
                for row in startRow..<(startRow + rows + 1) {
                    let baseY = CGFloat(row) * gridSize + oY
                    let warped = warpPoint(baseX, baseY)
                    if row == startRow { p.move(to: warped) }
                    else { p.addLine(to: warped) }
                }
            }
            let distToWell = abs(baseX - wellCenter.x)
            let alpha = 0.06 * max(0, 1.0 - distToWell / (size.width * 0.7))
            context.stroke(curvePath, with: .color(t.primary.opacity(Double(alpha))), lineWidth: 0.5)
        }

        // Concentric warp rings around the gravity well
        for ring in 1..<6 {
            let r = CGFloat(ring) * 60 * cam.zoom
            let ringPath = Path { p in
                let segments = 36
                for s in 0...segments {
                    let angle = CGFloat(s) * (2 * .pi / CGFloat(segments))
                    let px = wellCenter.x + CoreGraphics.cos(angle) * r
                    let py = wellCenter.y + CoreGraphics.sin(angle) * r
                    let warped = warpPoint(px, py)
                    if s == 0 { p.move(to: warped) } else { p.addLine(to: warped) }
                }
            }
            let alpha = 0.04 * (1.0 - CGFloat(ring) / 6.0)
            context.stroke(ringPath, with: .color(t.secondary.opacity(Double(alpha))),
                           style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
        }
    }

    // MARK: - Agent: 3D Planet with Multiple Tilted Orbital Rings

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let accent = resolveClusterColor(agent: agent, state: state)

        // Glow
        if state.detail(0.2) {
            let glowR = radius * 2.5; let glowA = agent.opacity * (agent.isActive ? 0.18 : 0.06)
            let glowGrad = Gradient(stops: [
                .init(color: accent.opacity(glowA), location: 0),
                .init(color: accent.opacity(glowA * 0.3), location: 0.5),
                .init(color: .clear, location: 1)
            ])
            context.fill(Circle().path(in: CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR*2, height: glowR*2)),
                         with: .radialGradient(glowGrad, center: center, startRadius: 0, endRadius: glowR))
        }

        // Planet sphere with 3D-style off-center highlight + shadow crescent
        let grad = Gradient(stops: [
            .init(color: t.agentFillTop.opacity(agent.opacity * 2.5), location: 0),
            .init(color: t.agentFillBottom.opacity(agent.opacity * 1.2), location: 0.5),
            .init(color: t.voidColor.opacity(agent.opacity * 0.8), location: 0.85),
            .init(color: t.voidColor.opacity(agent.opacity), location: 1)
        ])
        let highlight = CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3)
        context.fill(Circle().path(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius*2, height: radius*2)),
                     with: .radialGradient(grad, center: highlight, startRadius: 0, endRadius: radius * 1.4))

        // Atmospheric rim highlight
        context.stroke(Circle().path(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius*2, height: radius*2)),
                       with: .color(accent.opacity(agent.opacity * 0.4)), lineWidth: 1.5)
        // Thinner bright crescent on upper-left
        let crescentArc = Path { p in
            p.addArc(center: center, radius: radius - 1, startAngle: .degrees(200), endAngle: .degrees(320), clockwise: false)
        }
        context.stroke(crescentArc, with: .color(accent.opacity(agent.opacity * 0.25)), lineWidth: 2.5)

        // Atmospheric shimmer — faint pulsing haze around the planet
        if state.detail(0.2) {
            let shimmerR = radius * 1.15
            let shimmerAlpha = 0.05 * (1.0 + sin(state.time * 2)) * 0.5 * agent.opacity
            context.fill(
                Circle().path(in: CGRect(x: center.x - shimmerR, y: center.y - shimmerR, width: shimmerR * 2, height: shimmerR * 2)),
                with: .color(accent.opacity(shimmerAlpha))
            )
        }

        // Multiple tilted orbital rings (3D spatial effect)
        if state.detail(0.2) {
            let ringConfigs: [(widthMul: CGFloat, heightMul: CGFloat, speedMul: Double, dashOn: CGFloat, dashOff: CGFloat)] = agent.isMain
                ? [(2.6, 0.6, 0.25, 5, 3), (2.2, 0.9, -0.35, 3, 4), (3.0, 0.4, 0.15, 8, 4)]
                : [(2.4, 0.65, 0.3, 4, 3), (2.0, 0.85, -0.2, 3, 5)]

            for (i, cfg) in ringConfigs.enumerated() {
                let ringW = radius * cfg.widthMul; let ringH = radius * cfg.heightMul
                let ringAngle = Angle(radians: state.time * cfg.speedMul + Double(agent.id.hashValue % 100) * 0.1 + Double(i) * 0.8)
                var ctx2 = context
                ctx2.translateBy(x: center.x, y: center.y)
                ctx2.rotate(by: ringAngle)
                let ringRect = CGRect(x: -ringW/2, y: -ringH/2, width: ringW, height: ringH)
                let ringAlpha = agent.opacity * (0.2 - Double(i) * 0.04)
                ctx2.stroke(Ellipse().path(in: ringRect), with: .color(accent.opacity(ringAlpha)),
                            style: StrokeStyle(lineWidth: i == 0 ? 1.2 : 0.7, dash: [cfg.dashOn, cfg.dashOff]))

                // Small moon dot on the first ring
                if i == 0 && state.detail(0.4) {
                    let moonAngle = state.time * 0.8 + Double(agent.id.hashValue % 50)
                    let moonX = CoreGraphics.cos(CGFloat(moonAngle)) * ringW / 2
                    let moonY = CoreGraphics.sin(CGFloat(moonAngle)) * ringH / 2
                    let moonR: CGFloat = 2.5
                    ctx2.fill(Circle().path(in: CGRect(x: moonX - moonR, y: moonY - moonR, width: moonR*2, height: moonR*2)),
                              with: .color(accent.opacity(agent.opacity * 0.5)))
                }
            }

            // Token progress as a bright solid arc on the outermost ring
            if agent.tokensMax > 0 {
                let progress = min(Double(agent.tokensUsed) / Double(agent.tokensMax), 1.0)
                if progress > 0 {
                    let cfg = ringConfigs[0]
                    let ringW = radius * cfg.widthMul; let ringH = radius * cfg.heightMul
                    let ringAngle = Angle(radians: state.time * cfg.speedMul + Double(agent.id.hashValue % 100) * 0.1)
                    var ctx3 = context
                    ctx3.translateBy(x: center.x, y: center.y)
                    ctx3.rotate(by: ringAngle)
                    ctx3.scaleBy(x: 1, y: ringH / ringW)
                    let arcPath = Path { p in
                        p.addArc(center: .zero, radius: ringW / 2, startAngle: .degrees(0), endAngle: .degrees(360 * progress), clockwise: false)
                    }
                    let tokenColor = progress > 0.8 ? t.error : accent
                    ctx3.stroke(arcPath, with: .color(tokenColor.opacity(agent.opacity * 0.5)), lineWidth: 2)
                }
            }

            // Asteroid belt for main agents — tiny dots in an elliptical orbit
            if agent.isMain {
                let beltW = radius * 2.8
                let beltH = radius * 0.5
                let dotCount = 15
                let angleStep = 2.0 * Double.pi / Double(dotCount)
                for di in 0..<dotCount {
                    let angle = state.time * 0.1 + Double(di) * angleStep
                    let dx = CoreGraphics.cos(CGFloat(angle)) * beltW
                    let dy = CoreGraphics.sin(CGFloat(angle)) * beltH
                    let dotR: CGFloat = 1.5
                    let dotAlpha = agent.opacity * 0.35
                    context.fill(
                        Circle().path(in: CGRect(x: center.x + dx - dotR, y: center.y + dy - dotR, width: dotR * 2, height: dotR * 2)),
                        with: .color(accent.opacity(dotAlpha))
                    )
                }
            }
        }

        // Gas giant bands (latitude lines)
        if state.detail(0.4) {
            for i in 1..<4 {
                let bandY = center.y + radius * (CGFloat(i) / 4.0 * 2 - 1) * 0.8
                let bandHalfW = sqrt(max(0, radius * radius - (bandY - center.y) * (bandY - center.y)))
                if bandHalfW > 3 {
                    let band = Path { p in
                        p.move(to: CGPoint(x: center.x - bandHalfW, y: bandY))
                        // Slight curve for 3D effect
                        let curv: CGFloat = (bandY - center.y) * 0.15
                        p.addQuadCurve(to: CGPoint(x: center.x + bandHalfW, y: bandY),
                                       control: CGPoint(x: center.x, y: bandY + curv))
                    }
                    context.stroke(band, with: .color(t.sparkColor.opacity(agent.opacity * 0.1)), lineWidth: 0.5)
                }
            }
        }
    }

    // MARK: - Edges: Wide Gravitational Arcs with Spatial Depth

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let dx = target.x - source.x; let dy = target.y - source.y
        let dist = sqrt(dx * dx + dy * dy)

        // Wide parabolic gravitational arc
        let perpOffset = dist * 0.35
        let nx = -dy / max(dist, 1) * perpOffset; let ny = dx / max(dist, 1) * perpOffset
        let mid = CGPoint(x: (source.x + target.x) / 2 + nx, y: (source.y + target.y) / 2 + ny)
        let c1 = CGPoint(x: (source.x + mid.x) / 2 + nx * 0.3, y: (source.y + mid.y) / 2 + ny * 0.3)
        let c2 = CGPoint(x: (mid.x + target.x) / 2 + nx * 0.3, y: (mid.y + target.y) / 2 + ny * 0.3)
        let path = Path { p in p.move(to: source); p.addCurve(to: target, control1: c1, control2: c2) }

        let w: CGFloat = (edge.type == .parentChild ? 1.5 : 1.0) * state.camera.zoom
        let a = edge.opacity * (edge.isActive ? 0.5 : 0.15)
        let color = edge.type == .parentChild ? t.primary : t.secondary

        // Shadow/depth line (slightly offset, dimmer — gives 3D spatial depth)
        if state.detail(0.2) {
            let shadowPath = Path { p in
                p.move(to: CGPoint(x: source.x + 2, y: source.y + 2))
                p.addCurve(to: CGPoint(x: target.x + 2, y: target.y + 2),
                           control1: CGPoint(x: c1.x + 2, y: c1.y + 2),
                           control2: CGPoint(x: c2.x + 2, y: c2.y + 2))
            }
            context.stroke(shadowPath, with: .color(color.opacity(a * 0.15)), style: StrokeStyle(lineWidth: w * 1.5, lineCap: .round))
        }

        context.stroke(path, with: .color(color.opacity(a)), style: StrokeStyle(lineWidth: w, lineCap: .round))

        if edge.isActive && state.detail(0.2) {
            context.stroke(path, with: .color(color.opacity(a * 0.2)), style: StrokeStyle(lineWidth: w * 4, lineCap: .round))
        }
    }

    // MARK: - Particles: Satellites with Orbit Trail

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch; case .return: color = t.particleReturn
        case .toolCall: color = t.particleToolCall; case .toolReturn: color = t.particleToolReturn
        }

        let s: CGFloat = 5 * zoom

        // Glow halo
        let haloR = s * 2
        let grad = Gradient(stops: [.init(color: color.opacity(particle.opacity * 0.25), location: 0), .init(color: .clear, location: 1)])
        context.fill(Circle().path(in: CGRect(x: position.x - haloR, y: position.y - haloR, width: haloR*2, height: haloR*2)),
                     with: .radialGradient(grad, center: position, startRadius: 0, endRadius: haloR))

        // Satellite body
        context.fill(Circle().path(in: CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
                     with: .color(color.opacity(particle.opacity)))

        // Tilted mini orbit ring
        if state.detail(0.4) {
            let orbitR = s * 2; let orbitH = s * 0.8
            var ctx2 = context
            ctx2.translateBy(x: position.x, y: position.y)
            ctx2.rotate(by: Angle(radians: particle.progress * .pi * 2))
            ctx2.stroke(Ellipse().path(in: CGRect(x: -orbitR, y: -orbitH, width: orbitR*2, height: orbitH*2)),
                        with: .color(color.opacity(particle.opacity * 0.2)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }
    }

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = tool.opacity * (tool.state == .running ? 0.7 + sin(tool.pulsePhase) * 0.3 : 1.0)
        let halfSize: CGFloat = 20 * zoom

        // Tool state color
        let stateColor: Color
        switch tool.state {
        case .running:  stateColor = t.secondary
        case .complete: stateColor = t.success
        case .error:    stateColor = t.error
        }

        // Diamond / rhombus path (square rotated 45 degrees)
        var ctx2 = context
        ctx2.translateBy(x: center.x, y: center.y)
        if tool.state == .running {
            ctx2.rotate(by: Angle(radians: state.time * 0.5))
        }
        let diamond = Path { p in
            p.move(to: CGPoint(x: 0, y: -halfSize))
            p.addLine(to: CGPoint(x: halfSize, y: 0))
            p.addLine(to: CGPoint(x: 0, y: halfSize))
            p.addLine(to: CGPoint(x: -halfSize, y: 0))
            p.closeSubpath()
        }
        ctx2.fill(diamond, with: .color(t.primary.opacity(alpha * 0.3)))
        ctx2.stroke(diamond, with: .color(stateColor.opacity(alpha * 0.8)), lineWidth: 1.5)

        // Tool name text below the diamond
        let fontSize = max(7, 9 * zoom)
        let nameText = Text(tool.name)
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .foregroundStyle(stateColor.opacity(alpha))
        context.draw(context.resolve(nameText), at: CGPoint(x: center.x, y: center.y + halfSize + 6 * zoom), anchor: .top)
    }

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let alpha = discovery.opacity
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: state.theme)
        let outerRadius: CGFloat = 16 * zoom
        let innerRadius: CGFloat = outerRadius * 0.4

        // Twinkle: vary outer radius
        let twinkle = CGFloat(sin(state.time * 3 + Double(discovery.label.hashValue)) * 0.1)
        let outerR = outerRadius * (1.0 + twinkle)

        // 5-pointed star path: 10 points alternating outer/inner
        let starPath = Path { p in
            for i in 0..<10 {
                let angle = CGFloat(Double(i) * .pi / 5.0) - .pi / 2
                let r = i % 2 == 0 ? outerR : innerRadius
                let pt = CGPoint(x: center.x + CoreGraphics.cos(angle) * r,
                                 y: center.y + CoreGraphics.sin(angle) * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }

        context.fill(starPath, with: .color(typeColor.opacity(alpha * 0.5)))
        context.stroke(starPath, with: .color(typeColor.opacity(alpha * 0.8)), lineWidth: 1.2)

        // Label text below
        let fontSize = max(7, 9 * zoom)
        let labelText = Text(discovery.label)
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .foregroundStyle(typeColor.opacity(alpha * 0.9))
        context.draw(context.resolve(labelText), at: CGPoint(x: center.x, y: center.y + outerR + 6 * zoom), anchor: .top)
    }
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount

        let ellipsePath = Ellipse().path(in: rect)

        context.fill(ellipsePath, with: .color(accentColor.opacity(0.03 * dim)))

        let strokeStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1.5, dash: [10, 6])
            : StrokeStyle(lineWidth: 1, dash: [6, 4])
        context.stroke(ellipsePath, with: .color(accentColor.opacity(0.2 * dim)), style: strokeStyle)
    }

    // MARK: - Effects

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let t = state.theme; let zoom = state.camera.zoom; let alpha = 1.0 - progress

        // Nova burst: expanding ring + shrinking bright star + cross flare
        let r = 60 * progress * zoom
        context.stroke(Circle().path(in: CGRect(x: screenPos.x - r, y: screenPos.y - r, width: r*2, height: r*2)),
                       with: .color(t.primary.opacity(alpha * 0.4)), lineWidth: 2)
        let r2 = 40 * progress * zoom
        context.stroke(Circle().path(in: CGRect(x: screenPos.x - r2, y: screenPos.y - r2, width: r2*2, height: r2*2)),
                       with: .color(t.secondary.opacity(alpha * 0.2)), lineWidth: 1)
        let starR = 10 * (1.0 - progress) * zoom
        context.fill(Circle().path(in: CGRect(x: screenPos.x - starR, y: screenPos.y - starR, width: starR*2, height: starR*2)),
                     with: .color(t.primary.opacity(alpha)))
        // Cross flare
        let flareLen = 20 * alpha * zoom
        let flare = Path { p in
            p.move(to: CGPoint(x: screenPos.x - flareLen, y: screenPos.y)); p.addLine(to: CGPoint(x: screenPos.x + flareLen, y: screenPos.y))
            p.move(to: CGPoint(x: screenPos.x, y: screenPos.y - flareLen)); p.addLine(to: CGPoint(x: screenPos.x, y: screenPos.y + flareLen))
        }
        context.stroke(flare, with: .color(t.primary.opacity(alpha * 0.5)), lineWidth: 1)
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        let s: CGFloat = 2 * state.camera.zoom
        context.fill(Circle().path(in: CGRect(x: position.x - s, y: position.y - s, width: s*2, height: s*2)),
                     with: .color(state.theme.success.opacity(opacity)))
    }

    private func resolveClusterColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid] {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.primary
    }
}
