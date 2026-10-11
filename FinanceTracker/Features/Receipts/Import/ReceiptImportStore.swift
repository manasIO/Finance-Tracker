import Foundation
import SwiftData

@available(iOS 26.0, *)
@MainActor
enum ReceiptImportStore {
    static func save(_ draft: ReceiptImportDraft, in context: ModelContext, allowDuplicate: Bool = false) throws -> Receipt {
        if let message = draft.validationMessage {
            throw SaveError.invalidFields(message)
        }
        guard let total = ReceiptValidator.cents(from: draft.total) else {
            throw SaveError.invalidFields("Enter a valid total paid.")
        }

        let receipt = Receipt(
            merchantName: draft.merchantName.trimmingCharacters(in: .whitespacesAndNewlines),
            purchaseDate: draft.purchaseDate,
            totalCents: total
        )
        receipt.needsSplit = draft.needsSplit
        receipt.subtotalCents = ReceiptValidator.cents(from: draft.subtotal)
        receipt.taxCents = draft.taxCents

        // Build the complete graph before inserting anything into SwiftData.
        for item in draft.items {
            guard let lineTotal = ReceiptValidator.cents(from: item.lineTotal),
                  let quantity = ReceiptImportDraft.quantity(from: item.quantity) else {
                throw SaveError.invalidFields("Correct the item's line total and quantity.")
            }
            let savedItem = ReceiptItem(
                name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                unitPriceCents: ReceiptValidator.cents(from: item.unitPrice),
                lineTotalCents: lineTotal,
                category: item.category,
                isLuxury: item.classification == "Unclassified" ? nil : item.classification == "Want"
            )
            savedItem.foodChoice = item.foodChoice
            let unit = item.quantityUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            savedItem.quantityUnit = unit.isEmpty ? nil : unit
            receipt.items.append(savedItem)
        }

        try ReceiptStore.save(receipt, in: context, allowDuplicate: allowDuplicate)
        return receipt
    }

    enum SaveError: LocalizedError {
        case invalidFields(String)
        var errorDescription: String? {
            switch self {
            case .invalidFields(let message): message
            }
        }
    }
}
