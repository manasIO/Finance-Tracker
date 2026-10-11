import Foundation

@available(iOS 26.0, *)
enum ReceiptValidator {
    struct Report {
        let messages: [String]
        let needsReview: Bool
    }

    static func validate(_ receipt: ReceiptExtraction) -> Report {
        var messages: [String] = []
        var needsReview = false

        func flag(_ message: String) {
            messages.append("Review: \(message)")
            needsReview = true
        }

        let merchant = receipt.merchantName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if merchant.isEmpty
            || ["unknown", "not shown"].contains(merchant.lowercased()) {
            flag("Merchant name is missing.")
        }

        // Check every item before calculating the sum.
        var itemSum: Int64 = 0
        var allItemAmountsValid = !receipt.items.isEmpty

        if receipt.items.isEmpty {
            flag("No items were extracted.")
        }

        for (index, item) in receipt.items.enumerated() {
            if item.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                flag("Item \(index + 1) has no name.")
            }

            let lineTotal = item.lineTotal?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if lineTotal.isEmpty {
                flag("Item \(index + 1) (\(item.name)) has no extracted line total. Check its price in the recognized text.")
                allItemAmountsValid = false
                continue
            }

            guard let amount = cents(from: lineTotal) else {
                flag("Item \(index + 1) (\(item.name)) returned an invalid line total: \"\(lineTotal)\". Expected decimal dollars such as 3.99.")
                allItemAmountsValid = false
                continue
            }

            let addition = itemSum.addingReportingOverflow(amount)

            if addition.overflow {
                flag("Item amounts exceed the supported range.")
                allItemAmountsValid = false
            } else {
                itemSum = addition.partialValue
            }
        }

        let subtotal = cents(from: receipt.subtotal)
        let total = cents(from: receipt.total)

        if subtotal == nil {
            flag("Subtotal is missing or invalid.")
        }

        if total == nil {
            flag("Total is missing or invalid.")
        }

        if allItemAmountsValid, let subtotal {
            if itemSum == subtotal {
                messages.append("Passed: item amounts match the subtotal.")
            } else {
                flag(
                    "Items add up to \(money(itemSum)), "
                    + "but the subtotal is \(money(subtotal))."
                )
            }
        }

        // An empty tax array means unknown, not automatically zero.
        var taxSum: Int64 = 0
        var allTaxAmountsValid = !receipt.taxAmounts.isEmpty

        if receipt.taxAmounts.isEmpty {
            flag("Tax wasn't extracted; confirm whether tax is zero.")
        }

        for taxText in receipt.taxAmounts {
            guard let amount = cents(from: taxText) else {
                flag("A tax amount is invalid.")
                allTaxAmountsValid = false
                continue
            }

            let addition = taxSum.addingReportingOverflow(amount)

            if addition.overflow {
                flag("Tax amounts exceed the supported range.")
                allTaxAmountsValid = false
            } else {
                taxSum = addition.partialValue
            }
        }

        if let subtotal, let total, allTaxAmountsValid {
            let addition = subtotal.addingReportingOverflow(taxSum)

            if addition.overflow {
                flag("Calculated total exceeds the supported range.")
            } else if addition.partialValue == total {
                messages.append("Passed: subtotal plus tax matches the total.")
            } else {
                flag(
                    "Subtotal plus tax is \(money(addition.partialValue)), "
                    + "but the total is \(money(total)). "
                    + "Check for errors, discounts, tips, or fees."
                )
            }
        }

        return Report(
            messages: messages,
            needsReview: needsReview
        )
    }

    // USD-only prototype: accept nonnegative decimal dollar strings.
    // Reject currency symbols, percentages, units, and excess decimals.
    static func cents(from input: String?) -> Int64? {
        guard let input else { return nil }

        let text = input.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard text.range(
            of: #"^[0-9]{1,9}(?:\.[0-9]{1,2})?$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }

        let parts = text.split(separator: ".")

        guard let whole = Int64(String(parts[0])) else {
            return nil
        }

        let fraction = parts.count == 2 ? String(parts[1]) : ""

        let paddedFraction = fraction.padding(
            toLength: 2,
            withPad: "0",
            startingAt: 0
        )

        guard let fractionalCents = Int64(paddedFraction) else {
            return nil
        }

        return whole * 100 + fractionalCents
    }

    private static func money(_ cents: Int64) -> String {
        (Decimal(cents) / Decimal(100))
            .formatted(.currency(code: "USD"))
    }
}
