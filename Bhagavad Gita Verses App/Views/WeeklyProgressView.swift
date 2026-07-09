import SwiftUI

/// A compact weekly-engagement strip: one dot per recent week (filled = you showed up),
/// with the current streak. Reads the App Group engagement history.
struct WeeklyProgressView: View {
    @Environment(\.colorScheme) private var colorScheme

    let weeks: [Bool]        // oldest → newest, last = current week
    let streak: Int

    /// Live variant, reading recorded engagement.
    init(weeksBack: Int = 8, now: Date = Date()) {
        let opened = WeeklyEngagement.openedAnchors()
        self.weeks = WeeklyProgress.recentEngagement(opened: opened, now: now, count: weeksBack)
        self.streak = WeeklyProgress.currentStreak(opened: opened, now: now)
    }

    /// Deterministic variant for previews/tests.
    init(weeks: [Bool], streak: Int) {
        self.weeks = weeks
        self.streak = streak
    }

    private var accent: Color { colorScheme == .light ? AppColors.vividPurple : AppColors.lavender }
    private var faint: Color { (colorScheme == .light ? AppColors.lightPeacock : AppColors.parchment).opacity(0.22) }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { idx, engaged in
                    Circle()
                        .fill(engaged ? accent : faint)
                        .frame(width: idx == weeks.count - 1 ? 9 : 7,
                               height: idx == weeks.count - 1 ? 9 : 7)
                        .overlay(
                            Circle().strokeBorder(accent.opacity(idx == weeks.count - 1 && !engaged ? 0.6 : 0), lineWidth: 1)
                        )
                }
            }
            if streak > 0 {
                Text("\(streak) week\(streak == 1 ? "" : "s")")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)
                    .accessibilityLabel("\(streak) week streak")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        WeeklyProgressView(weeks: [false, true, true, false, true, true, true, true], streak: 4)
        WeeklyProgressView(weeks: [false, false, false, false, false, false, false, false], streak: 0)
    }
    .padding()
}
