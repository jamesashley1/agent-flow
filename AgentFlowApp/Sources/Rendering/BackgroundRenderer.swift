import SwiftUI

// MARK: - Background Renderer

/// Dispatches to the active theme renderer for background drawing.
struct BackgroundRenderer {

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        state: SimulationState
    ) {
        state.renderer.drawBackground(context: &context, size: size, state: state)
    }

    // Shared utility used by multiple themes
    static func hexagonPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3 - .pi / 6
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.closeSubpath()
        }
    }
}
