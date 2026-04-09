//
//  SourceEditorCommand.swift
//
//  Xcode Source Editor Extension: "Open in Agent Flow".
//
//  Adds a menu item under Editor → Agent Flow that sends the current file
//  path + selection line to Agent Flow's web UI via HTTP POST. The web UI
//  can then highlight the matching node in the agent graph.
//
//  Install: build the containing app target, launch it once, then enable
//  the extension under System Settings → Privacy & Security → Extensions
//  → Xcode Source Editor.
//

import Foundation
import XcodeKit

final class SourceEditorCommand: NSObject, XCSourceEditorCommand {

    func perform(with invocation: XCSourceEditorCommandInvocation,
                 completionHandler: @escaping (Error?) -> Void) {

        let buffer = invocation.buffer
        let path = buffer.usesTabsForIndentation
            ? (invocation.buffer.perform(Selector(("filePath"))) as? String) ?? ""
            : "" // Xcode doesn't expose the file path directly — see note below

        // XcodeKit does NOT expose the current file's path. Workaround:
        // send the first ~20 lines of the buffer so the receiving app can
        // fuzzy-match by content. The companion macOS app (or a small
        // helper endpoint) can resolve the path from AppleScript / UI
        // scripting if stricter matching is needed.
        let lines = buffer.lines as? [String] ?? []
        let headSample = lines.prefix(20).joined(separator: "\n")

        let selections = buffer.selections as? [XCSourceTextRange] ?? []
        let line = (selections.first?.start.line ?? 0) + 1

        let payload: [String: Any] = [
            "source": "xcode-extension",
            "path": path,
            "line": line,
            "head": headSample,
            "language": buffer.contentUTI ?? "",
        ]

        post(payload)
        completionHandler(nil)
    }

    private func post(_ payload: [String: Any]) {
        guard let url = URL(string: "http://127.0.0.1:3000/api/xcode-bridge"),
              let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 1.0
        URLSession.shared.dataTask(with: req).resume()
    }
}
