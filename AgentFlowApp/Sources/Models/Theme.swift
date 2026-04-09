import SwiftUI

// MARK: - Visualization Theme

struct Theme: Equatable {
    let name: String
    let icon: String
    let style: ThemeStyle

    // Background
    let voidColor: Color
    let voidColorAlt: Color          // for subtle gradient
    let spotlightColor: Color

    // Primary palette
    let primary: Color               // main accent (edges, borders, UI)
    let secondary: Color             // tool calls, secondary actions
    let success: Color               // completion, return
    let error: Color                 // errors, warnings
    let thinking: Color              // idle/thinking state
    let permission: Color            // waiting for permission

    // Agent node
    let agentFillTop: Color
    let agentFillBottom: Color
    let sparkColor: Color

    // Context bar segments
    let ctxSystem: Color
    let ctxUser: Color
    let ctxTool: Color
    let ctxReasoning: Color
    let ctxSubagent: Color

    // Message bubbles
    let bubbleThinking: Color
    let bubbleUser: Color
    let bubbleAssistant: Color

    // Tool card backgrounds
    let toolRunningBg: Color
    let toolCompleteBg: Color
    let toolErrorBg: Color

    // Discovery types
    let discoveryFile: Color
    let discoveryPattern: Color
    let discoveryFinding: Color
    let discoveryCode: Color

    // Cluster palette (up to 6)
    let clusterColors: [Color]

    // Particles
    let particleDispatch: Color
    let particleReturn: Color
    let particleToolCall: Color
    let particleToolReturn: Color

    // UI chrome
    let uiBackground: Color
    let uiAccent: Color
    let uiBorder: Color

    // Star / depth particle tint
    let starColor: Color
}

// MARK: - Built-in Themes

extension Theme {
    /// Holograph — the original cyan-on-navy sci-fi console
    static let holograph = Theme(
        name: "Holograph",
        icon: "hexagon",
        style: .holograph,
        voidColor:        Color(red: 0.02, green: 0.02, blue: 0.06),
        voidColorAlt:     Color(red: 0.03, green: 0.03, blue: 0.08),
        spotlightColor:   Color(red: 0.1, green: 0.2, blue: 0.4),
        primary:          Color(red: 0.4, green: 0.8, blue: 1.0),
        secondary:        Color(red: 1.0, green: 0.73, blue: 0.27),
        success:          Color(red: 0.4, green: 1.0, blue: 0.67),
        error:            Color(red: 1.0, green: 0.33, blue: 0.4),
        thinking:         Color(red: 0.4, green: 0.8, blue: 1.0),
        permission:       Color(red: 1.0, green: 0.67, blue: 0.2),
        agentFillTop:     Color(red: 0.06, green: 0.06, blue: 0.12),
        agentFillBottom:  Color(red: 0.03, green: 0.03, blue: 0.08),
        sparkColor:       Color(red: 0.4, green: 0.8, blue: 1.0),
        ctxSystem:        Color(red: 0.6, green: 0.5, blue: 1.0),
        ctxUser:          Color(red: 0.4, green: 0.8, blue: 1.0),
        ctxTool:          Color(red: 1.0, green: 0.73, blue: 0.27),
        ctxReasoning:     Color(red: 0.4, green: 1.0, blue: 0.67),
        ctxSubagent:      Color(red: 1.0, green: 0.5, blue: 0.6),
        bubbleThinking:   Color(red: 0.06, green: 0.08, blue: 0.15),
        bubbleUser:       Color(red: 0.1, green: 0.08, blue: 0.18),
        bubbleAssistant:  Color(red: 0.04, green: 0.08, blue: 0.12),
        toolRunningBg:    Color(red: 0.08, green: 0.06, blue: 0.02),
        toolCompleteBg:   Color(red: 0.02, green: 0.06, blue: 0.04),
        toolErrorBg:      Color(red: 0.08, green: 0.02, blue: 0.02),
        discoveryFile:    Color(red: 0.4, green: 0.8, blue: 1.0),
        discoveryPattern: Color(red: 0.6, green: 0.5, blue: 1.0),
        discoveryFinding: Color(red: 0.4, green: 1.0, blue: 0.67),
        discoveryCode:    Color(red: 1.0, green: 0.73, blue: 0.27),
        clusterColors: [
            Color(red: 0.4, green: 0.8, blue: 1.0),
            Color(red: 0.7, green: 0.5, blue: 1.0),
            Color(red: 0.4, green: 1.0, blue: 0.67),
            Color(red: 1.0, green: 0.73, blue: 0.27),
            Color(red: 1.0, green: 0.5, blue: 0.7),
            Color(red: 0.5, green: 0.9, blue: 0.5),
        ],
        particleDispatch:   Color(red: 0.4, green: 0.8, blue: 1.0),
        particleReturn:     Color(red: 0.4, green: 1.0, blue: 0.67),
        particleToolCall:   Color(red: 1.0, green: 0.73, blue: 0.27),
        particleToolReturn: Color(red: 0.6, green: 0.5, blue: 1.0),
        uiBackground:    Color(red: 0.03, green: 0.03, blue: 0.06),
        uiAccent:        Color(red: 0.4, green: 0.8, blue: 1.0),
        uiBorder:        Color(red: 0.4, green: 0.8, blue: 1.0),
        starColor:       .white
    )

