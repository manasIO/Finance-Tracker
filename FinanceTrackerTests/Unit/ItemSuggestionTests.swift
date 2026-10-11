import XCTest
@testable import FinanceTracker

@MainActor
final class ItemSuggestionTests: XCTestCase {
    func testImportedSuggestionsPopulateEditableDraft() {
        var extraction = ReceiptFixtures.extraction()
        extraction.items[0].category = .groceries
        extraction.items[0].classification = .need
        extraction.items[0].foodChoice = .healthier
        let draft = ReceiptImportDraft(extraction: extraction)
        XCTAssertEqual(draft.items[0].category, "Groceries")
        XCTAssertEqual(draft.items[0].classification, "Need")
        XCTAssertEqual(draft.items[0].foodChoice, "Healthier staples")
        XCTAssertEqual(draft.items[1].category, "Uncategorized")
        XCTAssertEqual(draft.items[1].classification, "Unclassified")
    }

    func testLateSuggestionPreservesManualChoicesIncludingUnknown() {
        var item = ManualReceiptItemDraft()
        item.name = "Chocolate"
        item.categoryEdited = true
        item.classificationEdited = true
        item.foodChoiceEdited = true
        item.apply(.init(category: .groceries, foodChoice: .treat, classification: .want), for: "Chocolate")
        XCTAssertEqual(item.category, "Uncategorized")
        XCTAssertEqual(item.classification, "Unclassified")
        XCTAssertEqual(item.foodChoice, "Unclassified")
    }

    func testRenamedItemsRejectStaleResponseAndResetAutomaticSuggestions() {
        var item = ManualReceiptItemDraft()
        item.name = "Milk"
        item.apply(.init(category: .groceries, classification: .need), for: "Milk")
        item.name = "Movie ticket"
        item.nameChanged()
        item.apply(.init(category: .groceries, classification: .need), for: "Milk")
        XCTAssertEqual(item.category, "Uncategorized")
        XCTAssertNil(item.suggestedName)
        item.apply(.init(category: .entertainment, classification: .want), for: "Movie ticket")
        XCTAssertEqual(item.category, "Entertainment")
        XCTAssertEqual(item.classification, "Want")
    }
}
