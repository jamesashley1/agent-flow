import SwiftUI

// MARK: - Theme Renderer Protocol

/// Each visual theme implements this protocol to provide completely different
/// shapes, animations, and rendering for every element.
protocol ThemeRenderer {
    /// Draw the background (void, grid, stars/particles, spotlight)
    func drawBackground(context: inout GraphicsContext, size: CGSize, state: SimulationState)

    /// Draw a single agent node at the given screen position
    func drawAgent(context: inout GraphicsContext, agent: AgentModel, center: CGPoint, radius: CGFloat, state: SimulationState)

    /// Draw a single edge between two screen points
    func drawEdge(context: inout GraphicsContext, source: CGPoint, target: CGPoint, edge: EdgeModel, state: SimulationState)

    /// Draw a particle at the given screen position
    func drawParticle(context: inout GraphicsContext, position: CGPoint, particle: ParticleModel, edge: EdgeModel, state: SimulationState)

    /// Draw a tool call card
    func drawToolCard(context: inout GraphicsContext, tool: ToolCallModel, center: CGPoint, zoom: CGFloat, state: SimulationState)

    /// Draw a discovery card
    func drawDiscovery(context: inout GraphicsContext, discovery: DiscoveryModel, center: CGPoint, zoom: CGFloat, state: SimulationState)

    /// Draw a cluster boundary
    func drawCluster(context: inout GraphicsContext, cluster: SessionCluster, agents: [AgentModel], state: SimulationState, size: CGSize)

    /// Draw a spawn effect
    func drawSpawnEffect(context: inout GraphicsContext, effect: SpawnEffect, screenPos: CGPoint, state: SimulationState)

    /// Draw a complete effect fragment
    func drawCompleteFragment(context: inout GraphicsContext, position: CGPoint, opacity: Double, state: SimulationState)
}

// MARK: - Theme Style

enum ThemeStyle: String, CaseIterable {
    case holograph
    case circuit
    case organism
    case astral
    case tactical
    case ironman
    case animus
    case forge
    case tron
}

extension ThemeStyle {
    var renderer: ThemeRenderer {
        switch self {
        case .holograph: return HolographRenderer()
        case .circuit:   return CircuitRenderer()
        case .organism:  return OrganismRenderer()
        case .astral:    return AstralRenderer()
        case .tactical:  return TacticalRenderer()
        case .ironman:   return IronmanRenderer()
        case .animus:    return AnimusRenderer()
        case .forge:     return ForgeRenderer()
        case .tron:      return TronRenderer()
        }
    }
}
