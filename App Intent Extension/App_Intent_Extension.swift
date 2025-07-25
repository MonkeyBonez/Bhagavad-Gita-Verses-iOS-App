//
//  App_Intent_Extension.swift
//  App Intent Extension
//
//  Created by Snehal Mulchandani on 2/2/25.
//

import AppIntents
import UIKit
import SwiftUI

struct OpenVerseOfDayIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Verse Of Day" }
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        EnvironmentValues().openURL(DeeplinkScheme.createDeeplink(path: .verseOfDayIntent))
        return .result()
    }
}
