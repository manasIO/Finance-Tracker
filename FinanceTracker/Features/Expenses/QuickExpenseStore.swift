import Foundation
import SwiftData

@MainActor
enum QuickExpenseStore {
    static func save(amount: String, description: String = "", category: String = "Uncategorized",
                     currency: String = "USD", date: Date = .now, needsSplit: Bool = false,
                     allowDuplicate: Bool = false, in context: ModelContext) throws -> Receipt {
        guard let cents = ReceiptValidator.cents(from: amount), cents > 0,
              ItemCategory(rawValue: category) != nil else { throw SaveError.invalidFields }
        let name = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Receipt(merchantName: name.isEmpty ? "Quick expense" : name,
                              purchaseDate: date, currencyCode: currency, totalCents: cents)
        expense.entryKind = "quickExpense"
        expense.needsSplit = needsSplit
        // One aggregate amount keeps category totals consistent without asking for items.
        let item = ReceiptItem(name: "Expense", lineTotalCents: cents, category: category)
        item.foodChoice = FoodChoice.unclassified.rawValue
        expense.items = [item]
        // Amount and date alone cannot reliably identify a duplicate purchase.
        try ReceiptStore.save(expense, in: context, allowDuplicate: allowDuplicate || name.isEmpty)
        return expense
    }

    enum SaveError: LocalizedError {
        case invalidFields
        var errorDescription: String? { "Enter a positive amount, such as 12.00, and choose a category." }
    }
}
