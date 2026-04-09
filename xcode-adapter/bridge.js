#!/usr/bin/env node
/**
 * Xcode Coding Assistant → Agent Flow bridge.
 *
 * Tails Xcode's Claude assistant conversation files and emits agent-flow
 * compatible events into a JSONL file that Agent Flow watches.
 *
 * Offsets are persisted to disk so restarts don't replay events.
 *
 * Config (env):
 *   XCODE_ASSISTANT_LOG_DIR   override the scan dir
 *   AGENT_FLOW_EVENT_LOG      output path (default ~/.claude/agent-flow/xcode-bridge.jsonl)
 *   BRIDGE_POLL_MS            poll interval (default 1000)
 *
 * Output events match extension/src/protocol.ts AgentEvent.
 */
'use strict'

const fs = require('fs')
const path = require('path')
const os = require('os')

// ─── Candidate Xcode log locations (version-specific; try all) ──────────────

const HOME = os.homedir()
const CANDIDATE_DIRS = [
  process.env.XCODE_ASSISTANT_LOG_DIR,
  path.join(HOME, 'Library/Developer/Xcode/UserData/ClaudeAssistant/conversations'),
  path.join(HOME, 'Library/Developer/Xcode/UserData/IDEEditor/Claude/conversations'),
  path.join(HOME, 'Library/Caches/com.apple.dt.Xcode/ClaudeAssistant'),
  path.join(HOME, 'Library/Containers/com.apple.dt.Xcode/Data/Library/Application Support/Xcode/ClaudeAssistant'),
].filter(Boolean)

const OUT_PATH = process.env.AGENT_FLOW_EVENT_LOG ||
  path.join(HOME, '.claude/agent-flow/xcode-bridge.jsonl')
const STATE_PATH = OUT_PATH + '.state.json'
const POLL_MS = Number(process.env.BRIDGE_POLL_MS) || 1000

// ─── Event emission ─────────────────────────────────────────────────────────

const sessionStartMs = Date.now()
const elapsed = () => Date.now() - sessionStartMs

function writeEvent(event) {
  fs.appendFileSync(OUT_PATH, JSON.stringify(event) + '\n', 'utf8')
}

function emit(type, payload, sessionId) {
  writeEvent({ time: elapsed(), type, payload, sessionId })
}

// ─── Offset persistence ─────────────────────────────────────────────────────

/** Map<absolute path, byte offset> — persisted between runs */
const seenFiles = new Map()

function loadState() {
  try {
    const raw = JSON.parse(fs.readFileSync(STATE_PATH, 'utf8'))
    for (const [k, v] of Object.entries(raw.offsets || {})) {
      seenFiles.set(k, Number(v) || 0)
    }
    console.log(`[xcode-bridge] restored ${seenFiles.size} file offset(s)`)
  } catch { /* no prior state */ }
}

let stateDirty = false
function saveStateSoon() {
  stateDirty = true
}
setInterval(() => {
  if (!stateDirty) return
  stateDirty = false
  const offsets = Object.fromEntries(seenFiles)
  const tmp = STATE_PATH + '.tmp'
  try {
    fs.writeFileSync(tmp, JSON.stringify({ offsets }, null, 2))
    fs.renameSync(tmp, STATE_PATH)
  } catch (e) { console.warn('[xcode-bridge] state save failed:', e.message) }
}, 2000)

// ─── Xcode log parsing (heuristic — swap format here when locked down) ──────

function translateTurn(turn, sessionId) {
  if (!turn || typeof turn !== 'object') return

  if (turn.role === 'user') {
    emit('message', { agent: 'orchestrator', role: 'user', content: String(turn.content ?? '') }, sessionId)
    return
  }

  if (turn.role === 'assistant') {
    if (typeof turn.content === 'string' && turn.content.trim()) {
      emit('message', { agent: 'orchestrator', role: 'assistant', content: turn.content }, sessionId)
    }
    for (const call of turn.tool_calls || []) {
      const toolId = call.id || `${call.name}-${Math.random().toString(36).slice(2, 8)}`
      const args = typeof (call.input || call.arguments) === 'object'
        ? JSON.stringify(call.input || call.arguments).slice(0, 200)
        : String(call.input || call.arguments || '')
      emit('tool_call_start', {
        agent: 'orchestrator',
        tool: call.name,
        args,
        preview: `${call.name}: ${args}`.slice(0, 80),
      }, sessionId)
      if (call.result !== undefined) {
        emit('tool_call_end', {
          agent: 'orchestrator',
          tool: call.name,
          result: typeof call.result === 'string'
            ? call.result
            : JSON.stringify(call.result).slice(0, 500),
        }, sessionId)
      }
    }
  }
}

// ─── File tailing ───────────────────────────────────────────────────────────

function processFile(filePath) {
  let stat
  try { stat = fs.statSync(filePath) } catch { return }
  const prev = seenFiles.get(filePath) || 0

  // File was truncated/rotated — reset
  if (stat.size < prev) { seenFiles.set(filePath, 0); }
  if (stat.size <= prev) return

  const start = seenFiles.get(filePath) || 0
  const fd = fs.openSync(filePath, 'r')
  const buf = Buffer.alloc(stat.size - start)
  fs.readSync(fd, buf, 0, buf.length, start)
  fs.closeSync(fd)
  seenFiles.set(filePath, stat.size)
  saveStateSoon()

  const sessionId = path.basename(filePath, path.extname(filePath))
  for (const line of buf.toString('utf8').split(/\r?\n/)) {
    if (!line.trim()) continue
    try { translateTurn(JSON.parse(line), sessionId) }
    catch { /* non-JSON — skip */ }
  }
}

function scan() {
  for (const dir of CANDIDATE_DIRS) {
    let entries
    try { entries = fs.readdirSync(dir) } catch { continue }
    for (const name of entries) {
      if (!/\.(jsonl?|log|txt|ndjson)$/i.test(name)) continue
      const full = path.join(dir, name)
      if (!seenFiles.has(full)) {
        const sessionId = path.basename(name, path.extname(name))
        emit('agent_spawn',
          { name: 'orchestrator', isMain: true, task: `Xcode session ${sessionId}` },
          sessionId)
        seenFiles.set(full, 0)
      }
      processFile(full)
    }
  }
}

// ─── Main ───────────────────────────────────────────────────────────────────

fs.mkdirSync(path.dirname(OUT_PATH), { recursive: true })
if (!fs.existsSync(OUT_PATH)) fs.writeFileSync(OUT_PATH, '')

loadState()

console.log('[xcode-bridge] candidate dirs:')
for (const d of CANDIDATE_DIRS) {
  console.log(' ', fs.existsSync(d) ? '✓' : '·', d)
}
console.log('[xcode-bridge] output:', OUT_PATH)
console.log('[xcode-bridge] state :', STATE_PATH)

scan()
setInterval(scan, POLL_MS)

process.on('SIGINT', () => { stateDirty = true; process.exit(0) })
