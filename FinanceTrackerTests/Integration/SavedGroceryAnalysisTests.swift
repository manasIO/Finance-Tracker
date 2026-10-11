import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class SavedGroceryAnalysisTests: XCTestCase {
    func testClassifiesLegacyGroceriesAndPreservesExistingChoices() async throws {
        let container = try LocalStorage.container(inMemory: true)
        var draft = ReceiptFixtures.draft()
        draft.items[1].category = "Groceries"
        draft.items[1].foodChoice = "Treats"
        let receipt = try ReceiptImportStore.save(draft, in: container.mainContext)
        let milk = try XCTUnwrap(receipt.items.first { $0.name == "Milk" })
        milk.foodChoice = nil
        try container.mainContext.save()
        var service = SavedGroceryAnalysis()
        var calls: [String] = []
        service.analyze = { name in
            calls.append(name)
            return .init(category: .groceries, foodChoice: .healthier, classification: .need)
        }
        try await service.classify(receipt.items, in: container.mainContext)
        XCTAssertEqual(calls, ["Milk"])
        XCTAssertEqual(milk.foodChoice, "Healthier staples")
        XCTAssertEqual(receipt.items.first { $0.name == "Apples" }?.foodChoice, "Treats")
        XCTAssertEqual(milk.category, "Groceries")
    }

    func testLateResponseCannotOverrideUserChoice() async throws {
        let container = try LocalStorage.container(inMemory: true)
        let receipt = try ReceiptImportStore.save(ReceiptFixtures.draft(), in: container.mainContext)
        let milk = try XCTUnwrap(receipt.items.first { $0.name == "Milk" })
        milk.foodChoice = nil
        var service = SavedGroceryAnalysis()
        service.analyze = { _ in
            milk.foodChoice = "Unclassified"
            return .init(category: .groceries, foodChoice: .healthier, classification: .need)
        }
        try await service.classify(receipt.items, in: container.mainContext)
        XCTAssertEqual(milk.foodChoice, "Unclassified")
    }
}
