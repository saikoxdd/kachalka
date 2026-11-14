import ActivityKit
import Foundation

// Общий файл: входит и в приложение, и в расширение Live Activity.
struct WorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String       // "Ноги + плечи · тяжёлая"
        var subtitle: String    // "Присед · 3/4 · 130×6"
        var restStart: Date?    // идёт отдых: начало
        var restEnd: Date?      // идёт отдых: конец
    }
    var startedAt: Date         // начало тренировки - для секундомера
}
