import Foundation

struct CategorySummary {
    struct Entry {
        var date: Date
        var currency: String
        var totalCents: Int64
        var items: [Item]
    }
    struct Item {
        var category: String
        var isLuxury: Bool?
        var cents: Int64
        var foodChoice: String? = nil
    }
    struct Row: Identifiable {
        var name: String
        var total: Decimal
        var id: String { name }
    }
    let categories: [Row]
    let needs: Decimal
    let wants: Decimal
    let unclassified: Decimal
    let adjustment: Decimal

    init(entries: [Entry], now: Date = .now, currency: String, calendar: Calendar = .current) {
        let month = calendar.dateInterval(of: .month, for: now)!
        let dayEnd = calendar.dateInterval(of: .day, for: now)!.end
        var totals: [String: Decimal] = [:]
        var needs: Decimal = 0, wants: Decimal = 0, unknown: Decimal = 0, adjustment: Decimal = 0
        for entry in entries where entry.currency == currency && month.contains(entry.date) && entry.date < dayEnd {
            var itemTotal: Decimal = 0
            for item in entry.items {
                let value = Decimal(item.cents) / 100
                let name = ItemCategory(rawValue: item.category)?.rawValue ?? "Uncategorized"
                totals[name, default: 0] += value
                itemTotal += value
                switch item.isLuxury {
                case false: needs += value
                case true: wants += value
                case nil: unknown += value
                }
            }
            // Keep missing items, tax and discounts visible without inventing categories.
            adjustment += Decimal(entry.totalCents) / 100 - itemTotal
        }
        categories = totals.map { Row(name: $0.key, total: $0.value) }
            .sorted { $0.total == $1.total ? $0.name < $1.name : $0.total > $1.total }
        self.needs = needs
        self.wants = wants
        self.unclassified = unknown
        self.adjustment = adjustment
    }
}
