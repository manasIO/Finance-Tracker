import SwiftUI
import SwiftData

@main struct FinanceTrackerApp: App {
    private let container: ModelContainer?

    init() {
        container = try? LocalStorage.container(
            inMemory: ProcessInfo.processInfo.environment["FINANCE_TRACKER_TESTING"] == "1"
        )
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                AppRootView().modelContainer(container)
            } else {
                ContentUnavailableView("Couldn't open local storage", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("Restart the app and try again. Your saved data has not been reset."))
            }
        }
    }
}
