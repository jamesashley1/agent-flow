/**
 * Swift / Xcode-aware tool summarizer.
 *
 * Wraps the generic summarizer in extension/src/tool-summarizer.ts with
 * heuristics tuned for Swift, Xcode, and xcodebuild output. Use as a drop-in:
 *
 *   import { summarizeInputSwift } from './xcode-adapter/swift-summarizer'
 *
 * Exports are additive — they fall through to the generic summarizer for
 * anything they don't recognize.
 */

import {
  summarizeInput as genericSummarizeInput,
  summarizeResult as genericSummarizeResult,
  detectError as genericDetectError,
} from '../extension/src/tool-summarizer'

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Make a path relative to an .xcodeproj/.xcworkspace ancestor if possible. */
export function tailXcodePath(p: string): string {
  if (!p) return ''
  const idx = p.search(/\.xcodeproj|\.xcworkspace|\.swiftpm/)
  if (idx >= 0) {
    const before = p.slice(0, idx).split('/').pop() || ''
    const after = p.slice(idx).split('/').slice(1).join('/')
    return `${before}/…/${after}` || p.split('/').slice(-2).join('/')
  }
  return p.split('/').slice(-2).join('/')
}

/** Extract target and scheme from xcodebuild/swift CLI invocations. */
export function parseXcodebuild(cmd: string): string | null {
  const m = cmd.match(/xcodebuild\s+/)
  if (!m) return null
  const scheme = cmd.match(/-scheme\s+(\S+)/)?.[1]
  const target = cmd.match(/-target\s+(\S+)/)?.[1]
  const config = cmd.match(/-configuration\s+(\S+)/)?.[1]
  const sdk = cmd.match(/-sdk\s+(\S+)/)?.[1]
  const action = cmd.match(/\b(build|test|archive|clean|analyze)\b/)?.[1]
  const parts = [action, scheme && `scheme:${scheme}`, target && `target:${target}`,
                 sdk, config].filter(Boolean)
  return `xcodebuild ${parts.join(' ')}`
}

/** Extract target/scheme from `swift` CLI invocations. */
export function parseSwiftCmd(cmd: string): string | null {
  const m = cmd.match(/^\s*swift\s+(build|test|run|package)\b/)
  if (!m) return null
  const rest = cmd.slice(cmd.indexOf(m[1]) + m[1].length).trim()
  return `swift ${m[1]}${rest ? ' ' + rest.slice(0, 60) : ''}`
}

// ─── Public API — drop-in replacements for the generic functions ────────────

export function summarizeInputSwift(
  toolName: string,
  input?: Record<string, unknown>,
): string {
  if (!input) return genericSummarizeInput(toolName, input)

  if (toolName === 'Bash') {
    const cmd = String(input.command || '')
    return parseXcodebuild(cmd) || parseSwiftCmd(cmd) || genericSummarizeInput(toolName, input)
  }

  // File tools: prefer Xcode-project-relative paths
  if (toolName === 'Read' || toolName === 'Edit' || toolName === 'Write') {
    const p = String(input.file_path || input.path || '')
    if (p.endsWith('.swift') || p.includes('.xcodeproj') || p.includes('.xcworkspace')) {
      const tail = tailXcodePath(p)
      if (toolName === 'Edit') return tail + ' — edit'
      if (toolName === 'Write') return tail + ' — write'
      return tail
    }
  }

  return genericSummarizeInput(toolName, input)
}

/**
 * Extract the first xcodebuild/swiftc diagnostic from tool output.
 * Returns a single-line summary like "3 errors: Foo.swift:42 'x' not found".
 */
export function summarizeSwiftDiagnostics(content: string): string | null {
  // xcodebuild: "Foo.swift:42:10: error: use of unresolved identifier 'bar'"
  const diag = content.match(/([^\s:/]+\.swift):(\d+):(?:\d+:)?\s*(error|warning):\s*([^\n]+)/)
  if (!diag) return null
  const errors = (content.match(/\berror:/g) || []).length
  const warns = (content.match(/\bwarning:/g) || []).length
  const parts: string[] = []
  if (errors) parts.push(`${errors} error${errors > 1 ? 's' : ''}`)
  if (warns) parts.push(`${warns} warning${warns > 1 ? 's' : ''}`)
  const msg = diag[4].slice(0, 80)
  return `${parts.join(', ')}: ${diag[1]}:${diag[2]} ${msg}`
}

export function summarizeResultSwift(content: unknown): string {
  const generic = genericSummarizeResult(content)
  if (typeof content === 'string') {
    const swift = summarizeSwiftDiagnostics(content)
    if (swift) return swift
  }
  // "** BUILD SUCCEEDED **" / "Test Suite 'All tests' passed at ..."
  if (typeof content === 'string') {
    if (/\*\*\s*BUILD SUCCEEDED\s*\*\*/.test(content)) return '** BUILD SUCCEEDED **'
    if (/\*\*\s*BUILD FAILED\s*\*\*/.test(content)) return '** BUILD FAILED **'
    const testPass = content.match(/Test Suite '([^']+)' passed at[^\n]*\n\s*Executed (\d+) test/)
    if (testPass) return `✓ ${testPass[1]}: ${testPass[2]} tests passed`
    const testFail = content.match(/Test Suite '[^']+' failed.*?Executed (\d+) tests?, with (\d+) failure/s)
    if (testFail) return `✗ ${testFail[2]}/${testFail[1]} tests failed`
  }
  return generic
}

/** Extended error detection including Swift/xcodebuild signals. */
export function detectErrorSwift(content: string): boolean {
  if (genericDetectError(content)) return true
  const lower = content.toLowerCase()
  return (
    lower.includes('** build failed **') ||
    lower.includes('xcodebuild:') && lower.includes('error') ||
    /\.swift:\d+:\d+: error:/.test(content) ||
    lower.includes('code signing error') ||
    lower.includes('linker command failed')
  )
}
