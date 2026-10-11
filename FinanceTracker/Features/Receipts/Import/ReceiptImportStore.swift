import Foundation
import SwiftData

@available(iOS 26.0, *)
@MainActor
enum ReceiptImportStore {
    static func save(_ draft: ReceiptImportDraft, confirmedReview: Bool, in context: ModelContext) throws -> Receipt {
        guard draft.canSave, let total = ReceiptValidator.cents(from: draft.total) else {
            throw SaveError.invalidFields
        }
        guard !(draft.report.needsReview || !draft.extractionWarnings.isEmpty) || confirmedReview else {
            throw SaveError.reviewRequired
        }

        let receipt = Receipt(
            merchantName: draft.merchantName.trimmingCharacters(in: .whitespacesAndNewlines),
            purchaseDate: draft.purchaseDate,
            totalCents: total
        )
        receipt.subtotalCents = ReceiptValidator.cents(from: draft.subtotal)
        receipt.taxCents = draft.taxCents

        // Build the complete graph before inserting anything into SwiftData.
        for item in draft.items {
            guard let lineTotal = ReceiptValidator.cents(from: item.lineTotal),
                  let quantity = ReceiptImportDraft.quantity(from: item.quantity) else {
                throw SaveError.invalidFields
            }
            let savedItem = ReceiptItem(
                name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                unitPriceCents: ReceiptValidator.cents(from: item.unitPrice),
                lineTotalCents: lineTotal,
                category: item.category,
                isLuxury: item.classification == "Unclassified" ? nil : item.classification == "Want"
            )
            let unit = item.quantityUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            savedItem.quantityUnit = unit.isEmpty ? nil : unit
            receipt.items.append(savedItem)
        }

        context.insert(receipt)
        do {
            try context.save()
            return receipt
        } catch {
            context.rollback()
            throw error
        }
    }

    enum SaveError: LocalizedError {
        case invalidFields, reviewRequired
        var errorDescription: String? {
            switch self {
            case .invalidFields: "Correct the required receipt fields before saving."
            case .reviewRequired: "Review the flagged fields before saving."
            }
        }
    }
}