    /// Circuit — PCB traces, chip packages, manhattan routing on dark green substrate
    static let circuit = Theme(
        name: "Circuit",
        icon: "cpu",
        style: .circuit,
        voidColor:        Color(red: 0.04, green: 0.07, blue: 0.04),
        voidColorAlt:     Color(red: 0.05, green: 0.09, blue: 0.05),
        spotlightColor:   Color(red: 0.1, green: 0.2, blue: 0.1),
        primary:          Color(red: 0.8, green: 0.6, blue: 0.2),  // copper
        secondary:        Color(red: 0.2, green: 0.8, blue: 0.3),  // solder green
        success:          Color(red: 0.3, green: 1.0, blue: 0.4),
        error:            Color(red: 1.0, green: 0.3, blue: 0.2),
        thinking:         Color(red: 0.8, green: 0.6, blue: 0.2),
        permission:       Color(red: 1.0, green: 0.8, blue: 0.2),
        agentFillTop:     Color(red: 0.06, green: 0.10, blue: 0.06),
        agentFillBottom:  Color(red: 0.03, green: 0.06, blue: 0.03),
        sparkColor:       Color(red: 0.8, green: 0.6, blue: 0.2),
        ctxSystem:        Color(red: 0.6, green: 0.45, blue: 0.15),
        ctxUser:          Color(red: 0.8, green: 0.6, blue: 0.2),
        ctxTool:          Color(red: 0.2, green: 0.8, blue: 0.3),
        ctxReasoning:     Color(red: 0.3, green: 1.0, blue: 0.4),
        ctxSubagent:      Color(red: 0.6, green: 0.8, blue: 0.3),
        bubbleThinking:   Color(red: 0.05, green: 0.08, blue: 0.05),
        bubbleUser:       Color(red: 0.06, green: 0.10, blue: 0.06),
        bubbleAssistant:  Color(red: 0.04, green: 0.07, blue: 0.04),
        toolRunningBg:    Color(red: 0.05, green: 0.08, blue: 0.04),
        toolCompleteBg:   Color(red: 0.03, green: 0.06, blue: 0.03),
        toolErrorBg:      Color(red: 0.08, green: 0.04, blue: 0.03),
        discoveryFile:    Color(red: 0.8, green: 0.6, blue: 0.2),
        discoveryPattern: Color(red: 0.6, green: 0.45, blue: 0.15),
        discoveryFinding: Color(red: 0.3, green: 1.0, blue: 0.4),
        discoveryCode:    Color(red: 0.2, green: 0.8, blue: 0.3),
        clusterColors: [
            Color(red: 0.8, green: 0.6, blue: 0.2),
            Color(red: 0.2, green: 0.8, blue: 0.3),
            Color(red: 0.3, green: 1.0, blue: 0.4),
            Color(red: 0.6, green: 0.8, blue: 0.3),
            Color(red: 0.9, green: 0.7, blue: 0.25),
            Color(red: 0.4, green: 0.9, blue: 0.5),
        ],
        particleDispatch:   Color(red: 0.8, green: 0.6, blue: 0.2),
        particleReturn:     Color(red: 0.3, green: 1.0, blue: 0.4),
        particleToolCall:   Color(red: 0.2, green: 0.8, blue: 0.3),
        particleToolReturn: Color(red: 0.6, green: 0.8, blue: 0.3),
        uiBackground:    Color(red: 0.03, green: 0.05, blue: 0.03),
        uiAccent:        Color(red: 0.8, green: 0.6, blue: 0.2),
        uiBorder:        Color(red: 0.5, green: 0.4, blue: 0.15),
        starColor:       Color(red: 0.8, green: 0.6, blue: 0.2)
    )

