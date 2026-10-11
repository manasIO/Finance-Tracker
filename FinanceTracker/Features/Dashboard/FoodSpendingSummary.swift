import Foundation

struct FoodSpendingSummary {
    struct Slice: Identifiable {
        let choice: FoodChoice
        let amount: Decimal
        let share: Decimal
        var id: String { choice.rawValue }
    }
    let total: Decimal
    let slices: [Slice]

    init(entries: [CategorySummary.Entry], now: Date, currency: String, calendar: Calendar = .current) {
        let month = calendar.dateInterval(of: .month, for: now)!
        let dayEnd = calendar.dateInterval(of: .day, for: now)!.end
        var amounts: [FoodChoice: Decimal] = [:]
        for entry in entries where entry.currency == currency && month.contains(entry.date) && entry.date < dayEnd {
            for item in entry.items where item.category == "Groceries" && item.cents > 0 {
                let choice = FoodChoice(rawValue: item.foodChoice ?? "") ?? .unclassified
                amounts[choice, default: 0] += Decimal(item.cents) / 100
            }
        }
        let total = amounts.values.reduce(Decimal(0), +)
        self.total = total
        slices = FoodChoice.allCases.map {
            let amount = amounts[$0, default: 0]
            return Slice(choice: $0, amount: amount, share: total > 0 ? amount / total : 0)
        }
    }
}
