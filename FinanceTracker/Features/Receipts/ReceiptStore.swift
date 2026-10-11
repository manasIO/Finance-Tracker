import Foundation
import SwiftData

@MainActor
enum ReceiptStore {
    // Matching store, calendar day, currency and total is a possible duplicate,
    // not proof: customers may make two identical purchases in one day.
    static func duplicate(of receipt: Receipt, among saved: [Receipt], calendar: Calendar = .current) -> Receipt? {
        saved.first {
            $0.id != receipt.id && normalized($0.merchantName) == normalized(receipt.merchantName)
                && calendar.isDate($0.purchaseDate, inSameDayAs: receipt.purchaseDate)
                && $0.currencyCode.uppercased() == receipt.currencyCode.uppercased()
                && $0.totalCents == receipt.totalCents
        }
    }

    static func save(_ receipt: Receipt, in context: ModelContext, allowDuplicate: Bool = false) throws {
        if !allowDuplicate,
           let existing = duplicate(of: receipt, among: try context.fetch(FetchDescriptor<Receipt>())) {
            throw SaveError.possibleDuplicate(existing.merchantName)
        }
        context.insert(receipt)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined()
    }

    enum SaveError: LocalizedError {
        case possibleDuplicate(String)
        var errorDescription: String? {
            switch self {
            case .possibleDuplicate(let store):
                "A receipt from \(store) with this date and total is already saved."
            }
        }
    }
}