    /// Organism — bioluminescent forest: fern spirals, branching fronds, spider web grid, glowing spores
    static let organism = Theme(
        name: "Organism",
        icon: "leaf",
        style: .organism,
        voidColor:        Color(red: 0.02, green: 0.06, blue: 0.03),
        voidColorAlt:     Color(red: 0.03, green: 0.08, blue: 0.04),
        spotlightColor:   Color(red: 0.05, green: 0.2, blue: 0.08),
        primary:          Color(red: 0.2, green: 0.85, blue: 0.45),   // emerald green
        secondary:        Color(red: 0.4, green: 0.95, blue: 0.6),    // bright mint
        success:          Color(red: 0.3, green: 1.0, blue: 0.5),
        error:            Color(red: 0.9, green: 0.35, blue: 0.25),
        thinking:         Color(red: 0.15, green: 0.75, blue: 0.4),
        permission:       Color(red: 0.8, green: 0.7, blue: 0.2),
        agentFillTop:     Color(red: 0.03, green: 0.10, blue: 0.05),
        agentFillBottom:  Color(red: 0.02, green: 0.06, blue: 0.03),
        sparkColor:       Color(red: 0.3, green: 1.0, blue: 0.5),
        ctxSystem:        Color(red: 0.15, green: 0.5, blue: 0.3),
        ctxUser:          Color(red: 0.2, green: 0.85, blue: 0.45),
        ctxTool:          Color(red: 0.4, green: 0.95, blue: 0.6),
        ctxReasoning:     Color(red: 0.3, green: 1.0, blue: 0.5),
        ctxSubagent:      Color(red: 0.5, green: 0.8, blue: 0.4),
        bubbleThinking:   Color(red: 0.03, green: 0.08, blue: 0.04),
        bubbleUser:       Color(red: 0.04, green: 0.10, blue: 0.05),
        bubbleAssistant:  Color(red: 0.02, green: 0.07, blue: 0.03),
        toolRunningBg:    Color(red: 0.03, green: 0.08, blue: 0.04),
        toolCompleteBg:   Color(red: 0.02, green: 0.07, blue: 0.03),
        toolErrorBg:      Color(red: 0.08, green: 0.03, blue: 0.02),
        discoveryFile:    Color(red: 0.2, green: 0.85, blue: 0.45),
        discoveryPattern: Color(red: 0.15, green: 0.6, blue: 0.35),
        discoveryFinding: Color(red: 0.3, green: 1.0, blue: 0.5),
        discoveryCode:    Color(red: 0.4, green: 0.95, blue: 0.6),
        clusterColors: [
            Color(red: 0.2, green: 0.85, blue: 0.45),
            Color(red: 0.4, green: 0.95, blue: 0.6),
            Color(red: 0.3, green: 1.0, blue: 0.5),
            Color(red: 0.5, green: 0.8, blue: 0.4),
            Color(red: 0.15, green: 0.7, blue: 0.35),
            Color(red: 0.35, green: 0.9, blue: 0.55),
        ],
        particleDispatch:   Color(red: 0.3, green: 1.0, blue: 0.5),
        particleReturn:     Color(red: 0.4, green: 0.95, blue: 0.6),
        particleToolCall:   Color(red: 0.2, green: 0.85, blue: 0.45),
        particleToolReturn: Color(red: 0.5, green: 0.8, blue: 0.4),
        uiBackground:    Color(red: 0.02, green: 0.05, blue: 0.03),
        uiAccent:        Color(red: 0.2, green: 0.85, blue: 0.45),
        uiBorder:        Color(red: 0.12, green: 0.45, blue: 0.25),
        starColor:       Color(red: 0.3, green: 0.9, blue: 0.5)
    )

