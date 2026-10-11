import Foundation
@testable import FinanceTracker

enum ReceiptFixtures {
    static func extraction() -> ReceiptExtraction {
        ReceiptExtraction(
            merchantEvidence: "Example Grocery",
            merchantName: "Example Grocery",
            items: [
                ExtractedReceiptItem(name: "Milk", lineTotal: "3.99", quantity: nil, unitPrice: nil),
                ExtractedReceiptItem(name: "Apples", lineTotal: "2.98", quantity: "0.5 lb", unitPrice: "5.96")
            ],
            subtotal: "6.97", taxAmounts: ["0.20", "0.10"], total: "7.27", warnings: []
        )
    }

    static func draft() -> ReceiptImportDraft {
        var draft = ReceiptImportDraft(extraction: extraction())
        draft.purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.items[0].category = "Groceries"
        draft.items[0].classification = "Need"
        return draft
    }
}
