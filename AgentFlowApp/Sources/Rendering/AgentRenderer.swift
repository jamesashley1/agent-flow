import SwiftUI

// MARK: - Agent Renderer

/// Handles agent culling, sorting, and shared overlays (labels, context, messages),
/// then dispatches node shape drawing to the active theme renderer.
struct AgentRenderer {
    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        state: SimulationState
    ) {
        let camera = state.camera
        let renderer = state.renderer

        for agent in state.sortedAgents {
            let screenPos = camera.worldToScreen(agent.position, viewSize: size)
            let screenRadius = agent.radius * camera.zoom * agent.scale

            guard screenPos.x > -screenRadius * 3 && screenPos.x < size.width + screenRadius * 3 &&
                  screenPos.y > -screenRadius * 3 && screenPos.y < size.height + screenRadius * 3 else { continue }

            let breathScale: CGFloat = agent.isActive ? 1.0 + sin(agent.breathPhase) * 0.03 : 1.0
            let finalRadius = screenRadius * breathScale

            // Dispatch node shape to theme
            renderer.drawAgent(context: &context, agent: agent, center: screenPos, radius: finalRadius, state: state)

            // Selection ring (shared across themes)
            if state.selectedAgentId == agent.id {
                let selectPath = Circle().path(in: CGRect(x: screenPos.x - finalRadius - 4, y: screenPos.y - finalRadius - 4, width: (finalRadius + 4) * 2, height: (finalRadius + 4) * 2))
                context.stroke(selectPath, with: .color(Color.white.opacity(0.6)), lineWidth: 2)
            }

            // Shared overlays at various detail levels
            if camera.zoom > 0.4 && state.detail(0.4) {
                drawContextRing(context: &context, agent: agent, center: screenPos, radius: finalRadius + 6 * camera.zoom, state: state)
            }
            if camera.zoom > 0.5 && state.detail(0.6) {
                drawContextBar(context: &context, agent: agent, center: screenPos, radius: finalRadius, zoom: camera.zoom, state: state)
            }
            if camera.zoom > 0.3 && state.detail(0.4) {
                drawLabel(context: &context, agent: agent, center: screenPos, radius: finalRadius, zoom: camera.zoom)
            }
            if camera.zoom > 0.4 && state.detail(0.8) {
                drawMessages(context: &context, agent: agent, center: screenPos, radius: finalRadius, zoom: camera.zoom, state: state)
            }
        }

        // Effects
        if state.detail(0.8) {
            for effect in state.spawnEffects {
                let screenPos = state.camera.worldToScreen(effect.position, viewSize: size)
                renderer.drawSpawnEffect(context: &context, effect: effect, screenPos: screenPos, state: state)
            }
            for effect in state.completeEffects {
                for fragment in effect.fragments where fragment.opacity > 0 {
                    let screenPos = state.camera.worldToScreen(fragment.position, viewSize: size)
                    renderer.drawCompleteFragment(context: &context, position: screenPos, opacity: fragment.opacity, state: state)
                }
            }
        }
    }

    // MARK: - Context Ring

    private static func drawContextRing(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState) {
        guard agent.tokensMax > 0 else { return }
        let progress = min(Double(agent.tokensUsed) / Double(agent.tokensMax), 1.0)
        guard progress > 0 else { return }

        let bgPath = Path { p in p.addArc(center: center, radius: radius, startAngle: .zero, endAngle: .degrees(360), clockwise: false) }
        context.stroke(bgPath, with: .color(Color.white.opacity(0.05)), lineWidth: 2)

        let arcPath = Path { p in p.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false) }
        let ringColor = progress > 0.8 ? state.theme.error : state.theme.primary
        context.stroke(arcPath, with: .color(ringColor.opacity(agent.opacity * 0.6)), lineWidth: 2)
    }

    // MARK: - Context Bar

    private static func drawContextBar(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, zoom: CGFloat, state: SimulationState) {
        let ctx = agent.context; guard ctx.total > 0 else { return }
        let t = state.theme
        let barWidth = radius * 1.6; let barHeight: CGFloat = 4 * zoom
        let barY = center.y + radius + 10 * zoom; let startX = center.x - barWidth / 2
        context.fill(RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: startX, y: barY, width: barWidth, height: barHeight)), with: .color(Color.white.opacity(0.1)))
        let segments: [(Int, Color)] = [(ctx.systemPrompt, t.ctxSystem), (ctx.userMessages, t.ctxUser), (ctx.toolResults, t.ctxTool), (ctx.reasoning, t.ctxReasoning), (ctx.subagentResults, t.ctxSubagent)]
        let total = Double(max(ctx.total, 1)); var x = startX
        for (count, color) in segments {
            let w = barWidth * CGFloat(Double(count) / total)
            if w > 0.5 { context.fill(Path(CGRect(x: x, y: barY, width: w, height: barHeight)), with: .color(color.opacity(agent.opacity * 0.8))); x += w }
        }
    }

    // MARK: - Label

    private static func drawLabel(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, zoom: CGFloat) {
        let fontSize = max(9, 11 * zoom)
        let text = Text(agent.name).font(.system(size: fontSize, weight: .medium, design: .monospaced)).foregroundStyle(Color.white.opacity(agent.opacity * 0.9))
        context.draw(context.resolve(text), at: CGPoint(x: center.x, y: center.y + radius + 20 * zoom), anchor: .top)
        if agent.tokensUsed > 0 {
            let tokenText = Text(formatTokens(agent.tokensUsed)).font(.system(size: max(7, 9 * zoom), design: .monospaced)).foregroundStyle(Color.white.opacity(agent.opacity * 0.5))
            context.draw(context.resolve(tokenText), at: CGPoint(x: center.x, y: center.y + radius + 20 * zoom + fontSize + 4 * zoom), anchor: .top)
        }
    }

    // MARK: - Messages

    private static func drawMessages(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, zoom: CGFloat, state: SimulationState) {
        guard let message = agent.messages.last, message.opacity > 0 else { return }
        let t = state.theme
        let bubbleY = center.y - radius + message.offsetY * zoom
        let maxWidth: CGFloat = 180 * zoom; let padding: CGFloat = 8 * zoom; let fontSize = max(8, 10 * zoom)
        let text = Text(String(message.text.prefix(120))).font(.system(size: fontSize, design: .monospaced)).foregroundStyle(Color.white.opacity(message.opacity * 0.9))
        let resolved = context.resolve(text)
        let textSize = resolved.measure(in: CGSize(width: maxWidth - padding * 2, height: 200))
        let bw = min(textSize.width + padding * 2, maxWidth); let bh = min(textSize.height + padding * 2, 80 * zoom)
        let rect = CGRect(x: center.x - bw / 2, y: bubbleY - bh, width: bw, height: bh)
        let bgColor: Color; let borderColor: Color
        switch message.role {
        case .thinking: bgColor = t.bubbleThinking; borderColor = t.thinking
        case .user: bgColor = t.bubbleUser; borderColor = t.ctxUser
        case .assistant: bgColor = t.bubbleAssistant; borderColor = t.primary
        }
        let rr = RoundedRectangle(cornerRadius: 6 * zoom)
        context.fill(rr.path(in: rect), with: .color(bgColor.opacity(message.opacity * 0.85)))
        context.stroke(rr.path(in: rect), with: .color(borderColor.opacity(message.opacity * 0.4)), lineWidth: 0.5)
        context.draw(resolved, in: CGRect(x: rect.minX + padding, y: rect.minY + padding, width: bw - padding * 2, height: bh - padding * 2))
    }

    // MARK: - Helpers

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
