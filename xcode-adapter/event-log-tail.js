#!/usr/bin/env node
/**
 * Event-log tail source for Agent Flow dev-relay.
 *
 * Tails a JSONL event-log file and POSTs each event to the dev-relay hook
 * server (port 3100 by default). Lets any source write AgentEvents to a
 * file and have them merged into the live visualization alongside Claude
 * Code hook events and session-watcher events.
 *
 * Usage:
 *   node xcode-adapter/event-log-tail.js --file <path> [--port 3100]
 *   AGENT_FLOW_EVENT_LOG=<path> node xcode-adapter/event-log-tail.js
 */
'use strict'

const fs = require('fs')
const http = require('http')
const path = require('path')
const os = require('os')

// ─── Args ───────────────────────────────────────────────────────────────────

function arg(flag, fallback) {
  const i = process.argv.indexOf(flag)
  return i >= 0 ? process.argv[i + 1] : fallback
}

const FILE = arg('--file', process.env.AGENT_FLOW_EVENT_LOG ||
  path.join(os.homedir(), '.claude/agent-flow/xcode-bridge.jsonl'))
const HOOK_PORT = Number(arg('--port', process.env.AGENT_FLOW_HOOK_PORT || 3100))
const STATE = FILE + '.tail-offset'

// ─── Offset persistence (dedup across restarts) ─────────────────────────────

function loadOffset() {
  try { return Number(fs.readFileSync(STATE, 'utf8')) || 0 } catch { return 0 }
}
function saveOffset(n) {
  try { fs.writeFileSync(STATE + '.tmp', String(n)); fs.renameSync(STATE + '.tmp', STATE) }
  catch {}
}

// ─── Forward event to hook server ───────────────────────────────────────────

function post(event) {
  const body = JSON.stringify({
    hook_event_name: 'AgentFlowExternalEvent',
    session_id: event.sessionId || 'xcode-default',
    event,
    cwd: process.cwd(),
  })
  const req = http.request({
    hostname: '127.0.0.1', port: HOOK_PORT,
    method: 'POST', path: '/',
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
    timeout: 1000,
  }, res => res.resume())
  req.on('error', () => {})
  req.on('timeout', () => req.destroy())
  req.write(body)
  req.end()
}

// ─── Tail loop ──────────────────────────────────────────────────────────────

let offset = loadOffset()

function poll() {
  let stat
  try { stat = fs.statSync(FILE) } catch { return }
  if (stat.size < offset) offset = 0 // rotated/truncated
  if (stat.size <= offset) return

  const fd = fs.openSync(FILE, 'r')
  const buf = Buffer.alloc(stat.size - offset)
  fs.readSync(fd, buf, 0, buf.length, offset)
  fs.closeSync(fd)
  offset = stat.size
  saveOffset(offset)

  for (const line of buf.toString('utf8').split(/\r?\n/)) {
    if (!line.trim()) continue
    try { post(JSON.parse(line)) } catch {}
  }
}

// ─── Main ───────────────────────────────────────────────────────────────────

if (!fs.existsSync(FILE)) {
  console.log(`[event-log-tail] ${FILE} does not exist yet — will poll.`)
  fs.mkdirSync(path.dirname(FILE), { recursive: true })
}

console.log(`[event-log-tail] watching ${FILE}`)
console.log(`[event-log-tail] forwarding to 127.0.0.1:${HOOK_PORT}`)
console.log(`[event-log-tail] starting offset: ${offset}`)

poll()
setInterval(poll, 500)
