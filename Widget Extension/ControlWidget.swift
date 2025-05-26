import AppIntents
import SwiftUI
import WidgetKit

struct quoteOfDayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "Sne.LockScreenWidgetSample.example"
        ) {
            ControlWidgetButton(action: OpenVerseOfDayIntent()) {
                Label("Label", systemImage: "text.book.closed")
            }
        }
        .displayName("Display name")
        .description("Description")
         // TODO fix ^
    }
}