    /// Astral — celestial orrery with planets, orbital rings, nebula wisps
    static let astral = Theme(
        name: "Astral",
        icon: "sparkles",
        style: .astral,
        voidColor:        Color(red: 0.01, green: 0.02, blue: 0.05),
        voidColorAlt:     Color(red: 0.02, green: 0.03, blue: 0.07),
        spotlightColor:   Color(red: 0.1, green: 0.08, blue: 0.25),
        primary:          Color(red: 0.5, green: 0.6, blue: 1.0),
        secondary:        Color(red: 0.9, green: 0.7, blue: 0.4),
        success:          Color(red: 0.6, green: 0.9, blue: 1.0),
        error:            Color(red: 1.0, green: 0.4, blue: 0.4),
        thinking:         Color(red: 0.5, green: 0.6, blue: 1.0),
        permission:       Color(red: 0.9, green: 0.7, blue: 0.4),
        agentFillTop:     Color(red: 0.06, green: 0.05, blue: 0.12),
        agentFillBottom:  Color(red: 0.03, green: 0.02, blue: 0.07),
        sparkColor:       Color(red: 0.6, green: 0.7, blue: 1.0),
        ctxSystem:        Color(red: 0.4, green: 0.4, blue: 0.8),
        ctxUser:          Color(red: 0.5, green: 0.6, blue: 1.0),
        ctxTool:          Color(red: 0.9, green: 0.7, blue: 0.4),
        ctxReasoning:     Color(red: 0.6, green: 0.9, blue: 1.0),
        ctxSubagent:      Color(red: 0.7, green: 0.5, blue: 0.9),
        bubbleThinking:   Color(red: 0.04, green: 0.03, blue: 0.10),
        bubbleUser:       Color(red: 0.06, green: 0.04, blue: 0.12),
        bubbleAssistant:  Color(red: 0.03, green: 0.03, blue: 0.08),
        toolRunningBg:    Color(red: 0.05, green: 0.04, blue: 0.10),
        toolCompleteBg:   Color(red: 0.03, green: 0.04, blue: 0.08),
        toolErrorBg:      Color(red: 0.08, green: 0.03, blue: 0.03),
        discoveryFile:    Color(red: 0.5, green: 0.6, blue: 1.0),
        discoveryPattern: Color(red: 0.7, green: 0.5, blue: 0.9),
        discoveryFinding: Color(red: 0.6, green: 0.9, blue: 1.0),
        discoveryCode:    Color(red: 0.9, green: 0.7, blue: 0.4),
        clusterColors: [
            Color(red: 0.5, green: 0.6, blue: 1.0),
            Color(red: 0.9, green: 0.7, blue: 0.4),
            Color(red: 0.6, green: 0.9, blue: 1.0),
            Color(red: 0.7, green: 0.5, blue: 0.9),
            Color(red: 0.4, green: 0.8, blue: 0.7),
            Color(red: 0.8, green: 0.6, blue: 1.0),
        ],
        particleDispatch:   Color(red: 0.5, green: 0.6, blue: 1.0),
        particleReturn:     Color(red: 0.6, green: 0.9, blue: 1.0),
        particleToolCall:   Color(red: 0.9, green: 0.7, blue: 0.4),
        particleToolReturn: Color(red: 0.7, green: 0.5, blue: 0.9),
        uiBackground:    Color(red: 0.02, green: 0.02, blue: 0.06),
        uiAccent:        Color(red: 0.5, green: 0.6, blue: 1.0),
        uiBorder:        Color(red: 0.3, green: 0.3, blue: 0.6),
        starColor:       Color(red: 0.7, green: 0.8, blue: 1.0)
    )

