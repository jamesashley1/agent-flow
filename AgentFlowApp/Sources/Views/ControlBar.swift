import SwiftUI

// MARK: - Control Bar

struct ControlBar: View {
    @Bindable var state: SimulationState
    var engine: SimulationEngine
    @Binding var showPlanTaskPanel: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Play/Pause
            Button(action: {
                state.isPlaying.toggle()
            }) {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(state.theme.uiAccent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            // Speed selector
            HStack(spacing: 4) {
                ForEach(PlaybackSpeed.allCases, id: \.rawValue) { speed in
                    Button(action: {
                        state.playbackSpeed = speed.rawValue
                    }) {
                        Text(speed.label)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(
                                state.playbackSpeed == speed.rawValue
                                    ? state.theme.uiAccent
                                    : Color.white.opacity(0.4)
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(state.playbackSpeed == speed.rawValue
                                        ? state.theme.uiAccent.opacity(0.15)
                                        : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Time display
            Text(formatTime(state.time))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            // Detail slider
            HStack(spacing: 6) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))

                Slider(value: $state.detailLevel, in: 0...1, step: 0.05)
                    .frame(width: 100)
                    .tint(state.theme.uiAccent)

                Image(systemName: "eye")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))

                Text(detailName)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(state.theme.uiAccent.opacity(0.7))
                    .frame(width: 52, alignment: .leading)
            }

            // Theme picker
            HStack(spacing: 2) {
                ForEach(Theme.allThemes, id: \.name) { theme in
                    Button(action: { state.theme = theme }) {
                        Image(systemName: theme.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(
                                state.theme.name == theme.name
                                    ? theme.uiAccent
                                    : .white.opacity(0.3)
                            )
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(state.theme.name == theme.name
                                        ? theme.uiAccent.opacity(0.15)
                                        : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(theme.name)
                }
            }
            .padding(.horizontal, 4)

            // Toggle buttons
            toggleButton(icon: "square.grid.3x3", label: "Grid", isOn: $state.showGrid)
            toggleButton(icon: "chart.bar", label: "Stats", isOn: $state.showStats)
            toggleButton(icon: "dollarsign.circle", label: "Cost", isOn: $state.showCost)
            toggleButton(icon: "list.bullet.clipboard", label: "Plan", isOn: $showPlanTaskPanel)

            // Zoom to fit
            Button(action: {
                engine.zoomToFit(viewSize: .init(width: 800, height: 600))
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(state.theme.uiBackground.opacity(0.9))
                .overlay(
                    Rectangle()
                        .fill(state.theme.uiAccent.opacity(0.08))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    private func toggleButton(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundStyle(
                isOn.wrappedValue
                    ? state.theme.uiAccent
                    : Color.white.opacity(0.4)
            )
            .frame(width: 40, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isOn.wrappedValue
                        ? state.theme.uiAccent.opacity(0.1)
                        : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var detailName: String {
        switch state.detailLevel {
        case ..<0.2: return "Minimal"
        case ..<0.3: return "Low"
        case ..<0.5: return "Med-Low"
        case ..<0.6: return "Medium"
        case ..<0.8: return "High"
        default:     return "Full"
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let ms = Int(time * 10) % 10
        return String(format: "%d:%02d.%d", minutes, seconds, ms)
    }
}
