import Foundation

struct SpendingSummary {
    struct Entry {
        let date: Date
        let totalCents: Int64
        let currencyCode: String
        var isReceipt = true
    }

    struct Month: Identifiable {
        let start: Date
        let totalCents: Decimal
        let receiptCount: Int
        var id: Date { start }
        var total: Decimal { totalCents / 100 }
    }

    let months: [Month]
    let currentMonth: Month
    let previousMonth: Month
    let previousMonthToDateCents: Decimal
    let previousMonthToDateCount: Int
    let firstRecordedMonth: Date?

    var changeCents: Decimal { currentMonth.totalCents - previousMonthToDateCents }
    var changeRatio: Decimal? {
        guard previousMonthToDateCents != 0 else { return nil }
        return changeCents / abs(previousMonthToDateCents)
    }
    var history: [Month] {
        guard let firstRecordedMonth else { return [] }
        return months.filter { $0.start >= firstRecordedMonth }.reversed()
    }

    init(entries: [Entry], now: Date = .now, calendar: Calendar = .current, currencyCode: String = "USD") {
        let currentStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        let previousStart = calendar.date(byAdding: .month, value: -1, to: currentStart) ?? currentStart
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let elapsedDays = (calendar.dateComponents([.day], from: currentStart, to: today).day ?? 0) + 1
        // Compare equal elapsed calendar days; clamp when the previous month is shorter.
        let previousCutoff = min(calendar.date(byAdding: .day, value: elapsedDays, to: previousStart) ?? currentStart, currentStart)
        let included = entries.filter { $0.currencyCode == currencyCode && $0.date < tomorrow }
        var totals: [Date: Decimal] = [:]
        var counts: [Date: Int] = [:]
        var previousToDate: Decimal = 0
        var previousCount = 0
        for entry in included {
            let start = calendar.dateInterval(of: .month, for: entry.date)?.start ?? calendar.startOfDay(for: entry.date)
            // Decimal cents avoid overflow when aggregating many integer-cent receipts.
            totals[start, default: 0] += Decimal(entry.totalCents)
            if entry.isReceipt { counts[start, default: 0] += 1 }
            if entry.date >= previousStart && entry.date < previousCutoff {
                previousToDate += Decimal(entry.totalCents)
                previousCount += 1
            }
        }
        firstRecordedMonth = totals.keys.min()
        let recentStart = calendar.date(byAdding: .month, value: -11, to: currentStart) ?? currentStart
        var start = min(firstRecordedMonth ?? recentStart, recentStart)
        var result: [Month] = []
        while start <= currentStart {
            result.append(Month(start: start, totalCents: totals[start, default: 0], receiptCount: counts[start, default: 0]))
            guard let next = calendar.date(byAdding: .month, value: 1, to: start), next > start else { break }
            start = next
        }
        months = result
        currentMonth = Month(start: currentStart, totalCents: totals[currentStart, default: 0], receiptCount: counts[currentStart, default: 0])
        previousMonth = Month(start: previousStart, totalCents: totals[previousStart, default: 0], receiptCount: counts[previousStart, default: 0])
        previousMonthToDateCents = previousToDate
        previousMonthToDateCount = previousCount
    }
}