    /// Tactical — Ender's Game holographic display: concentric rings, amber core, ice-blue arcs
    static let tactical = Theme(
        name: "Tactical",
        icon: "scope",
        style: .tactical,
        voidColor:        Color(red: 0.02, green: 0.03, blue: 0.05),
        voidColorAlt:     Color(red: 0.03, green: 0.04, blue: 0.07),
        spotlightColor:   Color(red: 0.15, green: 0.12, blue: 0.08),
        primary:          Color(red: 0.5, green: 0.75, blue: 0.9),    // ice blue
        secondary:        Color(red: 1.0, green: 0.6, blue: 0.2),     // amber/orange
        success:          Color(red: 0.5, green: 0.9, blue: 0.7),
        error:            Color(red: 1.0, green: 0.35, blue: 0.3),
        thinking:         Color(red: 0.5, green: 0.75, blue: 0.9),
        permission:       Color(red: 1.0, green: 0.7, blue: 0.3),
        agentFillTop:     Color(red: 0.04, green: 0.05, blue: 0.08),
        agentFillBottom:  Color(red: 0.02, green: 0.03, blue: 0.05),
        sparkColor:       Color(red: 1.0, green: 0.6, blue: 0.2),
        ctxSystem:        Color(red: 0.4, green: 0.55, blue: 0.7),
        ctxUser:          Color(red: 0.5, green: 0.75, blue: 0.9),
        ctxTool:          Color(red: 1.0, green: 0.6, blue: 0.2),
        ctxReasoning:     Color(red: 0.5, green: 0.9, blue: 0.7),
        ctxSubagent:      Color(red: 0.7, green: 0.6, blue: 0.9),
        bubbleThinking:   Color(red: 0.04, green: 0.05, blue: 0.08),
        bubbleUser:       Color(red: 0.05, green: 0.06, blue: 0.10),
        bubbleAssistant:  Color(red: 0.03, green: 0.04, blue: 0.07),
        toolRunningBg:    Color(red: 0.06, green: 0.04, blue: 0.02),
        toolCompleteBg:   Color(red: 0.02, green: 0.05, blue: 0.04),
        toolErrorBg:      Color(red: 0.06, green: 0.02, blue: 0.02),
        discoveryFile:    Color(red: 0.5, green: 0.75, blue: 0.9),
        discoveryPattern: Color(red: 0.7, green: 0.6, blue: 0.9),
        discoveryFinding: Color(red: 0.5, green: 0.9, blue: 0.7),
        discoveryCode:    Color(red: 1.0, green: 0.6, blue: 0.2),
        clusterColors: [
            Color(red: 0.5, green: 0.75, blue: 0.9),
            Color(red: 1.0, green: 0.6, blue: 0.2),
            Color(red: 0.5, green: 0.9, blue: 0.7),
            Color(red: 0.7, green: 0.6, blue: 0.9),
            Color(red: 0.9, green: 0.5, blue: 0.3),
            Color(red: 0.4, green: 0.8, blue: 0.8),
        ],
        particleDispatch:   Color(red: 1.0, green: 0.6, blue: 0.2),
        particleReturn:     Color(red: 0.5, green: 0.9, blue: 0.7),
        particleToolCall:   Color(red: 0.5, green: 0.75, blue: 0.9),
        particleToolReturn: Color(red: 0.7, green: 0.6, blue: 0.9),
        uiBackground:    Color(red: 0.02, green: 0.03, blue: 0.05),
        uiAccent:        Color(red: 0.5, green: 0.75, blue: 0.9),
        uiBorder:        Color(red: 0.3, green: 0.4, blue: 0.55),
        starColor:       Color(red: 0.5, green: 0.7, blue: 0.85)
    )

    /// Ironman — Jarvis HUD: chunky segmented ring gauges, angular circuit connectors, scanning lines
    static let ironman = Theme(
        name: "Jarvis",
        icon: "shield.lefthalf.filled",
        style: .ironman,
        voidColor:        Color(red: 0.03, green: 0.05, blue: 0.10),
        voidColorAlt:     Color(red: 0.04, green: 0.07, blue: 0.14),
        spotlightColor:   Color(red: 0.05, green: 0.15, blue: 0.3),
        primary:          Color(red: 0.0, green: 0.75, blue: 1.0),     // electric cyan
        secondary:        Color(red: 0.3, green: 0.9, blue: 1.0),      // bright cyan
        success:          Color(red: 0.2, green: 0.9, blue: 0.6),
        error:            Color(red: 1.0, green: 0.3, blue: 0.2),
        thinking:         Color(red: 0.0, green: 0.75, blue: 1.0),
        permission:       Color(red: 1.0, green: 0.7, blue: 0.2),
        agentFillTop:     Color(red: 0.04, green: 0.08, blue: 0.16),
        agentFillBottom:  Color(red: 0.02, green: 0.04, blue: 0.10),
        sparkColor:       Color(red: 0.0, green: 0.85, blue: 1.0),
        ctxSystem:        Color(red: 0.0, green: 0.5, blue: 0.7),
        ctxUser:          Color(red: 0.0, green: 0.75, blue: 1.0),
        ctxTool:          Color(red: 0.3, green: 0.9, blue: 1.0),
        ctxReasoning:     Color(red: 0.2, green: 0.9, blue: 0.6),
        ctxSubagent:      Color(red: 0.4, green: 0.7, blue: 1.0),
        bubbleThinking:   Color(red: 0.03, green: 0.06, blue: 0.12),
        bubbleUser:       Color(red: 0.04, green: 0.08, blue: 0.16),
        bubbleAssistant:  Color(red: 0.02, green: 0.05, blue: 0.10),
        toolRunningBg:    Color(red: 0.03, green: 0.06, blue: 0.12),
        toolCompleteBg:   Color(red: 0.02, green: 0.06, blue: 0.08),
        toolErrorBg:      Color(red: 0.08, green: 0.03, blue: 0.03),
        discoveryFile:    Color(red: 0.0, green: 0.75, blue: 1.0),
        discoveryPattern: Color(red: 0.4, green: 0.7, blue: 1.0),
        discoveryFinding: Color(red: 0.2, green: 0.9, blue: 0.6),
        discoveryCode:    Color(red: 0.3, green: 0.9, blue: 1.0),
        clusterColors: [
            Color(red: 0.0, green: 0.75, blue: 1.0),
            Color(red: 0.3, green: 0.9, blue: 1.0),
            Color(red: 0.2, green: 0.9, blue: 0.6),
            Color(red: 0.4, green: 0.7, blue: 1.0),
            Color(red: 0.0, green: 0.6, blue: 0.85),
            Color(red: 0.5, green: 0.85, blue: 1.0),
        ],
        particleDispatch:   Color(red: 0.0, green: 0.85, blue: 1.0),
        particleReturn:     Color(red: 0.2, green: 0.9, blue: 0.6),
        particleToolCall:   Color(red: 0.3, green: 0.9, blue: 1.0),
        particleToolReturn: Color(red: 0.4, green: 0.7, blue: 1.0),
        uiBackground:    Color(red: 0.03, green: 0.05, blue: 0.10),
        uiAccent:        Color(red: 0.0, green: 0.75, blue: 1.0),
        uiBorder:        Color(red: 0.0, green: 0.4, blue: 0.6),
        starColor:       Color(red: 0.3, green: 0.7, blue: 1.0)
    )

