import ActivityKit
import Foundation

// Управление Live Activity по сообщениям со страницы (webkit.messageHandlers.live)
@available(iOS 16.2, *)
enum LiveWorkout {
    static func handle(_ raw: Any) {
        guard let body = raw as? [String: Any] else { return }
        let type = body["type"] as? String ?? ""

        if type == "end" {
            Task { for a in Activity<WorkoutAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) } }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let startMs = (body["start"] as? Double) ?? now.timeIntervalSince1970 * 1000
        let start = Date(timeIntervalSince1970: startMs / 1000)

        var restStart: Date? = nil
        var restEnd: Date? = nil
        if let endMs = body["restEnd"] as? Double, endMs / 1000 > now.timeIntervalSince1970 {
            let end = Date(timeIntervalSince1970: endMs / 1000)
            let total = max((body["restTotal"] as? Double) ?? end.timeIntervalSince(now), 1)
            restEnd = end
            restStart = end.addingTimeInterval(-total)
        }

        let state = WorkoutAttributes.ContentState(
            title: (body["title"] as? String) ?? "Тренировка",
            subtitle: (body["sub"] as? String) ?? "",
            restStart: restStart,
            restEnd: restEnd
        )
        // когда отдых кончится, система перерисует активность и покажет секундомер
        let content = ActivityContent(state: state, staleDate: restEnd)

        Task {
            let existing = Activity<WorkoutAttributes>.activities
            if let a = existing.first(where: { abs($0.attributes.startedAt.timeIntervalSince(start)) < 1 }) {
                await a.update(content)
                for other in existing where other.id != a.id { await other.end(nil, dismissalPolicy: .immediate) }
            } else {
                for a in existing { await a.end(nil, dismissalPolicy: .immediate) }
                _ = try? Activity.request(attributes: WorkoutAttributes(startedAt: start), content: content, pushType: nil)
            }
        }
    }
}
