# Agent Flow — Xcode Source Editor Extension

Adds an **Editor → Agent Flow → Open in Agent Flow** menu item to Xcode.
Clicking it POSTs the current file's head + selection line to the Agent
Flow web app so the graph can navigate to the matching node.

## Build

1. In Xcode: File → New → Project → macOS → App (this is the host app —
   Source Editor Extensions must ship inside a host app)
2. File → New → Target → Xcode Source Editor Extension
3. Replace the generated `SourceEditorCommand.swift` with the one here
4. In the extension target's `Info.plist`, under
   `NSExtension > NSExtensionAttributes > XCSourceEditorCommandDefinitions`,
   set a user-facing name like `Open in Agent Flow`
5. Build + run the host app once, then enable under
   **System Settings → Privacy & Security → Extensions → Xcode Source Editor**

## Receiver endpoint

The extension POSTs to `http://127.0.0.1:3000/api/xcode-bridge`. Add this
Next.js route handler to the web app:

```ts
// web/app/api/xcode-bridge/route.ts
export async function POST(req: Request) {
  const payload = await req.json()
  // Broadcast to connected browser clients via your existing SSE bridge
  console.log('[xcode-bridge]', payload)
  return Response.json({ ok: true })
}
```

## Limitation

`XcodeKit` does not expose the file path of the current buffer. This
scaffold sends a sample of the buffer so the receiver can fuzzy-match by
content. If you need strict path matching, pair the extension with the
companion app and use AppleScript UI scripting against Xcode to read the
front window's document path.
