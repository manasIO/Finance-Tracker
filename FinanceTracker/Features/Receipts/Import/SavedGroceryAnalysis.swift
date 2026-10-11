import Foundation
import SwiftData

@MainActor
struct SavedGroceryAnalysis {
    var analyze: (String) async throws -> ItemAnalysis = { try await ItemAnalysisService().analyze(name: $0) }

    func classify(_ items: [ReceiptItem], in context: ModelContext) async throws {
        for item in items where item.category == "Groceries" && item.foodChoice == nil {
            let name = item.name
            let result = try await analyze(name)
            try Task.checkCancellation()
            guard item.modelContext != nil, item.name == name,
                  item.category == "Groceries", item.foodChoice == nil else { continue }
            item.foodChoice = result.foodChoice.rawValue
            do { try context.save() } catch { context.rollback(); throw error }
        }
    }
}
