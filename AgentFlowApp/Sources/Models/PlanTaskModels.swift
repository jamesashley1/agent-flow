import Foundation

// MARK: - Plan State

struct PlanState {
    var content: String
    var isActive: Bool = true
    var updatedAt: Double = 0
}

// MARK: - Task Item

struct TaskItem: Identifiable {
    let id: String
    var subject: String
    var description: String
    var status: TaskStatus
    var createdAt: Double
    var updatedAt: Double

    enum TaskStatus: String {
        case pending
        case inProgress = "in_progress"
        case completed
        case blocked
        case cancelled

        var icon: String {
            switch self {
            case .pending:    return "circle"
            case .inProgress: return "arrow.trianglehead.clockwise.rotate.90"
            case .completed:  return "checkmark.circle.fill"
            case .blocked:    return "xmark.circle"
            case .cancelled:  return "minus.circle"
            }
        }

        var isActive: Bool {
            self == .pending || self == .inProgress
        }
    }
}
