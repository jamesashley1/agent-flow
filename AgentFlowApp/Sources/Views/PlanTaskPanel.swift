import SwiftUI

// MARK: - Plan & Task Panel

/// Right-side slide-in panel showing the active plan and task list.
struct PlanTaskPanel: View {
    let plan: PlanState?
    let tasks: [TaskItem]
    let theme: Theme
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.uiAccent)

                Text("Plan & Tasks")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.white.opacity(0.1))

            // Plan section
            if let plan {
                HStack(spacing: 6) {
                    Circle()
                        .fill(plan.isActive ? theme.secondary : theme.success)
                        .frame(width: 6, height: 6)
                    Text(plan.isActive ? "Plan (active)" : "Plan (complete)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }

                ScrollView {
                    Text(plan.content)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 250)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.bubbleAssistant.opacity(0.8))
                )

                Divider().overlay(Color.white.opacity(0.1))
            } else {
                Text("No active plan")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }

            // Tasks section
            HStack {
                Text("Tasks (\(tasks.count))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                if !tasks.isEmpty {
                    let done = tasks.filter { $0.status == .completed }.count
                    Text("\(done)/\(tasks.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.success.opacity(0.6))
                }
            }

            if tasks.isEmpty {
                Text("No tasks")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(tasks) { task in
                            taskRow(task)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.agentFillTop.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.uiBorder.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.status.icon)
                .font(.system(size: 11))
                .foregroundStyle(taskColor(task.status))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.subject)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(task.status.isActive ? 0.9 : 0.5))
                    .lineLimit(2)

                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(task.status == .inProgress ? theme.uiAccent.opacity(0.06) : Color.white.opacity(0.02))
        )
    }

    private func taskColor(_ status: TaskItem.TaskStatus) -> Color {
        switch status {
        case .pending:    return .white.opacity(0.4)
        case .inProgress: return theme.secondary
        case .completed:  return theme.success
        case .blocked:    return theme.error
        case .cancelled:  return .white.opacity(0.25)
        }
    }
}
