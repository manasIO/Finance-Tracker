import Foundation
import SwiftData

@MainActor
enum LocalStorage {
    static func configuration(inMemory: Bool = false) throws -> ModelConfiguration {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        if !inMemory {
            // Keep the existing store location; exclude the app's storage directory
            // from backups so local-only data does not enter cloud device backups.
            try excludeFromBackup(configuration.url.deletingLastPathComponent())
        }
        return configuration
    }

    static func excludeFromBackup(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    static func container(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(for: Receipt.self, ReceiptItem.self, MonthlyBudget.self, UserProfile.self, RecurringExpense.self, RecurringPayment.self,
                           configurations: configuration(inMemory: inMemory))
    }
}
