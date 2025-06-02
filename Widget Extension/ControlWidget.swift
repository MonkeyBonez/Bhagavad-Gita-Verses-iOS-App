import AppIntents
import SwiftUI
import WidgetKit

struct QuoteOfDayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "Sne.LockScreenWidgetSample.example"
        ) {
            ControlWidgetButton(action: OpenVerseOfDayIntent()) {
                Label("Verse of Week", systemImage: "text.book.closed")
            }
        }
        .displayName("Verse of Week")
        .description("Opens to the Bhagavad Gita verse of week")
    }
}
