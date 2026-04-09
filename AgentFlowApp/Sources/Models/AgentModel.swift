import Foundation
import SwiftUI

// MARK: - Agent State

enum AgentState: String, CaseIterable {
    case idle
    case thinking
    case toolCalling
    case complete
    case error
    case waitingPermission

    var color: Color {
        switch self {
        case .idle, .thinking: return Color(red: 0.4, green: 0.8, blue: 1.0)     // cyan
        case .toolCalling:     return Color(red: 1.0, green: 0.73, blue: 0.27)    // orange
        case .complete:        return Color(red: 0.4, green: 1.0, blue: 0.67)     // green
        case .error:           return Color(red: 1.0, green: 0.33, blue: 0.4)     // red
        case .waitingPermission: return Color(red: 1.0, green: 0.67, blue: 0.2)   // amber
        }
    }

    var cgColor: CGColor {
        switch self {
        case .idle, .thinking: return CGColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1)
        case .toolCalling:     return CGColor(red: 1.0, green: 0.73, blue: 0.27, alpha: 1)
        case .complete:        return CGColor(red: 0.4, green: 1.0, blue: 0.67, alpha: 1)
        case .error:           return CGColor(red: 1.0, green: 0.33, blue: 0.4, alpha: 1)
        case .waitingPermission: return CGColor(red: 1.0, green: 0.67, blue: 0.2, alpha: 1)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: Identifiable {
    let id = UUID()
    var role: MessageRole
    var text: String
    var createdAt: Double
    var opacity: Double = 1.0
    var offsetY: Double = 0

    enum MessageRole {
        case thinking, user, assistant

        var color: Color {
            switch self {
            case .thinking:  return Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.5)
            case .user:      return Color(red: 0.6, green: 0.5, blue: 1.0)
            case .assistant: return Color(red: 0.4, green: 0.8, blue: 1.0)
            }
        }
    }
}

// MARK: - Context Breakdown

struct ContextBreakdown {
    var systemPrompt: Int = 0
    var userMessages: Int = 0
    var toolResults: Int = 0
    var reasoning: Int = 0
    var subagentResults: Int = 0

    var total: Int { systemPrompt + userMessages + toolResults + reasoning + subagentResults }
}

// MARK: - Agent Model

struct AgentModel: Identifiable {
    let id: String
    var name: String
    var parentId: String?
    var sessionId: String?
    var state: AgentState = .idle
    var position: CGPoint = .zero
    var velocity: CGPoint = .zero
    var radius: CGFloat = 28
    var isMain: Bool = false
    var isPinned: Bool = false

    var tokensUsed: Int = 0
    var tokensMax: Int = 200_000
    var toolCallCount: Int = 0
    var context: ContextBreakdown = ContextBreakdown()

    var messages: [MessageBubble] = []
    var spawnTime: Double = 0
    var completeTime: Double?

    // Animation state
    var opacity: Double = 0.0
    var scale: Double = 0.5
    var breathPhase: Double = 0
    var scanlineOffset: Double = 0

    var isActive: Bool { state == .thinking || state == .toolCalling }
}

// MARK: - Session Cluster

struct SessionCluster: Identifiable {
    let id: String
    var label: String
    var source: EventSource
    var center: CGPoint = .zero
    var agentCount: Int = 0
    var isActive: Bool = true
    var lastEventTime: Double = 0
    var completedTime: Double?
    var dimAmount: Double = 0  // 0 = fully bright, 1 = fully dimmed
}

// MARK: - Tool Call

enum ToolCallState {
    case running, complete, error
}

struct ToolCallModel: Identifiable {
    let id: String
    var agentId: String
    var name: String
    var args: String
    var result: String?
    var state: ToolCallState = .running
    var tokenCost: Int = 0
    var errorMessage: String?

    var position: CGPoint = .zero
    var opacity: Double = 0.0
    var pulsePhase: Double = 0
    var createdAt: Double = 0
    var completedAt: Double?
}

// MARK: - Edge

enum EdgeType {
    case parentChild
    case tool
}

struct EdgeModel: Identifiable {
    let id: String
    var sourceId: String
    var targetId: String
    var type: EdgeType = .parentChild
    var opacity: Double = 0.0
    var isActive: Bool = true
}

// MARK: - Particle

enum ParticleType {
    case dispatch, `return`, toolCall, toolReturn
}

struct ParticleModel: Identifiable {
    let id = UUID()
    var edgeId: String
    var progress: Double = 0.0
    var type: ParticleType
    var label: String?
    var wobblePhase: Double = 0
    var opacity: Double = 1.0

    var color: Color {
        switch type {
        case .dispatch:   return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .return:     return Color(red: 0.4, green: 1.0, blue: 0.67)
        case .toolCall:   return Color(red: 1.0, green: 0.73, blue: 0.27)
        case .toolReturn: return Color(red: 0.6, green: 0.5, blue: 1.0)
        }
    }
}

// MARK: - Discovery

enum DiscoveryType {
    case file, pattern, finding, code

    var color: Color {
        switch self {
        case .file:    return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .pattern: return Color(red: 0.6, green: 0.5, blue: 1.0)
        case .finding: return Color(red: 0.4, green: 1.0, blue: 0.67)
        case .code:    return Color(red: 1.0, green: 0.73, blue: 0.27)
        }
    }
}

struct DiscoveryModel: Identifiable {
    let id = UUID()
    var agentId: String
    var type: DiscoveryType
    var label: String
    var content: String
    var position: CGPoint = .zero
    var targetPosition: CGPoint = .zero
    var opacity: Double = 0.0
    var createdAt: Double = 0
}

// MARK: - Depth Particle (Background)

struct DepthParticle {
    var position: CGPoint
    var brightness: Double
    var depth: Double
    var size: CGFloat
}

// MARK: - Spawn Effect

struct SpawnEffect {
    var position: CGPoint
    var createdAt: Double
    var duration: Double = 0.8
    var segments: [(angle: Double, length: Double)] = []
}

// MARK: - Complete Effect

struct CompleteEffect {
    var position: CGPoint
    var createdAt: Double
    var duration: Double = 1.0
    var fragments: [(position: CGPoint, velocity: CGPoint, opacity: Double)] = []
}
