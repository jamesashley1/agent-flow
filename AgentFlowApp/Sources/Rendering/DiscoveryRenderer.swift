import SwiftUI

// MARK: - Discovery Renderer

struct DiscoveryRenderer {
    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        state: SimulationState
    ) {
        let camera = state.camera
        guard camera.zoom > 0.3 else { return }

        for discovery in state.discoveries {
            guard discovery.opacity > 0.01 else { continue }
            let screenPos = camera.worldToScreen(discovery.position, viewSize: size)
            guard screenPos.x > -200 && screenPos.x < size.width + 200 &&
                  screenPos.y > -100 && screenPos.y < size.height + 100 else { continue }

            drawDiscoveryCard(context: &context, discovery: discovery, center: screenPos, zoom: camera.zoom, state: state)

            if let agent = state.agents[discovery.agentId] {
                let agentScreen = camera.worldToScreen(agent.position, viewSize: size)
                let path = Path { p in p.move(to: agentScreen); p.addLine(to: screenPos) }
                let typeColor = discoveryColor(discovery.type, theme: state.theme)
                context.stroke(path, with: .color(typeColor.opacity(discovery.opacity * 0.15)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
            }
        }
    }

    private static func drawDiscoveryCard(
        context: inout GraphicsContext,
        discovery: DiscoveryModel,
        center: CGPoint,
        zoom: CGFloat,
        state: SimulationState
    ) {
        let t = state.theme
        let fontSize = max(7, 9 * zoom); let padding: CGFloat = 6 * zoom
        let cardWidth: CGFloat = 130 * zoom; let cardHeight: CGFloat = 50 * zoom
        let borderWidth: CGFloat = 3 * zoom

        let rect = CGRect(x: center.x - cardWidth / 2, y: center.y - cardHeight / 2, width: cardWidth, height: cardHeight)
        let alpha = discovery.opacity
        let typeColor = discoveryColor(discovery.type, theme: t)

        context.fill(RoundedRectangle(cornerRadius: 4 * zoom).path(in: rect), with: .color(t.agentFillBottom.opacity(alpha * 0.85)))

        let leftBorderRect = CGRect(x: rect.minX, y: rect.minY, width: borderWidth, height: rect.height)
        let leftBorderPath = Path { p in p.addRoundedRect(in: leftBorderRect, cornerRadii: RectangleCornerRadii(topLeading: 4 * zoom, bottomLeading: 4 * zoom)) }
        context.fill(leftBorderPath, with: .color(typeColor.opacity(alpha)))

        let labelText = Text(discovery.label).font(.system(size: fontSize, weight: .semibold, design: .monospaced)).foregroundStyle(typeColor.opacity(alpha * 0.9))
        context.draw(context.resolve(labelText), at: CGPoint(x: rect.minX + borderWidth + padding, y: rect.minY + padding), anchor: .topLeading)

        let contentText = Text(String(discovery.content.prefix(50))).font(.system(size: max(6, 7.5 * zoom), design: .monospaced)).foregroundStyle(Color.white.opacity(alpha * 0.5))
        context.draw(context.resolve(contentText), in: CGRect(x: rect.minX + borderWidth + padding, y: rect.minY + padding + fontSize + 4 * zoom, width: cardWidth - borderWidth - padding * 2, height: cardHeight - padding * 2 - fontSize - 4 * zoom))
    }

    static func discoveryColor(_ type: DiscoveryType, theme: Theme) -> Color {
        switch type {
        case .file:    return theme.discoveryFile
        case .pattern: return theme.discoveryPattern
        case .finding: return theme.discoveryFinding
        case .code:    return theme.discoveryCode
        }
    }
}