    /// Animus — Assassin's Creed memory deconstruction: monochrome pixel fragments, wireframe mesh, glitch
    static let animus = Theme(
        name: "Animus",
        icon: "eye.trianglebadge.exclamationmark",
        style: .animus,
        voidColor:        Color(red: 0.01, green: 0.01, blue: 0.02),
        voidColorAlt:     Color(red: 0.02, green: 0.02, blue: 0.03),
        spotlightColor:   Color(red: 0.08, green: 0.08, blue: 0.12),
        primary:          Color(red: 0.85, green: 0.85, blue: 0.9),    // near-white
        secondary:        Color(red: 0.7, green: 0.7, blue: 0.75),     // light gray
        success:          Color(red: 0.75, green: 0.85, blue: 0.8),
        error:            Color(red: 0.9, green: 0.5, blue: 0.5),
        thinking:         Color(red: 0.8, green: 0.8, blue: 0.85),
        permission:       Color(red: 0.9, green: 0.8, blue: 0.6),
        agentFillTop:     Color(red: 0.06, green: 0.06, blue: 0.08),
        agentFillBottom:  Color(red: 0.02, green: 0.02, blue: 0.03),
        sparkColor:       Color(red: 0.9, green: 0.9, blue: 0.95),
        ctxSystem:        Color(red: 0.5, green: 0.5, blue: 0.55),
        ctxUser:          Color(red: 0.8, green: 0.8, blue: 0.85),
        ctxTool:          Color(red: 0.65, green: 0.65, blue: 0.7),
        ctxReasoning:     Color(red: 0.75, green: 0.75, blue: 0.8),
        ctxSubagent:      Color(red: 0.6, green: 0.6, blue: 0.65),
        bubbleThinking:   Color(red: 0.04, green: 0.04, blue: 0.06),
        bubbleUser:       Color(red: 0.06, green: 0.06, blue: 0.08),
        bubbleAssistant:  Color(red: 0.03, green: 0.03, blue: 0.05),
        toolRunningBg:    Color(red: 0.04, green: 0.04, blue: 0.06),
        toolCompleteBg:   Color(red: 0.03, green: 0.04, blue: 0.04),
        toolErrorBg:      Color(red: 0.06, green: 0.03, blue: 0.03),
        discoveryFile:    Color(red: 0.8, green: 0.8, blue: 0.85),
        discoveryPattern: Color(red: 0.6, green: 0.6, blue: 0.65),
        discoveryFinding: Color(red: 0.75, green: 0.8, blue: 0.75),
        discoveryCode:    Color(red: 0.7, green: 0.7, blue: 0.75),
        clusterColors: [
            Color(red: 0.85, green: 0.85, blue: 0.9),
            Color(red: 0.65, green: 0.65, blue: 0.75),
            Color(red: 0.75, green: 0.8, blue: 0.75),
            Color(red: 0.7, green: 0.7, blue: 0.8),
            Color(red: 0.6, green: 0.65, blue: 0.7),
            Color(red: 0.8, green: 0.8, blue: 0.85),
        ],
        particleDispatch:   Color(red: 0.9, green: 0.9, blue: 0.95),
        particleReturn:     Color(red: 0.75, green: 0.8, blue: 0.75),
        particleToolCall:   Color(red: 0.8, green: 0.8, blue: 0.85),
        particleToolReturn: Color(red: 0.7, green: 0.7, blue: 0.75),
        uiBackground:    Color(red: 0.02, green: 0.02, blue: 0.03),
        uiAccent:        Color(red: 0.8, green: 0.8, blue: 0.85),
        uiBorder:        Color(red: 0.3, green: 0.3, blue: 0.35),
        starColor:       Color(red: 0.8, green: 0.8, blue: 0.85)
    )

