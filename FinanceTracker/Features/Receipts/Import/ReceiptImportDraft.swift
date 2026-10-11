import Foundation

@available(iOS 26.0, *)
struct ReceiptImportDraft: Equatable {
    struct Item: Identifiable, Equatable {
        let id = UUID()
        var name = ""
        var quantity = "1"
        var quantityUnit = ""
        var unitPrice = ""
        var lineTotal = ""
        var category = "Uncategorized"
        var classification = "Unclassified"
        var foodChoice = FoodChoice.unclassified.rawValue
    }

    struct Tax: Identifiable, Equatable {
        let id = UUID()
        var amount = ""
    }

    var needsSplit = false
    var merchantName: String
    var purchaseDate = Date()
    var subtotal: String
    var total: String
    var taxes: [Tax]
    var items: [Item]
    let merchantEvidence: String?
    let extractionWarnings: [String]

    init(extraction: ReceiptExtraction) {
        merchantName = extraction.merchantName ?? ""
        subtotal = extraction.subtotal ?? ""
        total = extraction.total ?? ""
        taxes = extraction.taxAmounts.map { Tax(amount: $0) }
        merchantEvidence = extraction.merchantEvidence
        extractionWarnings = extraction.warnings
        items = extraction.items.map { extracted in
            var item = Item()
            item.name = extracted.name
            item.foodChoice = extracted.foodChoice?.rawValue ?? FoodChoice.unclassified.rawValue
            item.category = extracted.category?.rawValue ?? "Uncategorized"
            item.classification = extracted.classification?.rawValue ?? "Unclassified"
            item.unitPrice = extracted.unitPrice ?? ""
            item.lineTotal = extracted.lineTotal ?? ""
            if let quantity = extracted.quantity, !quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Separate a printed numeric quantity from its unit without
                // interpreting package sizes or calculating missing amounts.
                let text = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
                if let range = text.range(of: #"^[0-9]+(?:\.[0-9]+)?"#, options: .regularExpression) {
                    item.quantity = String(text[range])
                    item.quantityUnit = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    item.quantity = text
                }
            }
            return item
        }
    }

    var extraction: ReceiptExtraction {
        ReceiptExtraction(
            merchantEvidence: merchantEvidence,
            merchantName: merchantName,
            items: items.map {
                ExtractedReceiptItem(name: $0.name, lineTotal: $0.lineTotal,
                    quantity: $0.quantity, unitPrice: $0.unitPrice.isEmpty ? nil : $0.unitPrice)
            },
            subtotal: subtotal.isEmpty ? nil : subtotal,
            taxAmounts: taxes.map(\.amount),
            total: total.isEmpty ? nil : total,
            warnings: extractionWarnings
        )
    }

    var report: ReceiptValidator.Report { ReceiptValidator.validate(extraction) }

    var canSave: Bool { validationMessage == nil }

    // Save remains available; report an actionable error only when it is tapped.
    var validationMessage: String? {
        let name = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty && !["unknown", "not shown"].contains(name) else {
            return "Enter the store name."
        }
        guard ReceiptValidator.cents(from: total) != nil else {
            return "Enter a valid total paid, such as 12.50."
        }
        for (index, item) in items.enumerated() {
            let number = index + 1
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "Enter a name for item \(number), or remove it."
            }
            guard ReceiptValidator.cents(from: item.lineTotal) != nil else {
                return "Enter a valid line total for item \(number), such as 3.99."
            }
            guard Self.quantity(from: item.quantity) != nil else {
                return "Enter a positive quantity for item \(number)."
            }
            guard item.unitPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || ReceiptValidator.cents(from: item.unitPrice) != nil else {
                return "Correct or clear the optional unit price for item \(number)."
            }
        }
        return nil
    }

    // Unknown tax is valid to store as nil. Invalid entered tax is not.
    var taxCents: Int64? {
        guard !taxes.isEmpty else { return nil }
        var sum: Int64 = 0
        for tax in taxes {
            guard let amount = ReceiptValidator.cents(from: tax.amount) else { return nil }
            let result = sum.addingReportingOverflow(amount)
            guard !result.overflow else { return nil }
            sum = result.partialValue
        }
        return sum
    }

    static func quantity(from input: String) -> Decimal? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]{1,9}(?:\.[0-9]{1,6})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
        return value
    }
}
