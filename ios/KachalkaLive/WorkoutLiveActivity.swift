import ActivityKit
import SwiftUI
import WidgetKit

private let lime = Color(red: 0.776, green: 1.0, blue: 0.369)
private let bg = Color(red: 0.055, green: 0.059, blue: 0.067)

private func restRange(_ s: WorkoutAttributes.ContentState, stale: Bool) -> ClosedRange<Date>? {
    guard !stale, let a = s.restStart, let b = s.restEnd, b > Date(), a < b else { return nil }
    return a...b
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(bg)
                .activitySystemActionForegroundColor(lime)
        } dynamicIsland: { context in
            let rest = restRange(context.state, stale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rest != nil ? "Отдых" : "Тренировка")
                            .font(.caption).foregroundStyle(.secondary)
                        Image(systemName: rest != nil ? "timer" : "figure.strengthtraining.traditional")
                            .font(.title2).foregroundStyle(lime)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if let r = rest {
                            Text(timerInterval: r, countsDown: true)
                        } else {
                            Text(context.attributes.startedAt, style: .timer)
                        }
                    }
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rest != nil ? lime : .white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140, alignment: .trailing)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.subtitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                        if let r = rest {
                            ProgressView(timerInterval: r, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                                .tint(lime)
                        } else {
                            HStack(spacing: 4) {
                                Text("Идёт").foregroundStyle(.secondary)
                                Text(context.attributes.startedAt, style: .timer).monospacedDigit()
                                Text("· " + context.state.title).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: rest != nil ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundStyle(lime)
            } compactTrailing: {
                Group {
                    if let r = rest {
                        Text(timerInterval: r, countsDown: true)
                    } else {
                        Text(context.attributes.startedAt, style: .timer)
                    }
                }
                .monospacedDigit()
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(rest != nil ? lime : .white)
                .multilineTextAlignment(.trailing)
                .frame(width: rest != nil ? 40 : 52)
            } minimal: {
                Image(systemName: rest != nil ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundStyle(lime)
            }
            .keylineTint(lime)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutAttributes>

    var body: some View {
        let rest = restRange(context.state, stale: context.isStale)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rest != nil ? "Отдых" : context.state.title)
                        .font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text(context.state.subtitle)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
                Spacer()
                Group {
                    if let r = rest {
                        Text(timerInterval: r, countsDown: true)
                    } else {
                        Text(context.attributes.startedAt, style: .timer)
                    }
                }
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rest != nil ? lime : .white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 130, alignment: .trailing)
            }
            if let r = rest {
                ProgressView(timerInterval: r, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(lime)
            } else {
                HStack(spacing: 4) {
                    Text("Тренировка идёт")
                    Text(context.attributes.startedAt, style: .timer).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
    }
}
