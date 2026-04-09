import SwiftUI

// MARK: - Cluster Renderer

struct ClusterRenderer {

    static func color(for cluster: SessionCluster, in clusters: [String: SessionCluster]) -> Color {
        let sorted = clusters.keys.sorted()
        let index = sorted.firstIndex(of: cluster.id) ?? 0
        return defaultPalette[index % defaultPalette.count]
    }

    static func color(for cluster: SessionCluster, in clusters: [String: SessionCluster], theme: Theme) -> Color {
        let sorted = clusters.keys.sorted()
        let index = sorted.firstIndex(of: cluster.id) ?? 0
        return theme.clusterColors[index % theme.clusterColors.count]
    }

    private static let defaultPalette: [Color] = Theme.holograph.clusterColors

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        state: SimulationState
    ) {
        guard !state.clusters.isEmpty else { return }
        let camera = state.camera
        let t = state.theme
        let renderer = state.renderer

        for cluster in state.clusters.values {
            let clusterAgents = Array(state.agents.values.filter { $0.sessionId == cluster.id })
            guard !clusterAgents.isEmpty else { continue }

            let positions = clusterAgents.map(\.position)
            let padding: CGFloat = 120
            let minX = positions.map(\.x).min()! - padding
            let maxX = positions.map(\.x).max()! + padding
            let minY = positions.map(\.y).min()! - padding
            let maxY = positions.map(\.y).max()! + padding

            let topLeft = camera.worldToScreen(CGPoint(x: minX, y: minY), viewSize: size)
            let bottomRight = camera.worldToScreen(CGPoint(x: maxX, y: maxY), viewSize: size)
            let rect = CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)

            guard rect.maxX > -50 && rect.minX < size.width + 50 &&
                  rect.maxY > -50 && rect.minY < size.height + 50 else { continue }

            let accentColor = Self.color(for: cluster, in: state.clusters, theme: t)
            let dim = 1.0 - cluster.dimAmount

            // Dispatch shape to theme renderer
            renderer.drawCluster(context: &context, cluster: cluster, agents: clusterAgents, state: state, size: size)

            // Fallback: if theme didn't draw, use default rounded rect
            // (themes that implement drawCluster will have already drawn)

            // Label (shared across all themes)
            if camera.zoom > 0.2 && state.detail(0.2) {
                drawClusterLabel(context: &context, cluster: cluster, rect: rect,
                                 accentColor: accentColor, dim: dim, zoom: camera.zoom, theme: t)
            }
        }
    }

    // MARK: - Default Cluster Shape (used by themes that don't override)

    static func drawDefaultCluster(
        context: inout GraphicsContext,
        cluster: SessionCluster,
        rect: CGRect,
        accentColor: Color,
        dim: Double,
        zoom: CGFloat
    ) {
        let cornerRadius: CGFloat = 20 * zoom
        let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)

        context.fill(roundedRect.path(in: rect), with: .color(accentColor.opacity(0.03 * dim)))

        let outerRect = rect.insetBy(dx: -2, dy: -2)
        context.stroke(RoundedRectangle(cornerRadius: cornerRadius + 2).path(in: outerRect),
                       with: .color(accentColor.opacity(0.06 * dim)), lineWidth: 4)

        if cluster.isActive {
            context.stroke(roundedRect.path(in: rect),
                           with: .color(accentColor.opacity(0.2 * dim)), style: StrokeStyle(lineWidth: 1.5))
        } else {
            context.stroke(roundedRect.path(in: rect),
                           with: .color(accentColor.opacity(0.12 * dim)),
                           style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
    }

    // MARK: - Cluster Label

    static func drawClusterLabel(
        context: inout GraphicsContext,
        cluster: SessionCluster,
        rect: CGRect,
        accentColor: Color,
        dim: Double,
        zoom: CGFloat,
        theme: Theme
    ) {
        let fontSize = max(10, 12 * zoom)
        let iconName = cluster.source == .xcode ? "hammer.fill" : "terminal.fill"
        let statusSuffix = cluster.isActive ? "" : "  \(Image(systemName: "checkmark.circle.fill"))"
        let labelText = Text("\(Image(systemName: iconName))  \(cluster.label)\(statusSuffix)")
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .foregroundStyle(accentColor.opacity(0.85 * dim))

        let resolved = context.resolve(labelText)
        let labelSize = resolved.measure(in: CGSize(width: 400, height: 40))

        let tabWidth = labelSize.width + 24; let tabHeight = labelSize.height + 10
        let tabX = rect.minX + 16 * zoom; let tabY = rect.minY - tabHeight + 2
        let tabRect = CGRect(x: tabX, y: tabY, width: tabWidth, height: tabHeight)

        let tabShape = UnevenRoundedRectangle(topLeadingRadius: 8 * zoom, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 8 * zoom)
        context.fill(tabShape.path(in: tabRect), with: .color(theme.uiBackground.opacity(0.92)))
        context.stroke(tabShape.path(in: tabRect), with: .color(accentColor.opacity(0.2 * dim)), lineWidth: 1.5)
        context.draw(resolved, at: CGPoint(x: tabRect.midX, y: tabRect.midY), anchor: .center)

        let countText = Text("\(cluster.agentCount)").font(.system(size: max(8, 9 * zoom), weight: .medium, design: .monospaced)).foregroundStyle(accentColor.opacity(0.7 * dim))
        let resolvedCount = context.resolve(countText)
        let countSize = resolvedCount.measure(in: CGSize(width: 50, height: 20))
        let pillRect = CGRect(x: tabRect.maxX + 6, y: tabRect.midY - (countSize.height + 6) / 2, width: countSize.width + 10, height: countSize.height + 6)
        context.fill(Capsule().path(in: pillRect), with: .color(accentColor.opacity(0.12 * dim)))
        context.draw(resolvedCount, at: CGPoint(x: pillRect.midX, y: pillRect.midY), anchor: .center)
    }

    /// Compute bounding rect from agents (utility for theme renderers)
    static func boundingRect(agents: [AgentModel], camera: CameraState, size: CGSize, padding: CGFloat = 120) -> CGRect {
        let positions = agents.map(\.position)
        let minX = positions.map(\.x).min()! - padding
        let maxX = positions.map(\.x).max()! + padding
        let minY = positions.map(\.y).min()! - padding
        let maxY = positions.map(\.y).max()! + padding
        let topLeft = camera.worldToScreen(CGPoint(x: minX, y: minY), viewSize: size)
        let bottomRight = camera.worldToScreen(CGPoint(x: maxX, y: maxY), viewSize: size)
        return CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }
}
