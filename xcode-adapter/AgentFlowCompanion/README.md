# Agent Flow Companion (macOS menu-bar app)

Small SwiftUI menu-bar app that launches the Agent Flow dev server so you
don't have to manage a Node process in Terminal.

## Build

1. Open Xcode → File → New → Project → macOS → App
2. Product name: `AgentFlowCompanion`, Interface: SwiftUI, Language: Swift
3. Replace the generated `AgentFlowCompanionApp.swift` with the one in this folder
4. Under Info.plist, set **Application is agent (UIElement)** = YES so it
   runs as a menu-bar-only app with no dock icon
5. Build and run

## Use

1. Click the menu-bar icon, pick your `agent-flow` repo directory
2. Click **Start** — the app runs `pnpm run dev` for you
3. Click **Open** to launch the visualizer in your browser
4. Recent log output streams in the popover

## Notes

- Uses a login zsh shell (`/bin/zsh -l -c`) so `node`/`pnpm` from nvm / homebrew
  resolve correctly.
- Process is terminated on app quit. No state is persisted other than the
  repo path (UserDefaults via `@AppStorage`).
