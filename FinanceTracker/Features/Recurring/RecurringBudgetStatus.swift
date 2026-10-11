import Foundation

struct RecurringBudgetStatus {
    let limit: Decimal
    let spent: Decimal
    let reserved: Decimal
    var committed: Decimal { spent + reserved }
    var remaining: Decimal { limit - committed }

    init(limitCents: Int64, spent: Decimal, recurring: [RecurringSchedule.Occurrence]) {
        limit = Decimal(limitCents) / 100
        self.spent = spent
        reserved = recurring.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
}
