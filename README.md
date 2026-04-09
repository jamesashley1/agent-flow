# Agent Flow

Real-time visualization of Claude Code agent orchestration. Watch your agents think, branch, and coordinate as they work.

## Overview

Agent Flow is a native macOS app that visualizes Claude Code sessions as an interactive node graph. See agents spawn, tool calls execute, subagents coordinate, and context windows fill — all in real time.

### Features

- **Live session detection** — Automatically discovers active Claude Code sessions by watching `~/.claude/projects/`
- **Multiple visual themes** — Holograph, Tron, Circuit, Astral, Organism, Tactical, and more
- **Interactive canvas** — Pan, zoom, click agents and tool calls to inspect details
- **Multi-session support** — Track concurrent agent sessions from CLI and Xcode
- **Xcode integration** — Visualize Xcode's built-in Claude assistant via the xcode-adapter bridge
- **Demo mode** — Built-in demo scenario to preview the visualization without a live session

## Requirements

- macOS 14+ (Sonoma)
- Swift 5.9+
- Claude Code CLI (for live visualization)

## Getting Started

### Build & Run

```bash
cd AgentFlowApp
swift build
swift run
```

Or open `AgentFlowApp/Package.swift` in Xcode and run the target.

### Live Mode

1. Launch Agent Flow
2. Start a Claude Code session in any terminal
3. Agent Flow auto-detects the session and streams events in real time

### Demo Mode

Click the **Demo** toggle in the top-right corner to see a sample multi-agent session.

## Xcode Assistant Bridge

To visualize Xcode's built-in Claude coding assistant (Xcode 26+), use the xcode-adapter:

```bash
# Terminal 1: tail Xcode assistant logs and write bridge events
node xcode-adapter/bridge.js

# Terminal 2: forward bridge events to Agent Flow (if using the relay pipeline)
node xcode-adapter/event-log-tail.js
```

See `xcode-adapter/README.md` for details on configuration and testing.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `F` | Zoom to fit |
| `G` | Toggle grid |
| `S` | Toggle stats |
| `P` | Toggle plan/task panel |
| `1-4` | Playback speed (0.5x, 1x, 2x, 4x) |
| `D/Shift+D` | Decrease/increase detail level |
| `Esc` | Deselect |

## Project Structure

```
AgentFlowApp/
  Sources/
    AgentFlowApp.swift          # App entry point
    Models/                     # Agent, simulation state, themes
    Views/                      # SwiftUI views and canvas
    Rendering/                  # Theme-specific renderers
    Simulation/                 # Engine, transcript parser, session watcher
xcode-adapter/
  bridge.js                     # Tails Xcode assistant logs -> JSONL events
  event-log-tail.js             # Forwards JSONL events to hook server
  swift-summarizer.ts           # Swift/xcodebuild-aware tool summarizer
```

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

Based on [agent-flow](https://github.com/patoles/agent-flow) by [Simon Patole](https://github.com/patoles).