    /// Forge — Industrial mechanical hologram: stacked cylinders, pipe connectors, perspective wireframe
    static let forge = Theme(
        name: "Forge",
        icon: "gearshape.2",
        style: .forge,
        voidColor:        Color(red: 0.03, green: 0.02, blue: 0.01),
        voidColorAlt:     Color(red: 0.05, green: 0.03, blue: 0.02),
        spotlightColor:   Color(red: 0.25, green: 0.12, blue: 0.04),
        primary:          Color(red: 1.0, green: 0.55, blue: 0.15),    // amber/orange
        secondary:        Color(red: 1.0, green: 0.8, blue: 0.25),     // warm yellow
        success:          Color(red: 1.0, green: 0.85, blue: 0.35),
        error:            Color(red: 0.9, green: 0.2, blue: 0.15),
        thinking:         Color(red: 1.0, green: 0.55, blue: 0.15),
        permission:       Color(red: 1.0, green: 0.4, blue: 0.1),
        agentFillTop:     Color(red: 0.08, green: 0.05, blue: 0.02),
        agentFillBottom:  Color(red: 0.04, green: 0.02, blue: 0.01),
        sparkColor:       Color(red: 1.0, green: 0.7, blue: 0.2),
        ctxSystem:        Color(red: 0.7, green: 0.35, blue: 0.1),
        ctxUser:          Color(red: 1.0, green: 0.55, blue: 0.15),
        ctxTool:          Color(red: 1.0, green: 0.8, blue: 0.25),
        ctxReasoning:     Color(red: 1.0, green: 0.85, blue: 0.35),
        ctxSubagent:      Color(red: 0.85, green: 0.45, blue: 0.15),
        bubbleThinking:   Color(red: 0.06, green: 0.04, blue: 0.02),
        bubbleUser:       Color(red: 0.08, green: 0.05, blue: 0.02),
        bubbleAssistant:  Color(red: 0.05, green: 0.03, blue: 0.01),
        toolRunningBg:    Color(red: 0.06, green: 0.04, blue: 0.01),
        toolCompleteBg:   Color(red: 0.05, green: 0.04, blue: 0.02),
        toolErrorBg:      Color(red: 0.08, green: 0.02, blue: 0.01),
        discoveryFile:    Color(red: 1.0, green: 0.55, blue: 0.15),
        discoveryPattern: Color(red: 0.7, green: 0.35, blue: 0.1),
        discoveryFinding: Color(red: 1.0, green: 0.85, blue: 0.35),
        discoveryCode:    Color(red: 1.0, green: 0.8, blue: 0.25),
        clusterColors: [
            Color(red: 1.0, green: 0.55, blue: 0.15),
            Color(red: 1.0, green: 0.8, blue: 0.25),
            Color(red: 0.9, green: 0.35, blue: 0.15),
            Color(red: 1.0, green: 0.65, blue: 0.2),
            Color(red: 0.85, green: 0.45, blue: 0.1),
            Color(red: 1.0, green: 0.75, blue: 0.3),
        ],
        particleDispatch:   Color(red: 1.0, green: 0.7, blue: 0.2),
        particleReturn:     Color(red: 1.0, green: 0.85, blue: 0.35),
        particleToolCall:   Color(red: 1.0, green: 0.55, blue: 0.15),
        particleToolReturn: Color(red: 0.85, green: 0.45, blue: 0.15),
        uiBackground:    Color(red: 0.03, green: 0.02, blue: 0.01),
        uiAccent:        Color(red: 1.0, green: 0.55, blue: 0.15),
        uiBorder:        Color(red: 0.6, green: 0.3, blue: 0.1),
        starColor:       Color(red: 1.0, green: 0.7, blue: 0.3)
    )

