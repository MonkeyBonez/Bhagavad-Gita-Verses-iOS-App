import WidgetKit
import SwiftUI

@main
struct exampleBundle: WidgetBundle {
    var body: some Widget {
        HomescreenLessonWidget()
        HomescreenVerseWidget()
        LockscreenQuoteWidget()
        QuoteOfDayControl()
    }
}
