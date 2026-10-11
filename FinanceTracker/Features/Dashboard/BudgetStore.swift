import Foundation
import SwiftData

@MainActor
enum BudgetStore {
    static func save(amount: String, month: Date, currency: String, in context: ModelContext) throws {
        guard let cents = ReceiptValidator.cents(from: amount), cents > 0 else {
            throw BudgetError.invalidAmount
        }
        let start = Calendar.current.dateInterval(of: .month, for: month)!.start
        let budgets = try context.fetch(FetchDescriptor<MonthlyBudget>())
        let budget = budgets.first { $0.month == start && $0.currencyCode == currency }
            ?? MonthlyBudget(month: start, currencyCode: currency, amountCents: cents)
        if budget.modelContext == nil { context.insert(budget) }
        budget.amountCents = cents
        do { try context.save() } catch { context.rollback(); throw error }
    }

    enum BudgetError: LocalizedError {
        case invalidAmount
        var errorDescription: String? { "Enter a positive budget, such as 500.00." }
    }
}
