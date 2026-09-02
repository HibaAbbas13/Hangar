import WidgetKit
import SwiftUI
import AppIntents

@main
struct HangarWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeckControlWidget()
        LockScreenWidget()
        WebhookLiveActivity()
    }
}
