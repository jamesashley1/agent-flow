import SwiftUI

// MARK: - Circuit Theme Renderer

/// PCB aesthetic: chip packages with pins, manhattan routing, square pulse particles, solder pads.
struct CircuitRenderer: ThemeRenderer {

    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState) {
        let t = state.theme
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.voidColor))

        // Dot grid (solder pads) — always shown as subtle background
        if state.detail(0.2) {
            let cam = state.camera; let gridSize: CGFloat = 30 * cam.zoom
            guard gridSize > 4 else { return }
            let alpha = min((gridSize - 4) / 20, 0.12)
            let oX = cam.offset.x * cam.zoom + size.width / 2
            let oY = cam.offset.y * cam.zoom + size.height / 2
            let cols = Int(size.width / gridSize) + 4; let rows = Int(size.height / gridSize) + 4
            let startCol = Int(-oX / gridSize) - 2; let startRow = Int(-oY / gridSize) - 2
            let dotR: CGFloat = max(1, 1.5 * cam.zoom)
            for row in startRow..<(startRow + rows) {
                for col in startCol..<(startCol + cols) {
                    let x = CGFloat(col) * gridSize + oX; let y = CGFloat(row) * gridSize + oY
                    guard x > -5 && x < size.width + 5 && y > -5 && y < size.height + 5 else { continue }
                    context.fill(Circle().path(in: CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)), with: .color(t.primary.opacity(alpha)))
                }
            }
        }

        // Grid toggle: PCB trace grid — orthogonal copper lines with thicker major lines
        if state.showGrid && state.detail(0.2) {
            let cam = state.camera; let gridSize: CGFloat = 30 * cam.zoom
            guard gridSize > 6 else { return }
            let oX = cam.offset.x * cam.zoom + size.width / 2
            let oY = cam.offset.y * cam.zoom + size.height / 2
            let startCol = Int(-oX / gridSize) - 2; let startRow = Int(-oY / gridSize) - 2
            let cols = Int(size.width / gridSize) + 4; let rows = Int(size.height / gridSize) + 4
            for col in startCol..<(startCol + cols) {
                let x = CGFloat(col) * gridSize + oX
                let isMajor = col % 5 == 0
                let a = isMajor ? 0.1 : 0.04
                let lw: CGFloat = isMajor ? 1.0 : 0.5
                let line = Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) }
                context.stroke(line, with: .color(t.primary.opacity(a)), lineWidth: lw)
            }
            for row in startRow..<(startRow + rows) {
                let y = CGFloat(row) * gridSize + oY
                let isMajor = row % 5 == 0
                let a = isMajor ? 0.1 : 0.04
                let lw: CGFloat = isMajor ? 1.0 : 0.5
                let line = Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) }
                context.stroke(line, with: .color(t.primary.opacity(a)), lineWidth: lw)
            }
        }
    }

    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        let t = state.theme
        let clusterAccent = resolveClusterColor(agent: agent, state: state)
        let w = radius * 1.4; let h = radius * 1.8
        let chipRect = CGRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)

        // Chip body
        context.fill(RoundedRectangle(cornerRadius: 3).path(in: chipRect), with: .color(t.agentFillTop.opacity(agent.opacity)))
        context.stroke(RoundedRectangle(cornerRadius: 3).path(in: chipRect), with: .color(clusterAccent.opacity(agent.opacity * 0.8)), lineWidth: agent.isMain ? 2 : 1.2)

        // Notch at top
        let notchR: CGFloat = w * 0.15
        context.fill(Circle().path(in: CGRect(x: center.x - notchR, y: chipRect.minY - notchR * 0.3, width: notchR * 2, height: notchR * 2)), with: .color(t.voidColor))

        // Pins (left and right)
        if state.detail(0.2) {
            let pinCount = agent.isMain ? 5 : 3
            let pinSpacing = h / CGFloat(pinCount + 1)
            let pinLen: CGFloat = w * 0.25
            let activePin = Int(state.time * 6) % pinCount
            for i in 1...pinCount {
                let py = chipRect.minY + pinSpacing * CGFloat(i)
                let pinAlpha = agent.isActive ? ((i - 1) == activePin ? 0.9 : 0.25) : 0.3
                // Left pin
                let lp = Path { p in p.move(to: CGPoint(x: chipRect.minX - pinLen, y: py)); p.addLine(to: CGPoint(x: chipRect.minX, y: py)) }
                context.stroke(lp, with: .color(clusterAccent.opacity(agent.opacity * pinAlpha)), lineWidth: 1.5)
                // Right pin
                let rp = Path { p in p.move(to: CGPoint(x: chipRect.maxX, y: py)); p.addLine(to: CGPoint(x: chipRect.maxX + pinLen, y: py)) }
                context.stroke(rp, with: .color(clusterAccent.opacity(agent.opacity * pinAlpha)), lineWidth: 1.5)
            }
        }

        // Signal wave in center
        if state.detail(0.2) {
            let waveW = w * 0.5; let waveH: CGFloat = 4
            let wavePath = Path { p in
                let startX = center.x - waveW / 2
                p.move(to: CGPoint(x: startX, y: center.y))
                for s in stride(from: 0.0, through: 1.0, by: 0.1) {
                    let x = startX + CGFloat(s) * waveW
                    let y = center.y + sin(s * 3 * .pi + state.time * 3) * waveH
                    p.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(wavePath, with: .color(t.sparkColor.opacity(agent.opacity * 0.7)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState) {
        let t = state.theme
        // Manhattan routing: horizontal → vertical → horizontal
        let midX = (source.x + target.x) / 2
        let path = Path { p in
            p.move(to: source)
            p.addLine(to: CGPoint(x: midX, y: source.y))
            p.addLine(to: CGPoint(x: midX, y: target.y))
            p.addLine(to: target)
        }
        let w: CGFloat = (edge.type == .parentChild ? 2.0 : 1.2) * state.camera.zoom
        let a = edge.opacity * (edge.isActive ? 0.7 : 0.25)
        let c = edge.type == .parentChild ? t.primary : t.secondary
        context.stroke(path, with: .color(c.opacity(a)), style: StrokeStyle(lineWidth: w, lineCap: .square))

        // Solder joints at corners
        if state.detail(0.2) {
            let jr: CGFloat = 2.5 * state.camera.zoom
            let joints = [CGPoint(x: midX, y: source.y), CGPoint(x: midX, y: target.y)]
            for j in joints {
                context.fill(Circle().path(in: CGRect(x: j.x - jr, y: j.y - jr, width: jr * 2, height: jr * 2)), with: .color(c.opacity(a)))
            }
        }

        // Current flow animation: bright dot traveling along the 3-segment path
        if edge.isActive && state.detail(0.2) {
            let progress = state.time.truncatingRemainder(dividingBy: 1.0)
            let seg1 = CGPoint(x: midX, y: source.y)
            let seg2 = CGPoint(x: midX, y: target.y)

            // Compute lengths of each segment
            let len1 = abs(midX - source.x)
            let len2 = abs(target.y - source.y)
            let len3 = abs(target.x - midX)
            let totalLen = len1 + len2 + len3
            guard totalLen > 0 else { return }

            let dist = CGFloat(progress) * totalLen
            let dotPos: CGPoint
            if dist <= len1 {
                let frac = len1 > 0 ? dist / len1 : 0
                dotPos = CGPoint(x: source.x + (seg1.x - source.x) * frac, y: source.y)
            } else if dist <= len1 + len2 {
                let frac = len2 > 0 ? (dist - len1) / len2 : 0
                dotPos = CGPoint(x: midX, y: source.y + (seg2.y - seg1.y) * frac)
            } else {
                let frac = len3 > 0 ? (dist - len1 - len2) / len3 : 0
                dotPos = CGPoint(x: midX + (target.x - midX) * frac, y: target.y)
            }

            let dotR: CGFloat = 3.5 * state.camera.zoom
            context.fill(
                Circle().path(in: CGRect(x: dotPos.x - dotR, y: dotPos.y - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(state.theme.sparkColor.opacity(edge.opacity * 0.9))
            )
        }
    }

    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState) {
        let t = state.theme; let zoom = state.camera.zoom
        let color: Color
        switch particle.type {
        case .dispatch: color = t.particleDispatch; case .return: color = t.particleReturn
        case .toolCall: color = t.particleToolCall; case .toolReturn: color = t.particleToolReturn
        }
        // Square pulse
        let s: CGFloat = 4 * zoom
        let quantized = CGPoint(x: (position.x / (3 * zoom)).rounded() * 3 * zoom, y: (position.y / (3 * zoom)).rounded() * 3 * zoom)
        context.fill(Path(CGRect(x: quantized.x - s/2, y: quantized.y - s/2, width: s, height: s)), with: .color(color.opacity(particle.opacity)))
    }

    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let t = state.theme
        let alpha = tool.opacity
        let chipW: CGFloat = 50 * zoom; let chipH: CGFloat = 28 * zoom

        let chipRect = CGRect(x: center.x - chipW / 2, y: center.y - chipH / 2, width: chipW, height: chipH)

        // Chip body
        let borderColor: Color
        switch tool.state {
        case .running: borderColor = t.secondary
        case .complete: borderColor = t.success
        case .error:   borderColor = t.error
        }
        context.fill(Path(chipRect), with: .color(t.agentFillTop.opacity(alpha * 0.9)))
        context.stroke(Path(chipRect), with: .color(borderColor.opacity(alpha * 0.7)), lineWidth: 1.2)

        // Notch at top center
        let notchW: CGFloat = 8 * zoom; let notchH: CGFloat = 3 * zoom
        let notchRect = CGRect(x: center.x - notchW / 2, y: chipRect.minY - 0.5, width: notchW, height: notchH)
        context.fill(Path(notchRect), with: .color(t.voidColor))

        // LED indicator (small filled square, blinks when running)
        let ledSize: CGFloat = 4 * zoom
        let ledX = chipRect.minX + 4 * zoom; let ledY = center.y - ledSize / 2
        let ledAlpha: Double = tool.state == .running ? 0.5 + 0.5 * sin(state.time * 4) : (tool.state == .complete ? 0.8 : 0.3)
        let ledColor = tool.state == .running ? t.sparkColor : borderColor
        context.fill(Path(CGRect(x: ledX, y: ledY, width: ledSize, height: ledSize)), with: .color(ledColor.opacity(alpha * ledAlpha)))

        // Tool name text
        if state.detail(0.6) && zoom > 0.3 {
            let label = Text(tool.name)
                .font(.system(size: max(6, 8 * zoom), weight: .medium, design: .monospaced))
                .foregroundStyle(borderColor.opacity(alpha * 0.8))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y + chipH / 2 + 4 * zoom), anchor: .top)
        }
    }
    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState) {
        let alpha = discovery.opacity
        let typeColor = DiscoveryRenderer.discoveryColor(discovery.type, theme: state.theme)

        // Capacitor symbol: vertical rectangle with horizontal leads
        let bodyW: CGFloat = 10 * zoom; let bodyH: CGFloat = 20 * zoom
        let leadLen: CGFloat = 12 * zoom
        let bodyRect = CGRect(x: center.x - bodyW / 2, y: center.y - bodyH / 2, width: bodyW, height: bodyH)

        // Body rectangle
        context.fill(Path(bodyRect), with: .color(typeColor.opacity(alpha * 0.7)))
        context.stroke(Path(bodyRect), with: .color(typeColor.opacity(alpha * 0.9)), lineWidth: 1.0)

        // Left lead line
        let leftLead = Path { p in
            p.move(to: CGPoint(x: center.x - bodyW / 2 - leadLen, y: center.y))
            p.addLine(to: CGPoint(x: center.x - bodyW / 2, y: center.y))
        }
        context.stroke(leftLead, with: .color(typeColor.opacity(alpha * 0.8)), lineWidth: 1.2)

        // Right lead line
        let rightLead = Path { p in
            p.move(to: CGPoint(x: center.x + bodyW / 2, y: center.y))
            p.addLine(to: CGPoint(x: center.x + bodyW / 2 + leadLen, y: center.y))
        }
        context.stroke(rightLead, with: .color(typeColor.opacity(alpha * 0.8)), lineWidth: 1.2)

        // Label text below
        if state.detail(0.6) && zoom > 0.3 {
            let label = Text(discovery.label)
                .font(.system(size: max(6, 7.5 * zoom), weight: .medium, design: .monospaced))
                .foregroundStyle(typeColor.opacity(alpha * 0.7))
            context.draw(context.resolve(label), at: CGPoint(x: center.x, y: center.y + bodyH / 2 + 4 * zoom), anchor: .top)
        }
    }
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize) {
        let rect = ClusterRenderer.boundingRect(agents: agents, camera: state.camera, size: size)
        let accentColor = ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        let dim = 1.0 - cluster.dimAmount
        let arm: CGFloat = 15 * state.camera.zoom

        // Fill
        context.fill(Path(rect), with: .color(accentColor.opacity(0.03 * dim)))

        // Sharp rectangle stroke
        let strokeStyle: StrokeStyle = cluster.isActive
            ? StrokeStyle(lineWidth: 1.5)
            : StrokeStyle(lineWidth: 1, dash: [6, 4])
        context.stroke(Path(rect), with: .color(accentColor.opacity(0.2 * dim)), style: strokeStyle)

        // L-shaped corner brackets
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),   // top-left
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),  // top-right
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),  // bottom-left
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1), // bottom-right
        ]
        for (pt, dx, dy) in corners {
            var bracket = Path()
            bracket.move(to: CGPoint(x: pt.x + arm * dx, y: pt.y))
            bracket.addLine(to: pt)
            bracket.addLine(to: CGPoint(x: pt.x, y: pt.y + arm * dy))
            context.stroke(bracket, with: .color(accentColor.opacity(0.5 * dim)), style: StrokeStyle(lineWidth: 2, lineCap: .square))
        }
    }

    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState) {
        let elapsed = state.time - effect.createdAt; let progress = elapsed / effect.duration
        guard progress < 1.0 else { return }
        // Expanding square
        let s = 40 * progress * state.camera.zoom; let alpha = 1.0 - progress
        let rect = CGRect(x: screenPos.x - s, y: screenPos.y - s, width: s * 2, height: s * 2)
        context.stroke(Path(rect), with: .color(state.theme.primary.opacity(alpha)), lineWidth: 1.5)
    }

    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState) {
        let s: CGFloat = 3 * state.camera.zoom
        context.fill(Path(CGRect(x: position.x - s/2, y: position.y - s/2, width: s, height: s)), with: .color(state.theme.success.opacity(opacity)))
    }

    private func resolveClusterColor(agent: AgentModel, state: SimulationState) -> Color {
        if let sid = agent.sessionId, let cluster = state.clusters[sid] {
            return ClusterRenderer.color(for: cluster, in: state.clusters, theme: state.theme)
        }
        return state.theme.primary
    }
}
