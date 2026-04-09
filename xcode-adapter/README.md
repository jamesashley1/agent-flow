# Xcode Adapter for Agent Flow

Bridges Xcode's built-in Claude coding assistant (Xcode 26+) into Agent Flow's
native macOS visualization.

## How It Works

Two-process pipeline:

1. **`bridge.js`** — Tails Xcode assistant conversation logs, translates turns
   into Agent Flow events, and writes them to a JSONL file
2. **`event-log-tail.js`** — Tails the JSONL file and POSTs each event to the
   Agent Flow hook server for merging into the live visualization

```
Xcode logs → bridge.js → xcode-bridge.jsonl → event-log-tail.js → hook server → Agent Flow
```

## Setup

```bash
# Terminal 1: tail Xcode assistant logs
node xcode-adapter/bridge.js

# Terminal 2: forward events to Agent Flow
node xcode-adapter/event-log-tail.js
```

Override the Xcode log scan directory if needed:

```bash
XCODE_ASSISTANT_LOG_DIR=/path/to/logs node xcode-adapter/bridge.js
```

## Config (environment variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `XCODE_ASSISTANT_LOG_DIR` | Auto-detected | Override Xcode conversation log directory |
| `AGENT_FLOW_EVENT_LOG` | `~/.claude/agent-flow/xcode-bridge.jsonl` | Output event log path |
| `BRIDGE_POLL_MS` | `1000` | Bridge poll interval (ms) |
| `AGENT_FLOW_HOOK_PORT` | `3100` | Hook server port for event-log-tail |

## Files

| File | Purpose |
|------|---------|
| `bridge.js` | Tails Xcode assistant logs, writes JSONL events (offsets persisted) |
| `event-log-tail.js` | Tails JSONL event log, POSTs to hook server |
| `swift-summarizer.ts` | Swift/xcodebuild-aware tool summarizer |
| `test-events.jsonl` | Sample session for testing without Xcode |
| `AgentFlowCompanion/` | SwiftUI menu-bar app (runs bridge for you) |
| `AgentFlowXcodeExtension/` | Xcode Source Editor Extension |

## Test Without Xcode

```bash
# Start event-log-tail, then feed sample events:
cat xcode-adapter/test-events.jsonl >> ~/.claude/agent-flow/xcode-bridge.jsonl
```
