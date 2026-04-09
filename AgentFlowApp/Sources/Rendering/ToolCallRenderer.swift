import SwiftUI

// MARK: - Tool Call Renderer

struct ToolCallRenderer {
    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        state: SimulationState
    ) {
        let camera = state.camera
        let t = state.theme
        guard camera.zoom > 0.3 else { return }

        var latestPerAgent: [String: ToolCallModel] = [:]
        for tool in state.sortedToolCalls where tool.opacity > 0.01 {
            latestPerAgent[tool.agentId] = tool
        }

        for tool in latestPerAgent.values {
            let screenPos = camera.worldToScreen(tool.position, viewSize: size)
            guard screenPos.x > -200 && screenPos.x < size.width + 200 &&
                  screenPos.y > -100 && screenPos.y < size.height + 100 else { continue }

            drawToolCard(context: &context, tool: tool, center: screenPos, zoom: camera.zoom, state: state)

            if state.detail(0.6), let agent = state.agents[tool.agentId] {
                let agentScreen = camera.worldToScreen(agent.position, viewSize: size)
                let path = Path { p in p.move(to: agentScreen); p.addLine(to: screenPos) }
                let lineColor: Color
                switch tool.state {
                case .running: lineColor = t.secondary
                case .complete: lineColor = t.success
                case .error:   lineColor = t.error
                }
                context.stroke(path, with: .color(lineColor.opacity(tool.opacity * 0.2)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }

    private static func drawToolCard(
        context: inout GraphicsContext,
        tool: ToolCallModel,
        center: CGPoint,
        zoom: CGFloat,
        state: SimulationState
    ) {
        let t = state.theme
        let fontSize = max(8, 10 * zoom); let padding: CGFloat = 6 * zoom
        let cardWidth: CGFloat = 140 * zoom; let cardHeight: CGFloat = 44 * zoom
        let isSelected = state.selectedToolCallId == tool.id

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

        let roundedRect = RoundedRectangle(cornerRadius: 6 * zoom)
        context.fill(roundedRect.path(in: rect), with: .color(bgColor.opacity(alpha * 0.9)))
        context.stroke(roundedRect.path(in: rect), with: .color(borderColor.opacity(alpha * 0.6)), lineWidth: isSelected ? 2 : 1)

        if isSelected {
            context.fill(RoundedRectangle(cornerRadius: 8 * zoom).path(in: rect.insetBy(dx: -4, dy: -4)), with: .color(borderColor.opacity(0.15)))
        }

        // Tool name
        let nameText = Text(tool.name).font(.system(size: fontSize, weight: .semibold, design: .monospaced)).foregroundStyle(borderColor.opacity(alpha))
        context.draw(context.resolve(nameText), at: CGPoint(x: rect.minX + padding, y: rect.minY + padding), anchor: .topLeading)

        guard state.detail(0.6) else { return }

        // Args
        let argsText = Text(String(tool.args.prefix(30))).font(.system(size: max(7, 8 * zoom), design: .monospaced)).foregroundStyle(Color.white.opacity(alpha * 0.5))
        context.draw(context.resolve(argsText), at: CGPoint(x: rect.minX + padding, y: rect.maxY - padding), anchor: .bottomLeading)

        // Running spinner
        if tool.state == .running {
            let sr: CGFloat = 6 * zoom; let sc = CGPoint(x: rect.maxX - padding - sr, y: rect.midY)
            let spinnerPath = Path { p in p.addArc(center: sc, radius: sr, startAngle: Angle(radians: state.time * 4), endAngle: Angle(radians: state.time * 4) + .degrees(270), clockwise: false) }
            context.stroke(spinnerPath, with: .color(borderColor.opacity(alpha * 0.8)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        if tool.state == .complete && tool.tokenCost > 0 && zoom > 0.5 {
            let costText = Text("\(AgentRenderer.formatTokens(tool.tokenCost)) tokens").font(.system(size: max(6, 7 * zoom), design: .monospaced)).foregroundStyle(Color.white.opacity(alpha * 0.4))
            context.draw(context.resolve(costText), at: CGPoint(x: center.x, y: rect.maxY + 4 * zoom), anchor: .top)
        }
    }
}
