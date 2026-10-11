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
    }

    struct Tax: Identifiable, Equatable {
        let id = UUID()
        var amount = ""
    }

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

    var canSave: Bool {
        let name = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !name.isEmpty && !["unknown", "not shown"].contains(name)
            && ReceiptValidator.cents(from: total) != nil
            && (subtotal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ReceiptValidator.cents(from: subtotal) != nil)
            && (taxes.isEmpty || taxCents != nil)
            && !items.isEmpty
            && items.allSatisfy {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && ReceiptValidator.cents(from: $0.lineTotal) != nil
                    && Self.quantity(from: $0.quantity) != nil
                    && ($0.unitPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ReceiptValidator.cents(from: $0.unitPrice) != nil)
            }
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