    /// Tron — Digital frontier: identity discs, light cycle trails, perspective Grid, neon on black
    static let tron = Theme(
        name: "Tron",
        icon: "circle.circle",
        style: .tron,
        voidColor:        Color(red: 0.0, green: 0.0, blue: 0.02),
        voidColorAlt:     Color(red: 0.0, green: 0.01, blue: 0.03),
        spotlightColor:   Color(red: 0.0, green: 0.1, blue: 0.15),
        primary:          Color(red: 0.0, green: 0.87, blue: 1.0),     // electric blue
        secondary:        Color(red: 1.0, green: 0.4, blue: 0.07),     // Clu orange
        success:          Color(red: 0.0, green: 0.9, blue: 0.6),
        error:            Color(red: 1.0, green: 0.2, blue: 0.15),
        thinking:         Color(red: 0.0, green: 0.87, blue: 1.0),
        permission:       Color(red: 1.0, green: 0.5, blue: 0.1),
        agentFillTop:     Color(red: 0.0, green: 0.03, blue: 0.05),
        agentFillBottom:  Color(red: 0.0, green: 0.01, blue: 0.02),
        sparkColor:       Color(red: 0.0, green: 0.9, blue: 1.0),
        ctxSystem:        Color(red: 0.0, green: 0.5, blue: 0.6),
        ctxUser:          Color(red: 0.0, green: 0.87, blue: 1.0),
        ctxTool:          Color(red: 1.0, green: 0.4, blue: 0.07),
        ctxReasoning:     Color(red: 0.0, green: 0.9, blue: 0.6),
        ctxSubagent:      Color(red: 0.5, green: 0.6, blue: 1.0),
        bubbleThinking:   Color(red: 0.0, green: 0.02, blue: 0.04),
        bubbleUser:       Color(red: 0.03, green: 0.02, blue: 0.0),
        bubbleAssistant:  Color(red: 0.0, green: 0.02, blue: 0.03),
        toolRunningBg:    Color(red: 0.03, green: 0.02, blue: 0.0),
        toolCompleteBg:   Color(red: 0.0, green: 0.03, blue: 0.02),
        toolErrorBg:      Color(red: 0.04, green: 0.01, blue: 0.01),
        discoveryFile:    Color(red: 0.0, green: 0.87, blue: 1.0),
        discoveryPattern: Color(red: 0.5, green: 0.6, blue: 1.0),
        discoveryFinding: Color(red: 0.0, green: 0.9, blue: 0.6),
        discoveryCode:    Color(red: 1.0, green: 0.4, blue: 0.07),
        clusterColors: [
            Color(red: 0.0, green: 0.87, blue: 1.0),
            Color(red: 1.0, green: 0.4, blue: 0.07),
            Color(red: 0.0, green: 0.9, blue: 0.6),
            Color(red: 0.5, green: 0.6, blue: 1.0),
            Color(red: 0.0, green: 0.7, blue: 0.85),
            Color(red: 0.8, green: 0.5, blue: 0.1),
        ],
        particleDispatch:   Color(red: 0.0, green: 0.87, blue: 1.0),
        particleReturn:     Color(red: 0.0, green: 0.9, blue: 0.6),
        particleToolCall:   Color(red: 1.0, green: 0.4, blue: 0.07),
        particleToolReturn: Color(red: 0.5, green: 0.6, blue: 1.0),
        uiBackground:    Color(red: 0.0, green: 0.0, blue: 0.02),
        uiAccent:        Color(red: 0.0, green: 0.87, blue: 1.0),
        uiBorder:        Color(red: 0.0, green: 0.4, blue: 0.5),
        starColor:       Color(red: 0.0, green: 0.7, blue: 0.85)
    )

    static let allThemes: [Theme] = [.holograph, .circuit, .organism, .astral, .tactical, .ironman, .animus, .forge, .tron]
}
