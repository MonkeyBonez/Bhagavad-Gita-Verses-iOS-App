import WidgetKit
import SwiftUI

@main
struct exampleBundle: WidgetBundle {
    var body: some Widget {
        HomescreenVerseWidget()
        HomescreenQuoteWidget()
        LockscreenQuoteWidget()
        LockscreenEasyViewQuoteWidget()
        QuoteOfDayControl()
    }
}
