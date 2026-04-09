import SwiftUI

// MARK: - Organism Theme Renderer

/// Bioluminescent forest: fern-spiral agents, branching frond edges,
/// floating spores, spider web grid. Deep emerald green palette.
struct OrganismRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        // Grid toggle: Spider web
        if state.showGrid && state.detail(0.2) {
            drawSpiderWeb(context: &context, size: size, state: state)
        }

        // Floating spores (small glowing ellipses drifting slowly)
        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                // Slow drift animation
                let drift = sin(state.time * 0.3 + particle.brightness * 5) * 8
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2 + drift * pf
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2 + drift * 0.5 * pf
                guard sx > -10 && sx < size.width + 10 && sy > -10 && sy < size.height + 10 else { continue }
                let twinkle = (sin(state.time * 1.2 + particle.brightness * 8) + 1) / 2 * 0.4 + 0.6
                let alpha = particle.brightness * twinkle * 0.5

                // Soft spore glow
                let glowR = particle.size * 3
                let grad = Gradient(stops: [
                    .init(color: t.starColor.opacity(alpha * 0.4), location: 0),
                    .init(color: .clear, location: 1)
                ])
                context.fill(
                    Circle().path(in: CGRect(x: sx - glowR, y: sy - glowR, width: glowR * 2, height: glowR * 2)),
                    with: .radialGradient(grad, center: CGPoint(x: sx, y: sy), startRadius: 0, endRadius: glowR)
                )

                // Spore dot
                let s = particle.size * 0.8
                context.fill(
                    Circle().path(in: CGRect(x: sx - s/2, y: sy - s/2, width: s, height: s)),
                    with: .color(t.starColor.opacity(alpha))
                )
            }
        }

        // Firefly particles
        if state.detail(0.2) {
            let cam = state.camera
            let fireflyColor = t.starColor
            let particleSlice = state.depthParticles.prefix(8)
            for (i, particle) in particleSlice.enumerated() {
                let isOn = sin(state.time * 2 + Double(i) * 1.7) > 0.3
                guard isOn else { continue }

                let pf = particle.depth
                let drift = sin(state.time * 0.5 + particle.brightness * 3) * 6
                let fx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2 + drift * pf
                let fy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2 + drift * 0.4 * pf
                guard fx > -20 && fx < size.width + 20 && fy > -20 && fy < size.height + 20 else { continue }

                let brightness = (sin(state.time * 3 + Double(i) * 2.3) + 1) / 2 * 0.6 + 0.4

                // Bright glow
                let glowR: CGFloat = 12 * cam.zoom
                let glowGrad = Gradient(stops: [
                    .init(color: fireflyColor.opacity(brightness * 0.5), location: 0),
                    .init(color: .clear, location: 1)
                ])
                context.fill(
                    Circle().path(in: CGRect(x: fx - glowR, y: fy - glowR, width: glowR * 2, height: glowR * 2)),
                    with: .radialGradient(glowGrad, center: CGPoint(x: fx, y: fy), startRadius: 0, endRadius: glowR)
                )

                // Bright core dot
                let coreR: CGFloat = 2 * cam.zoom
                context.fill(
                    Circle().path(in: CGRect(x: fx - coreR, y: fy - coreR, width: coreR * 2, height: coreR * 2)),
                    with: .color(fireflyColor.opacity(brightness * 0.9))
                )
            }
        }

        // Forest floor spotlight (warm green glow)
        if state.detail(0.4) {
            guard let active = state.agents.values.first(where: { $0.isActive }) ?? state.agents.values.first else { return }
            let sp = state.camera.worldToScreen(active.position, viewSize: size)
            let wobX = sin(state.time * 0.5) * 12; let wobY = cos(state.time * 0.4) * 10
            let center = CGPoint(x: sp.x + wobX, y: sp.y + wobY)
            let r: CGFloat = 400
            let grad = Gradient(stops: [
                .init(color: t.spotlightColor.opacity(0.1), location: 0),
                .init(color: .clear, location: 1)
            ])
            context.fill(
                Circle().path(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(grad, center: center, startRadius: 0, endRadius: r)
            )
        }
    }

    // MARK: - Spider Web Grid

    private func drawSpiderWeb(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let cam = state.camera
        let center = CGPoint(
            x: cam.offset.x * cam.zoom + size.width / 2,
            y: cam.offset.y * cam.zoom + size.height / 2
        )
        let t = state.theme
        let maxR: CGFloat = max(size.width, size.height) * 1.2
        let spokeCount = 16
        let ringCount = 12
        let ringSpacing: CGFloat = 80 * cam.zoom
        guard ringSpacing > 8 else { return }

        // Radial spokes
        for i in 0..<spokeCount {
            let angle = CGFloat(i) * (2.0 * .pi / CGFloat(spokeCount))
            let endX = center.x + CoreGraphics.cos(angle) * maxR
            let endY = center.y + CoreGraphics.sin(angle) * maxR
            let spoke = Path { p in p.move(to: center); p.addLine(to: CGPoint(x: endX, y: endY)) }
            context.stroke(spoke, with: .color(t.primary.opacity(0.06)), lineWidth: 0.5)
        }

        // Spiral web rings (slightly irregular like a real web)
        for ring in 1...ringCount {
            let baseR = CGFloat(ring) * ringSpacing
            guard baseR < maxR else { break }

            let webPath = Path { p in
                for spoke in 0...spokeCount {
                    let angle = CGFloat(spoke) * (2.0 * .pi / CGFloat(spokeCount))
                    // Slight irregularity: radius wobbles per spoke
                    let wobble = CoreGraphics.sin(CGFloat(spoke) * 2.3 + CGFloat(ring) * 1.7) * ringSpacing * 0.08
                    let r = baseR + wobble
                    let x = center.x + CoreGraphics.cos(angle) * r
                    let y = center.y + CoreGraphics.sin(angle) * r
                    if spoke == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }

            let alpha = 0.07 * (1.0 - CGFloat(ring) / CGFloat(ringCount + 2))
            context.stroke(webPath, with: .color(t.primary.opacity(Double(alpha))), lineWidth: 0.5)
        }

        // Dew drops at intersections (tiny bright dots)
        if state.detail(0.4) {
            for ring in stride(from: 2, through: ringCount, by: 2) {
                let baseR = CGFloat(ring) * ringSpacing
                for spoke in stride(from: 0, to: spokeCount, by: 2) {
                    let angle = CGFloat(spoke) * (2.0 * .pi / CGFloat(spokeCount))
                    let x = center.x + CoreGraphics.cos(angle) * baseR
                    let y = center.y + CoreGraphics.sin(angle) * baseR
                    guard x > -10 && x < size.width + 10 && y > -10 && y < size.height + 10 else { continue }
                    let twinkle = (sin(state.time * 2 + Double(ring + spoke)) + 1) / 2 * 0.3 + 0.4
                    let dr: CGFloat = 1.5 * cam.zoom
                    context.fill(
                        Circle().path(in: CGRect(x: x - dr, y: y - dr, width: dr * 2, height: dr * 2)),
                        with: .color(t.secondary.opacity(twinkle * 0.4))
                    )
                }
            }
        }

        // Spiders crawling on the web
        drawSpiders(context: &context, center: center, spokeCount: spokeCount, ringCount: ringCount, ringSpacing: ringSpacing, maxR: maxR, state: state)
    }

    // MARK: - Spiders

    private func drawSpiders(
        context: inout GraphicsContext,
        center: CGPoint,
        spokeCount: Int,
        ringCount: Int,
        ringSpacing: CGFloat,
        maxR: CGFloat,
        state: SimulationState
    ) {
        let t = state.theme
        let spiderCount = 4
        let time = state.time

        for i in 0..<spiderCount {
            // Each spider moves along a unique path on the web
            let speed = 0.15 + Double(i) * 0.05
            let phase = Double(i) * 2.7

            // Spider position: interpolate between web intersections
            // Alternate between crawling along spokes and along rings
            let cycleTime = (time * speed + phase).truncatingRemainder(dividingBy: Double(spokeCount + ringCount))

            let spokeAngle: CGFloat
            let ringR: CGFloat

            if cycleTime < Double(spokeCount) {
                // Crawling along a ring (moving between spokes)
                let spokeProgress = cycleTime.truncatingRemainder(dividingBy: Double(spokeCount))
                spokeAngle = CGFloat(spokeProgress) * (2.0 * .pi / CGFloat(spokeCount))
                let ringIdx = (Int(time * speed * 0.3 + phase * 1.3) % max(ringCount - 1, 1)) + 1
                ringR = CGFloat(ringIdx) * ringSpacing
            } else {
                // Crawling along a spoke (moving between rings)
                let spokeIdx = (Int(time * speed * 0.7 + phase * 2.1) % spokeCount)
                spokeAngle = CGFloat(spokeIdx) * (2.0 * .pi / CGFloat(spokeCount))
                let ringProgress = (cycleTime - Double(spokeCount)).truncatingRemainder(dividingBy: Double(ringCount))
                ringR = CGFloat(ringProgress / Double(ringCount)) * maxR * 0.6 + ringSpacing
            }

            let spiderX = center.x + CoreGraphics.cos(spokeAngle) * ringR
            let spiderY = center.y + CoreGraphics.sin(spokeAngle) * ringR

            // Skip if off screen
            guard spiderX > -50 && spiderX < state.camera.zoom * 2000 + 50 &&
                  spiderY > -50 && spiderY < state.camera.zoom * 2000 + 50 else { continue }

            drawSpider(context: &context, at: CGPoint(x: spiderX, y: spiderY),
                       heading: spokeAngle, time: time, index: i, zoom: state.camera.zoom, theme: t)
        }
    }

    private func drawSpider(
        context: inout GraphicsContext,
        at pos: CGPoint,
        heading: CGFloat,
        time: Double,
        index: Int,
        zoom: CGFloat,
        theme: Theme
    ) {
        let bodySize: CGFloat = 3.5 * zoom
        let legLen: CGFloat = 10 * zoom
        let alpha = 0.35

        // Body (small oval)
        context.fill(
            Ellipse().path(in: CGRect(x: pos.x - bodySize, y: pos.y - bodySize * 0.6,
                                      width: bodySize * 2, height: bodySize * 1.2)),
            with: .color(theme.primary.opacity(alpha))
        )

        // Head (smaller circle in front)
        let headDist = bodySize * 1.1
        let headX = pos.x + CoreGraphics.cos(heading) * headDist
        let headY = pos.y + CoreGraphics.sin(heading) * headDist
        let headR = bodySize * 0.5
        context.fill(
            Circle().path(in: CGRect(x: headX - headR, y: headY - headR, width: headR * 2, height: headR * 2)),
            with: .color(theme.primary.opacity(alpha))
        )

        // 8 legs (4 per side), animated with walking motion
        let legPairs = 4
        for leg in 0..<legPairs {
            let legOffset = CGFloat(leg - legPairs / 2) * bodySize * 0.5 + bodySize * 0.25
            let walkPhase = sin(time * 6 + Double(leg) * 1.2 + Double(index) * 2) * 0.3

            // Perpendicular to heading for leg spread
            let perpAngle = heading + .pi / 2

            for side in [-1.0, 1.0] {
                // Leg root on body
                let rootX = pos.x + CoreGraphics.cos(heading) * legOffset
                let rootY = pos.y + CoreGraphics.sin(heading) * legOffset

                // Knee (mid-joint, angled outward and slightly forward)
                let kneeAngle = perpAngle * CGFloat(side) + heading * 0.3 + CGFloat(walkPhase * side)
                let kneeLen = legLen * 0.6
                let kneeX = rootX + CoreGraphics.cos(CGFloat(side) * perpAngle + CGFloat(walkPhase * side) * 0.5) * kneeLen
                let kneeY = rootY + CoreGraphics.sin(CGFloat(side) * perpAngle + CGFloat(walkPhase * side) * 0.5) * kneeLen

                // Foot (tip, extends further with bend)
                let footAngle = CGFloat(side) * perpAngle + CGFloat(walkPhase * side) * 0.8 + 0.4 * CGFloat(side)
                let footLen = legLen * 0.5
                let footX = kneeX + CoreGraphics.cos(footAngle) * footLen
                let footY = kneeY + CoreGraphics.sin(footAngle) * footLen

                let legPath = Path { p in
                    p.move(to: CGPoint(x: rootX, y: rootY))
                    p.addLine(to: CGPoint(x: kneeX, y: kneeY))
                    p.addLine(to: CGPoint(x: footX, y: footY))
                }
                context.stroke(legPath, with: .color(theme.primary.opacity(alpha * 0.7)),
                               style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: - Agent: Fern Spiral

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let accent = resolveClusterColor(agent: agent, state: state)

        // Bioluminescent glow
        if state.detail(0.2) {
            let glowR = radius * 2.2
            let glowA = agent.opacity * (agent.isActive ? 0.2 : 0.08)
            let grad = Gradient(stops: [
                .init(color: accent.opacity(glowA), location: 0),
                .init(color: accent.opacity(0), location: 1)
            ])
            context.fill(
                Circle().path(in: CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2)),
                with: .radialGradient(grad, center: center, startRadius: 0, endRadius: glowR)
            )
        }

        // Fern spiral (Fibonacci/golden spiral approximation)
        let fernPath = Path { p in
            let turns: Double = agent.isMain ? 3.5 : 2.5
            let steps = 40
            let growthRate = radius / CGFloat(pow(2.718, turns * 0.3))
            let rotOffset = agent.isActive ? state.time * 0.2 : 0

            for i in 0...steps {
                let t = Double(i) / Double(steps) * turns * 2 * .pi
                let r = growthRate * CGFloat(pow(2.718, t * 0.3 / (2 * .pi)))
                let angle = t + rotOffset
                let x = center.x + CoreGraphics.cos(CGFloat(angle)) * r
                let y = center.y + CoreGraphics.sin(CGFloat(angle)) * r
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }

        context.stroke(fernPath, with: .color(accent.opacity(agent.opacity * 0.7)),
                       style: StrokeStyle(lineWidth: agent.isMain ? 2.0 : 1.2, lineCap: .round))

        // Small frond leaves branching off the spiral
        if state.detail(0.2) {
            let leafCount = agent.isMain ? 8 : 5
            let turns: Double = agent.isMain ? 3.5 : 2.5
            for i in 1...leafCount {
                let t = Double(i) / Double(leafCount) * turns * 2 * .pi
                let growthRate = radius / CGFloat(pow(2.718, turns * 0.3))
                let r = growthRate * CGFloat(pow(2.718, t * 0.3 / (2 * .pi)))
                let rotOffset = agent.isActive ? state.time * 0.2 : 0
                let angle = CGFloat(t + rotOffset)
                let baseX = center.x + CoreGraphics.cos(angle) * r
                let baseY = center.y + CoreGraphics.sin(angle) * r

                // Leaf: short line perpendicular to spiral
                let leafLen = radius * 0.2 * (0.5 + CGFloat(i) / CGFloat(leafCount) * 0.5)
                let perpAngle = angle + .pi / 2
                let leafPath = Path { p in
                    p.move(to: CGPoint(x: baseX, y: baseY))
                    p.addLine(to: CGPoint(
                        x: baseX + CoreGraphics.cos(perpAngle) * leafLen,
                        y: baseY + CoreGraphics.sin(perpAngle) * leafLen
                    ))
                }
                context.stroke(leafPath, with: .color(accent.opacity(agent.opacity * 0.4)),
                               style: StrokeStyle(lineWidth: 0.8, lineCap: .round))

                // Mirror leaf on other side
                let mirrorAngle = angle - .pi / 2
                let mirrorPath = Path { p in
                    p.move(to: CGPoint(x: baseX, y: baseY))
                    p.addLine(to: CGPoint(
                        x: baseX + CoreGraphics.cos(mirrorAngle) * leafLen * 0.8,
                        y: baseY + CoreGraphics.sin(mirrorAngle) * leafLen * 0.8
                    ))
                }
                context.stroke(mirrorPath, with: .color(accent.opacity(agent.opacity * 0.3)),
                               style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
            }
        }

        // Center seed (bright dot)
        let seedR = radius * 0.12
        context.fill(
            Circle().path(in: CGRect(x: center.x - seedR, y: center.y - seedR, width: seedR * 2, height: seedR * 2)),
            with: .color(t.sparkColor.opacity(agent.opacity * 0.8))
        )

        // Breathing pulse
        if agent.isActive {
            let pulseR = radius * (0.3 + sin(agent.breathPhase) * 0.08)
            context.stroke(
                Circle().path(in: CGRect(x: center.x - pulseR, y: center.y - pulseR, width: pulseR * 2, height: pulseR * 2)),
                with: .color(accent.opacity(agent.opacity * 0.15)), lineWidth: 1
            )
        }
    }

    // MARK: - Edges: Branching Vine

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let dx = target.x - source.x; let dy = target.y - source.y
        let dist = sqrt(dx * dx + dy * dy)

        // Organic vine curve with gentle drift
        let drift = sin(state.time * 0.4) * 10
        let curv = min(dist * 0.22, 70) + drift
        let nx = -dy / max(dist, 1) * curv; let ny = dx / max(dist, 1) * curv
        let c1 = CGPoint(x: source.x + dx * 0.33 + nx, y: source.y + dy * 0.33 + ny)
        let c2 = CGPoint(x: source.x + dx * 0.66 - nx * 0.4, y: source.y + dy * 0.66 - ny * 0.4)
        let path = Path { p in p.move(to: source); p.addCurve(to: target, control1: c1, control2: c2) }

        let a = edge.opacity * (edge.isActive ? 0.5 : 0.15)
        let color = edge.type == .parentChild ? t.primary : t.secondary

        // Main vine
        context.stroke(path, with: .color(color.opacity(a)),
                       style: StrokeStyle(lineWidth: 2.5 * state.camera.zoom, lineCap: .round))

        // Faint glow
        if edge.isActive && state.detail(0.2) {
            context.stroke(path, with: .color(color.opacity(a * 0.25)),
                           style: StrokeStyle(lineWidth: 6 * state.camera.zoom, lineCap: .round))
        }

        // Small leaf buds along the vine
        if state.detail(0.4) {
            let zoom = state.camera.zoom
            for i in 1..<4 {
                let vt = Double(i) * 0.25
                let mt = 1 - vt; let mt2 = mt * mt; let mt3 = mt2 * mt
                let vt2 = vt * vt; let vt3 = vt2 * vt
                let px = mt3 * source.x + 3 * mt2 * vt * c1.x + 3 * mt * vt2 * c2.x + vt3 * target.x
                let py = mt3 * source.y + 3 * mt2 * vt * c1.y + 3 * mt * vt2 * c2.y + vt3 * target.y

                // Tiny leaf
                let leafLen: CGFloat = 5 * zoom
                let leafAngle = CGFloat(state.time * 0.3 + Double(i) * 1.5)
                let lx = px + CoreGraphics.cos(leafAngle) * leafLen
                let ly = py + CoreGraphics.sin(leafAngle) * leafLen
                let leafPath = Path { p in
                    p.move(to: CGPoint(x: px, y: py))
                    p.addLine(to: CGPoint(x: lx, y: ly))
                }
                context.stroke(leafPath, with: .color(color.opacity(a * 0.6)),
                               style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            }
        }

        // Flower bloom at midpoint of active edges
        if edge.isActive && state.detail(0.6) {
            let zoom = state.camera.zoom
            // Midpoint of the bezier at t=0.5
            let mt: Double = 0.5; let mt1 = 1 - mt
            let mt12 = mt1 * mt1; let mt13 = mt12 * mt1
            let mt2 = mt * mt; let mt3 = mt2 * mt
            let mx = mt13 * source.x + 3 * mt12 * mt * c1.x + 3 * mt1 * mt2 * c2.x + mt3 * target.x
            let my = mt13 * source.y + 3 * mt12 * mt * c1.y + 3 * mt1 * mt2 * c2.y + mt3 * target.y

            let bloomAlpha = (sin(state.time * 0.8) + 1) / 2  // 0..1 fade in/out
            let petalCount = 6
            let petalR: CGFloat = 4 * zoom
            let dotR: CGFloat = 1.2 * zoom
            for p in 0..<petalCount {
                let angle = CGFloat(Double(p) / Double(petalCount) * 2 * .pi)
                let px = mx + CoreGraphics.cos(angle) * petalR
                let py = my + CoreGraphics.sin(angle) * petalR
                context.fill(
                    Circle().path(in: CGRect(x: px - dotR, y: py - dotR, width: dotR * 2, height: dotR * 2)),
                    with: .color(color.opacity(a * bloomAlpha * 0.7))
                )
            }
            // Center dot
            let centerR: CGFloat = 1.5 * zoom
            context.fill(
                Circle().path(in: CGRect(x: mx - centerR, y: my - centerR, width: centerR * 2, height: centerR * 2)),
                with: .color(state.theme.sparkColor.opacity(a * bloomAlpha * 0.8))
            )
        }
    }

    // MARK: - Particles: Floating Spores

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch; case .return: color = t.particleReturn
        case .toolCall: color = t.particleToolCall; case .toolReturn: color = t.particleToolReturn
        }

        // Spore with soft glow
        let s: CGFloat = 5 * zoom
        let glowR: CGFloat = 10 * zoom
        let grad = Gradient(stops: [
            .init(color: color.opacity(particle.opacity * 0.3), location: 0),
            .init(color: .clear, location: 1)
        ])
        context.fill(
            Circle().path(in: CGRect(x: position.x - glowR, y: position.y - glowR, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(grad, center: position, startRadius: 0, endRadius: glowR)
        )
        context.fill(
            Circle().path(in: CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
            with: .color(color.opacity(particle.opacity))
        )
    }

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme

        // Seed pod shape: oval that pulses when running
        let baseW: CGFloat = 50 * zoom
        let baseH: CGFloat = 30 * zoom
        let scale: CGFloat = tool.state == .running ? CGFloat(1.0 + sin(tool.pulsePhase) * 0.05) : 1.0
        let w = baseW * scale
        let h = baseH * scale

        let pulseAlpha: Double = tool.state == .running ? 0.7 + sin(tool.pulsePhase) * 0.3 : 1.0
        let alpha = tool.opacity * pulseAlpha

        let borderColor: Color
        let fillColor: Color
        switch tool.state {
        case .running:  borderColor = t.secondary; fillColor = t.secondary
        case .complete: borderColor = t.success;   fillColor = t.success
        case .error:    borderColor = t.error;     fillColor = t.error
        }

        let podRect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)

        // Translucent fill
        context.fill(
            Ellipse().path(in: podRect),
            with: .color(fillColor.opacity(alpha * 0.2))
        )

        // Border
        let borderWidth: CGFloat = tool.state == .running ? 1.5 : 1.0
        context.stroke(
            Ellipse().path(in: podRect),
            with: .color(borderColor.opacity(alpha * 0.6)),
            lineWidth: borderWidth
        )

        // Tool name below
        let fontSize = max(7, 9 * zoom)
        let nameText = Text(tool.name)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .foregroundStyle(borderColor.opacity(alpha * 0.8))
        context.draw(context.resolve(nameText), at: CGPoint(x: center.x, y: center.y + h / 2 + 4 * zoom), anchor: .top)
    }

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: t)
        let alpha = discovery.opacity

        // Bob animation
        let bob = CGFloat(sin(state.time * 1.5 + Double(discovery.label.hashValue)) * 2)
        let pos = CGPoint(x: center.x, y: center.y + bob)

        let sporeR: CGFloat = 8 * zoom

        // Translucent fill
        context.fill(
            Circle().path(in: CGRect(x: pos.x - sporeR, y: pos.y - sporeR, width: sporeR * 2, height: sporeR * 2)),
            with: .color(t.voidColor.opacity(alpha * 0.6))
        )

        // Colored border
        context.stroke(
            Circle().path(in: CGRect(x: pos.x - sporeR, y: pos.y - sporeR, width: sporeR * 2, height: sporeR * 2)),
            with: .color(typeColor.opacity(alpha * 0.7)),
            lineWidth: 1.5
        )

        // Label text below
        let fontSize = max(6, 7.5 * zoom)
        let labelText = Text(discovery.label)
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundStyle(typeColor.opacity(alpha * 0.7))
        context.draw(context.resolve(labelText), at: CGPoint(x: pos.x, y: pos.y + sporeR + 3 * zoom), anchor: .top)
    }
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount

        let cx = rect.midX, cy = rect.midY
        let rx = rect.width / 2, ry = rect.height / 2
        let pointCount = 12

        var blob = Path()
        for i in 0..<pointCount {
            let angle = (Double(i) / Double(pointCount)) * 2.0 * .pi
            let wobble = sin(state.time * 0.3 + Double(i) * 0.8) * 8.0 * state.camera.zoom
            let px = cx + (rx + wobble) * cos(angle)
            let py = cy + (ry + wobble) * sin(angle)
            if i == 0 {
                blob.move(to: CGPoint(x: px, y: py))
            } else {
                blob.addLine(to: CGPoint(x: px, y: py))
            }
        }
        blob.closeSubpath()

        context.fill(blob, with: .color(accentColor.opacity(0.03 * dim)))

        let strokeStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1.5, dash: [8, 6])
            : StrokeStyle(lineWidth: 1, dash: [4, 4])
        context.stroke(blob, with: .color(accentColor.opacity(0.2 * dim)), style: strokeStyle)
    }

    // MARK: - Effects

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let alpha = 1.0 - progress
        let t = state.theme

        // Unfurling frond: small spiral that grows outward
        let spiralPath = Path { p in
            let steps = 20
            for i in 0...steps {
                let s = Double(i) / Double(steps) * progress
                let angle = s * 3 * .pi
                let r = s * 40 * state.camera.zoom
                let x = screenPos.x + CoreGraphics.cos(CGFloat(angle)) * CGFloat(r)
                let y = screenPos.y + CoreGraphics.sin(CGFloat(angle)) * CGFloat(r)
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
        context.stroke(spiralPath, with: .color(t.primary.opacity(alpha * 0.5)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        // Drifting leaf fragment
        let s: CGFloat = 3 * state.camera.zoom
        context.fill(
            Ellipse().path(in: CGRect(x: position.x - s, y: position.y - s/2, width: s * 2, height: s)),
            with: .color(state.theme.success.opacity(opacity))
        )
    }

    private func resolveClusterColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid] {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.primary
    }
}
