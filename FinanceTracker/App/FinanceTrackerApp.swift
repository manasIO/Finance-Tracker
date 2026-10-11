import SwiftUI
import SwiftData

@main struct FinanceTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ReceiptListView()
        }
        .modelContainer(for: [
            Receipt.self,
            ReceiptItem.self
        ])
    }
}
