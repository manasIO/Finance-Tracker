import Foundation

enum ReceiptRedactor {
    static func prepare(_ text: String) -> String {
        var keptLines: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !line.isEmpty else { continue }

            // Your sample has a separate card-terminal receipt.
            if line.lowercased() == "transaction receipt" {
                break
            }

            // Remove standalone labeled payment/transaction metadata.
            if matches(
                #"(?i)^(reference\s*#?|trans(?:action)?\s*:|terminal\s*:|clerk\s*id|auth\s*code|invoice\s*:|credit\s*card\b|lane\s*\d+\b)"#,
                in: line
            ) {
                continue
            }

            // Remove standalone US phone numbers.
            if matches(
                #"^(?:\+1[\s.-]?)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}$"#,
                in: line
            ) {
                continue
            }

            // Conservative street-address pattern.
            if matches(
                #"(?i)^\d+\s+.+\s(?:street|st|road|rd|avenue|ave|pike|drive|dr|boulevard|blvd)\.?$"#,
                in: line
            ) {
                continue
            }

            keptLines.append(line)
        }

        return keptLines.joined(separator: "\n")
    }

    private static func matches(
        _ pattern: String,
        in text: String
    ) -> Bool {
        text.range(
            of: pattern,
            options: .regularExpression
        ) != nil
    }
}
