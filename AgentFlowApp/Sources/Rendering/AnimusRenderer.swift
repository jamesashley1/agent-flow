import SwiftUI

// MARK: - Animus Theme Renderer

/// Assassin's Creed Animus aesthetic: near-monochrome white on black,
/// scattered pixel fragments, thin wireframe lines, glitch effects,
/// layered depth. Minimal color — stark digital memory deconstruction.
struct AnimusRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme

        // Pure black
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        // Grid toggle: Dense triangulated wireframe mesh
        if state.showGrid && state.detail(0.2) {
            drawWireframeMesh(context: &context, size: size, state: state)
        }

        // Scattered pixel fragments at various depths
        if state.detail(0.2) {
            let cam = state.camera
            for particle in state.depthParticles {
                let pf = particle.depth
                let sx = (particle.position.x * pf + cam.offset.x) * cam.zoom + size.width / 2
                let sy = (particle.position.y * pf + cam.offset.y) * cam.zoom + size.height / 2
                guard sx > -5 && sx < size.width + 5 && sy > -5 && sy < size.height + 5 else { continue }

                let alpha = particle.brightness * 0.5

                // Small square pixels instead of circles (digital fragment feel)
                let pixelSize: CGFloat = particle.depth > 0.6 ? 3 : 1.5
                let px = (sx / pixelSize).rounded() * pixelSize  // snap to pixel grid
                let py = (sy / pixelSize).rounded() * pixelSize
                context.fill(
                    Path(CGRect(x: px, y: py, width: pixelSize, height: pixelSize)),
                    with: .color(t.starColor.opacity(alpha))
                )

                // Occasional small text fragments near bright particles
                if particle.brightness > 0.6 && state.detail(0.6) {
                    let fragments = ["XX", "01", "MV", ">>", "##", "//"]
                    let idx = abs(particle.position.x.hashValue) % fragments.count
                    let frag = Text(fragments[idx])
                        .font(.system(size: 6, weight: .light, design: .monospaced))
                        .foregroundStyle(t.primary.opacity(alpha * 0.4))
                    context.draw(context.resolve(frag), at: CGPoint(x: px + 5, y: py), anchor: .leading)
                }
            }
        }

        // Memory loading bar at top of screen
        let loadProgress = (state.time * 0.1).truncatingRemainder(dividingBy: 1.0)
        let loadWidth = size.width * CGFloat(loadProgress)
        context.fill(
            Path(CGRect(x: 0, y: 8, width: loadWidth, height: 1)),
            with: .color(t.primary.opacity(0.08))
        )

        // Periodic full-screen CRT scan-line glitch
        if sin(state.time * 1.7) > 0.97 {
            for i in 0..<min(state.depthParticles.count, 5) {
                let glitchY = state.depthParticles[i].position.y
                    .truncatingRemainder(dividingBy: size.height)
                let absY = abs(glitchY)
                let lineH: CGFloat = CGFloat(1 + Int(abs(state.depthParticles[i].brightness * 2)))
                context.fill(
                    Path(CGRect(x: 0, y: absY, width: size.width, height: lineH)),
                    with: .color(Color.white.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Wireframe Mesh Grid

    private func drawWireframeMesh(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme; let cam = state.camera
        let gridSize: CGFloat = 50 * cam.zoom
        guard gridSize > 8 else { return }

        let oX = cam.offset.x * cam.zoom + size.width / 2
        let oY = cam.offset.y * cam.zoom + size.height / 2
        let cols = Int(size.width / gridSize) + 4; let rows = Int(size.height / gridSize) + 4
        let startCol = Int(-oX / gridSize) - 2; let startRow = Int(-oY / gridSize) - 2

        // Triangulated mesh: each grid cell has a diagonal
        for row in startRow..<(startRow + rows) {
            for col in startCol..<(startCol + cols) {
                let x = CGFloat(col) * gridSize + oX; let y = CGFloat(row) * gridSize + oY
                guard x > -gridSize * 2 && x < size.width + gridSize * 2 &&
                      y > -gridSize * 2 && y < size.height + gridSize * 2 else { continue }

                let tl = CGPoint(x: x, y: y)
                let tr = CGPoint(x: x + gridSize, y: y)
                let bl = CGPoint(x: x, y: y + gridSize)

                // Vary opacity based on distance from center for depth
                let dx = x + gridSize / 2 - size.width / 2; let dy = y + gridSize / 2 - size.height / 2
                let dist = sqrt(dx * dx + dy * dy)
                let maxDist = sqrt(size.width * size.width + size.height * size.height) / 2
                let alpha = 0.06 * max(0, 1.0 - dist / maxDist)

                // Horizontal line
                let hLine = Path { p in p.move(to: tl); p.addLine(to: tr) }
                context.stroke(hLine, with: .color(t.primary.opacity(alpha)), lineWidth: 0.3)

                // Vertical line
                let vLine = Path { p in p.move(to: tl); p.addLine(to: bl) }
                context.stroke(vLine, with: .color(t.primary.opacity(alpha)), lineWidth: 0.3)

                // Diagonal (alternating direction per cell for triangle mesh)
                let diag: Path
                if (col + row) % 2 == 0 {
                    diag = Path { p in p.move(to: tl); p.addLine(to: CGPoint(x: x + gridSize, y: y + gridSize)) }
                } else {
                    diag = Path { p in p.move(to: tr); p.addLine(to: bl) }
                }
                context.stroke(diag, with: .color(t.primary.opacity(alpha * 0.6)), lineWidth: 0.3)
            }
        }
    }

    // MARK: - Agent: Pixel Cloud

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let accent = resolveColor(agent: agent, state: state)

        // Scatter of pixel fragments forming a loose circular shape
        let pixelCount = agent.isMain ? 40 : 24
        let rng = SeededRandom(seed: UInt64(abs(agent.id.hashValue)))
        var rngCopy = rng

        for _ in 0..<pixelCount {
            let angle = rngCopy.next() * 2 * .pi
            let dist = rngCopy.next() * Double(radius) * (0.3 + rngCopy.next() * 0.7)
            // Slight jitter animation
            let jitterX = sin(state.time * 2 + angle * 3) * 1.5
            let jitterY = cos(state.time * 1.7 + angle * 2) * 1.5
            let px = center.x + CGFloat(cos(angle) * dist) + CGFloat(jitterX)
            let py = center.y + CGFloat(sin(angle) * dist) + CGFloat(jitterY)

            let pixelSize: CGFloat = CGFloat(1.5 + rngCopy.next() * 2.5)
            let alpha = agent.opacity * (0.3 + rngCopy.next() * 0.5)

            // Snap to pixel grid
            let snapX = (px / 2).rounded() * 2; let snapY = (py / 2).rounded() * 2
            context.fill(
                Path(CGRect(x: snapX, y: snapY, width: pixelSize, height: pixelSize)),
                with: .color(accent.opacity(alpha))
            )
        }

        // Thin circle outline (barely visible, like a memory boundary)
        context.stroke(
            Circle().path(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(accent.opacity(agent.opacity * 0.12)), lineWidth: 0.5)

        // Small crosshair at center
        if state.detail(0.2) {
            let cr: CGFloat = radius * 0.2
            let cross = Path { p in
                p.move(to: CGPoint(x: center.x - cr, y: center.y)); p.addLine(to: CGPoint(x: center.x + cr, y: center.y))
                p.move(to: CGPoint(x: center.x, y: center.y - cr)); p.addLine(to: CGPoint(x: center.x, y: center.y + cr))
            }
            context.stroke(cross, with: .color(t.primary.opacity(agent.opacity * 0.5)), lineWidth: 0.8)
        }

        // DNA helix strands wrapping vertically through agent area
        if state.detail(0.4) {
            let helixAmplitude = radius * 0.8
            let steps = Int(radius * 2 / 4)  // dot every ~4 points
            for i in 0..<steps {
                let yOff = CGFloat(i) * 4 - radius
                let py = center.y + yOff
                let phase = Double(yOff) * 0.3 + state.time * 2
                // Strand 1
                let x1 = center.x + sin(phase) * helixAmplitude
                let dotR1: CGFloat = 1.2
                context.fill(
                    Path(CGRect(x: x1 - dotR1, y: py - dotR1, width: dotR1 * 2, height: dotR1 * 2)),
                    with: .color(accent.opacity(agent.opacity * 0.25))
                )
                // Strand 2 (pi offset)
                let x2 = center.x + sin(phase + .pi) * helixAmplitude
                let dotR2: CGFloat = 1.2
                context.fill(
                    Path(CGRect(x: x2 - dotR2, y: py - dotR2, width: dotR2 * 2, height: dotR2 * 2)),
                    with: .color(accent.opacity(agent.opacity * 0.2))
                )
            }
        }

        // Glitch line (brief horizontal displacement)
        if agent.isActive && state.detail(0.4) {
            let glitchPhase = (state.time * 7 + Double(agent.id.hashValue % 100)).truncatingRemainder(dividingBy: 4.0)
            if glitchPhase < 0.15 {
                let gy = center.y + CGFloat.random(in: -radius...radius)
                let glitchW = radius * 0.8
                let glitch = Path(CGRect(x: center.x - glitchW/2 + 3, y: gy, width: glitchW, height: 1.5))
                context.fill(glitch, with: .color(t.primary.opacity(agent.opacity * 0.4)))
            }
        }
    }

    // MARK: - Edges: Thin Glitchy Lines

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        let a = edge.opacity * (edge.isActive ? 0.35 : 0.08)
        let w: CGFloat = (edge.type == .parentChild ? 0.8 : 0.5) * state.camera.zoom

        // Main line (straight, stark)
        let path = Path { p in p.move(to: source); p.addLine(to: target) }
        context.stroke(path, with: .color(t.primary.opacity(a)), lineWidth: w)

        // Glitch: occasional offset duplicate line
        if edge.isActive && state.detail(0.4) {
            let glitchPhase = (state.time * 5 + Double(edge.id.hashValue % 100)).truncatingRemainder(dividingBy: 3.0)
            if glitchPhase < 0.1 {
                let offset: CGFloat = 3
                let glitchPath = Path { p in
                    p.move(to: CGPoint(x: source.x + offset, y: source.y - offset))
                    p.addLine(to: CGPoint(x: target.x + offset, y: target.y - offset))
                }
                context.stroke(glitchPath, with: .color(t.primary.opacity(a * 0.5)), lineWidth: w * 0.5)
            }
        }

        // Small node dots at endpoints
        if state.detail(0.2) {
            let dotR: CGFloat = 1.5 * state.camera.zoom
            context.fill(Path(CGRect(x: source.x - dotR, y: source.y - dotR, width: dotR * 2, height: dotR * 2)),
                         with: .color(t.primary.opacity(a)))
            context.fill(Path(CGRect(x: target.x - dotR, y: target.y - dotR, width: dotR * 2, height: dotR * 2)),
                         with: .color(t.primary.opacity(a)))
        }
    }

    // MARK: - Particles: Single Bright Pixels

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        // All particles are white — minimal color
        let s: CGFloat = 3 * state.camera.zoom
        let snapX = (position.x / 2).rounded() * 2; let snapY = (position.y / 2).rounded() * 2
        context.fill(
            Path(CGRect(x: snapX - s/2, y: snapY - s/2, width: s, height: s)),
            with: .color(t.primary.opacity(particle.opacity * 0.8))
        )
    }

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = tool.opacity
        let cardW: CGFloat = 44 * zoom; let cardH: CGFloat = 22 * zoom
        let cardRect = CGRect(x: center.x - cardW / 2, y: center.y - cardH / 2, width: cardW, height: cardH)

        // Scattered square fragment outline (pixelated border)
        let fragSize: CGFloat = 3 * zoom
        let flickerMod = Int(state.time * 10) % 3
        let rng = SeededRandom(seed: UInt64(abs(tool.id.hashValue)))
        var rngCopy = rng

        // Draw fragments along the rectangle edges
        let steps = Int((cardW + cardH) * 2 / fragSize)
        for i in 0..<steps {
            // Flickering: randomly hide some fragments when running
            if tool.state == .running && (i + flickerMod) % 3 == 0 {
                _ = rngCopy.next()
                continue
            }

            let perimeter = CGFloat(i) * fragSize
            let fx: CGFloat; let fy: CGFloat
            if perimeter < cardW {
                fx = cardRect.minX + perimeter; fy = cardRect.minY
            } else if perimeter < cardW + cardH {
                fx = cardRect.maxX; fy = cardRect.minY + (perimeter - cardW)
            } else if perimeter < cardW * 2 + cardH {
                fx = cardRect.maxX - (perimeter - cardW - cardH); fy = cardRect.maxY
            } else {
                fx = cardRect.minX; fy = cardRect.maxY - (perimeter - cardW * 2 - cardH)
            }

            // Slight scatter offset
            let scatter = CGFloat(rngCopy.next() * 2 - 1) * 1.5
            context.fill(
                Path(CGRect(x: fx + scatter, y: fy + scatter, width: fragSize, height: fragSize)),
                with: .color(t.primary.opacity(alpha * 0.5))
            )
        }

        // Tool name in small monospace
        if state.detail(0.6) && zoom > 0.3 {
            let borderColor: Color
            switch tool.state {
            case .running: borderColor = t.primary
            case .complete: borderColor = t.success
            case .error:   borderColor = t.error
            }
            let label = Text(tool.name)
                .font(.system(size: max(5, 7 * zoom), weight: .light, design: .monospaced))
                .foregroundStyle(borderColor.opacity(alpha * 0.7))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y), anchor: .center)
        }
    }

    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let alpha = discovery.opacity
        let nearWhite = Color.white

        // Cluster of 4-5 small scattered pixels near the discovery position
        let rng = SeededRandom(seed: UInt64(abs(discovery.id.hashValue)))
        var rngCopy = rng
        for _ in 0..<5 {
            let dx = CGFloat(rngCopy.next() * 8 - 4) * zoom
            let dy = CGFloat(rngCopy.next() * 8 - 4) * zoom
            let s: CGFloat = CGFloat(1.5 + rngCopy.next() * 1.5) * zoom
            context.fill(
                Path(CGRect(x: center.x + dx - s / 2, y: center.y + dy - s / 2, width: s, height: s)),
                with: .color(nearWhite.opacity(alpha * 0.6))
            )
        }

        // Thin connecting line toward the target (agent) direction
        let worldDx = discovery.targetPosition.x - discovery.position.x
        let worldDy = discovery.targetPosition.y - discovery.position.y
        let worldDist = max(1, sqrt(worldDx * worldDx + worldDy * worldDy))
        let lineLen: CGFloat = 20 * zoom
        let lineEnd = CGPoint(
            x: center.x + worldDx / worldDist * lineLen,
            y: center.y + worldDy / worldDist * lineLen
        )
        let line = Path { p in
            p.move(to: center)
            p.addLine(to: lineEnd)
        }
        context.stroke(line, with: .color(nearWhite.opacity(alpha * 0.15)), lineWidth: 0.5)

        // Label text nearby in tiny monospace font
        if state.detail(0.6) && zoom > 0.3 {
            let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: state.theme)
            let label = Text(discovery.label)
                .font(.system(size: max(5, 6 * zoom), weight: .light, design: .monospaced))
                .foregroundStyle(typeColor.opacity(alpha * 0.6))
            context.draw(context.resolve(label),
                         at: CGPoint(x: center.x, y: center.y + 8 * zoom), anchor: .top)
        }
    }
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount

        let cx = rect.midX, cy = rect.midY
        let radius = hypot(rect.width / 2, rect.height / 2)

        var hex = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3) - .pi / 6
            let px = cx + cos(angle) * radius
            let py = cy + sin(angle) * radius
            if i == 0 { hex.move(to: CGPoint(x: px, y: py)) }
            else { hex.addLine(to: CGPoint(x: px, y: py)) }
        }
        hex.closeSubpath()

        context.fill(hex, with: .color(accentColor.opacity(0.02 * dim)))

        let strokeStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1)
            : StrokeStyle(lineWidth: 0.7, dash: [6, 4])
        context.stroke(hex, with: .color(accentColor.opacity(0.15 * dim)), style: strokeStyle)
    }

    // MARK: - Effects

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        let t = state.theme; let zoom = state.camera.zoom; let alpha = 1.0 - progress

        // Pixel burst: small squares scattering outward
        let count = 12
        let rng = SeededRandom(seed: UInt64(abs(effect.position.x.hashValue &+ effect.position.y.hashValue)))
        var rngCopy = rng
        for _ in 0..<count {
            let angle = rngCopy.next() * 2 * .pi
            let speed = 20 + rngCopy.next() * 40
            let dist = speed * progress * Double(zoom)
            let px = screenPos.x + CGFloat(cos(angle) * dist)
            let py = screenPos.y + CGFloat(sin(angle) * dist)
            let s: CGFloat = CGFloat(1.5 + rngCopy.next() * 2) * zoom
            context.fill(Path(CGRect(x: px, y: py, width: s, height: s)),
                         with: .color(t.primary.opacity(alpha * (0.3 + rngCopy.next() * 0.5))))
        }
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        let s: CGFloat = 2 * state.camera.zoom
        context.fill(Path(CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)),
                     with: .color(state.theme.primary.opacity(opacity)))
    }

    private func resolveColor(agent: AgentModel, state: SimulationState) -> Color {
        // Mostly white, with very faint cluster tint
        if let sid = agent.sessionId, let cluster = state.clusters[sid], state.clusters.count > 1 {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.primary
    }
}

// MARK: - Seeded Random

/// Simple deterministic random for consistent pixel scatter per agent.
private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
    }
}
