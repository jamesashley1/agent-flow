import Foundation

// MARK: - Demo Scenario

/// Generates a realistic multi-session demo showing Claude agents across
/// separate CLI and Xcode sessions, each in its own cluster.
struct DemoScenario {
    struct Event {
        var delay: Double
        var action: (SimulationEngine) -> Void
    }

    static func generate() -> [Event] {
        var events: [Event] = []

        let session1 = "demo-cli-session"
        let session2 = "demo-xcode-session"

        // ── Session 1: CLI – Auth refactoring ──

        events.append(Event(delay: 0.5) { engine in
            engine.spawnAgent(id: "\(session1):main", name: "Main Agent", isMain: true,
                              sessionId: session1, sessionLabel: "CLI: agent-flow", source: .cli)
            engine.state.agents["\(session1):main"]?.state = .thinking
        })

        events.append(Event(delay: 1.0) { engine in
            engine.addMessage(agentId: "\(session1):main", role: .user,
                              text: "Refactor the auth module to use JWT tokens and add rate limiting")
        })

        events.append(Event(delay: 2.5) { engine in
            engine.addMessage(agentId: "\(session1):main", role: .thinking,
                              text: "I'll need to understand the current auth system...")
        })

        events.append(Event(delay: 3.5) { engine in
            engine.startToolCall(id: "\(session1):tc1", agentId: "\(session1):main",
                                 name: "Read", args: "src/auth/middleware.ts")
        })

        events.append(Event(delay: 5.0) { engine in
            engine.completeToolCall(id: "\(session1):tc1",
                                    result: "export function authMiddleware(req, res, next) { ... }", tokenCost: 1240)
            engine.addDiscovery(agentId: "\(session1):main", type: .file,
                                label: "middleware.ts", content: "Express middleware using session-based auth")
        })

        events.append(Event(delay: 6.0) { engine in
            engine.startToolCall(id: "\(session1):tc2", agentId: "\(session1):main",
                                 name: "Grep", args: "'authenticate' in src/")
        })

        events.append(Event(delay: 7.5) { engine in
            engine.completeToolCall(id: "\(session1):tc2",
                                    result: "Found 12 matches across 8 files", tokenCost: 890)
        })

        // CLI subagent: JWT
        events.append(Event(delay: 9.0) { engine in
            engine.spawnAgent(id: "\(session1):jwt", name: "JWT Implementation",
                              parentId: "\(session1):main", sessionId: session1,
                              sessionLabel: "CLI: agent-flow", source: .cli)
            engine.state.agents["\(session1):jwt"]?.state = .thinking
            engine.addMessage(agentId: "\(session1):jwt", role: .thinking, text: "Implementing JWT token generation and validation with RS256 signing...")
        })

        events.append(Event(delay: 10.0) { engine in
            engine.addMessage(agentId: "\(session1):jwt", role: .assistant, text: "I'll create the JWT service with sign/verify methods and a refresh token rotation strategy.")
            engine.startToolCall(id: "\(session1):tc3", agentId: "\(session1):jwt",
                                 name: "Write", args: "src/auth/jwt.ts")
        })

        events.append(Event(delay: 12.0) { engine in
            engine.completeToolCall(id: "\(session1):tc3",
                                    result: "File written: jwt.ts (84 lines)", tokenCost: 2100)
            engine.addDiscovery(agentId: "\(session1):jwt", type: .code,
                                label: "jwt.ts", content: "JWT sign/verify with RS256")
        })

        events.append(Event(delay: 13.0) { engine in
            engine.addMessage(agentId: "\(session1):jwt", role: .assistant, text: "JWT implementation complete. Created token service with RS256 signing, 15min access + 7d refresh tokens.")
        })

        // CLI subagent: Rate limiter
        events.append(Event(delay: 10.0) { engine in
            engine.spawnAgent(id: "\(session1):rate", name: "Rate Limiter",
                              parentId: "\(session1):main", sessionId: session1,
                              sessionLabel: "CLI: agent-flow", source: .cli)
            engine.state.agents["\(session1):rate"]?.state = .thinking
            engine.addMessage(agentId: "\(session1):rate", role: .thinking, text: "Setting up rate limiting with Redis-backed sliding window algorithm...")
        })

        events.append(Event(delay: 11.5) { engine in
            engine.startToolCall(id: "\(session1):tc4", agentId: "\(session1):rate",
                                 name: "Write", args: "src/middleware/rateLimiter.ts")
        })

        events.append(Event(delay: 12.0) { engine in
            engine.addMessage(agentId: "\(session1):rate", role: .assistant, text: "I'll use the existing Redis connection pool for the sliding window counters.")
        })

        events.append(Event(delay: 14.0) { engine in
            engine.completeToolCall(id: "\(session1):tc4",
                                    result: "File written: rateLimiter.ts (95 lines)", tokenCost: 2400)
            engine.addDiscovery(agentId: "\(session1):rate", type: .code,
                                label: "rateLimiter.ts", content: "Sliding window: 100 req/min per IP")
            engine.addMessage(agentId: "\(session1):rate", role: .assistant, text: "Rate limiter implemented: 100 req/min per IP, 1000 req/min per API key with Redis sliding window.")
        })

        events.append(Event(delay: 16.0) { engine in
            engine.completeAgent(id: "\(session1):jwt")
        })

        events.append(Event(delay: 17.0) { engine in
            engine.completeAgent(id: "\(session1):rate")
        })

        events.append(Event(delay: 20.0) { engine in
            engine.addMessage(agentId: "\(session1):main", role: .assistant,
                              text: "Auth refactoring complete! Migrated to JWT with rate limiting.")
            engine.completeAgent(id: "\(session1):main")
        })

        // ── Session 2: Xcode – SwiftUI view refactor ──

        events.append(Event(delay: 2.0) { engine in
            engine.spawnAgent(id: "\(session2):main", name: "Orchestrator", isMain: true,
                              sessionId: session2, sessionLabel: "Xcode: MidtermHero", source: .xcode)
            engine.state.agents["\(session2):main"]?.state = .thinking
        })

        events.append(Event(delay: 2.5) { engine in
            engine.addMessage(agentId: "\(session2):main", role: .user,
                              text: "Refactor ContentView to use @Observable and extract the timer logic")
        })

        events.append(Event(delay: 4.0) { engine in
            engine.startToolCall(id: "\(session2):tc1", agentId: "\(session2):main",
                                 name: "Read", args: "MidtermHero/ContentView.swift")
        })

        events.append(Event(delay: 5.5) { engine in
            engine.completeToolCall(id: "\(session2):tc1",
                                    result: "struct ContentView: View { @StateObject var timer ... }", tokenCost: 980)
            engine.addDiscovery(agentId: "\(session2):main", type: .file,
                                label: "ContentView.swift", content: "Uses @StateObject, needs @Observable migration")
        })

        events.append(Event(delay: 7.0) { engine in
            engine.startToolCall(id: "\(session2):tc2", agentId: "\(session2):main",
                                 name: "Read", args: "MidtermHero/TimerModel.swift")
        })

        events.append(Event(delay: 8.5) { engine in
            engine.completeToolCall(id: "\(session2):tc2",
                                    result: "class TimerModel: ObservableObject { ... }", tokenCost: 640)
        })

        // Xcode subagent: Model migration
        events.append(Event(delay: 9.5) { engine in
            engine.spawnAgent(id: "\(session2):model", name: "Model Migration",
                              parentId: "\(session2):main", sessionId: session2,
                              sessionLabel: "Xcode: MidtermHero", source: .xcode)
            engine.state.agents["\(session2):model"]?.state = .thinking
            engine.addMessage(agentId: "\(session2):model", role: .thinking, text: "Migrating TimerModel from ObservableObject to @Observable macro...")
        })

        events.append(Event(delay: 10.5) { engine in
            engine.addMessage(agentId: "\(session2):model", role: .assistant, text: "I need to replace @Published properties with plain stored properties and change the class declaration.")
        })

        events.append(Event(delay: 11.0) { engine in
            engine.startToolCall(id: "\(session2):tc3", agentId: "\(session2):model",
                                 name: "Edit", args: "MidtermHero/TimerModel.swift")
        })

        events.append(Event(delay: 13.0) { engine in
            engine.completeToolCall(id: "\(session2):tc3",
                                    result: "Replaced ObservableObject → @Observable", tokenCost: 1800)
            engine.addDiscovery(agentId: "\(session2):model", type: .code,
                                label: "TimerModel.swift", content: "@Observable class with modern concurrency")
            engine.addMessage(agentId: "\(session2):model", role: .assistant, text: "Migrated TimerModel: removed @Published, added @Observable macro, updated init to use modern concurrency patterns.")
        })

        // Xcode subagent: View update
        events.append(Event(delay: 12.0) { engine in
            engine.spawnAgent(id: "\(session2):view", name: "View Updater",
                              parentId: "\(session2):main", sessionId: session2,
                              sessionLabel: "Xcode: MidtermHero", source: .xcode)
            engine.state.agents["\(session2):view"]?.state = .thinking
            engine.addMessage(agentId: "\(session2):view", role: .thinking, text: "Updating ContentView to use @State instead of @StateObject for the new @Observable model...")
        })

        events.append(Event(delay: 13.0) { engine in
            engine.addMessage(agentId: "\(session2):view", role: .assistant, text: "I'll replace @StateObject with @State and remove .environmentObject modifiers.")
        })

        events.append(Event(delay: 13.5) { engine in
            engine.startToolCall(id: "\(session2):tc4", agentId: "\(session2):view",
                                 name: "Edit", args: "MidtermHero/ContentView.swift")
        })

        events.append(Event(delay: 15.5) { engine in
            engine.completeToolCall(id: "\(session2):tc4",
                                    result: "Replaced @StateObject → @State, removed .environmentObject", tokenCost: 1500)
        })

        events.append(Event(delay: 17.0) { engine in
            engine.completeAgent(id: "\(session2):model")
        })

        events.append(Event(delay: 18.0) { engine in
            engine.completeAgent(id: "\(session2):view")
        })

        // Xcode build test
        events.append(Event(delay: 19.0) { engine in
            engine.startToolCall(id: "\(session2):tc5", agentId: "\(session2):main",
                                 name: "Bash", args: "xcodebuild -scheme MidtermHero test")
        })

        events.append(Event(delay: 22.0) { engine in
            engine.completeToolCall(id: "\(session2):tc5",
                                    result: "Build Succeeded. 12 tests passed.", tokenCost: 450)
            engine.addDiscovery(agentId: "\(session2):main", type: .finding,
                                label: "Tests pass", content: "12/12 tests passing after migration")
        })

        events.append(Event(delay: 23.0) { engine in
            engine.addMessage(agentId: "\(session2):main", role: .assistant,
                              text: "Migration complete. ContentView now uses @Observable pattern.")
            engine.completeAgent(id: "\(session2):main")
        })

        return events
    }
}
