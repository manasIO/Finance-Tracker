import SwiftUI

@available(iOS 26.0, *)
struct ReceiptAIReviewView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preparedText: String
    @State private var extraction: ReceiptExtraction?
    @State private var merchantName = ""
    @State private var isParsing = false
    @State private var errorMessage: String?

    private let aiService = ReceiptAIService()

    init(ocrText: String) {
        _preparedText = State(initialValue: ocrText)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $preparedText)
                        .frame(minHeight: 220)
                        .font(.system(.body, design: .monospaced))
                        .disabled(isParsing)
                } header: {
                    Text("Text for on-device AI")
                } footer: {
                    Text(
                        "Review the recognized text before extraction. "
                            + "Processing happens on your device."
                    )
                }

                Section {
                    Button("Extract receipt items") {
                        Task {
                            await extractReceipt()
                        }
                    }
                    .disabled(
                        isParsing
                        || preparedText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )

                    if isParsing {
                        ProgressView("Extracting receipt…")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let result = extraction {
                    Section("Receipt summary — verify against photo") {
                        LabeledContent("Store") {
                            TextField("Enter store name", text: $merchantName)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: merchantName) { _, name in
                                    extraction?.merchantName = name.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                }
                        }

                        LabeledContent(
                            "Subtotal",
                            value: result.subtotal ?? "Unknown"
                        )

                        LabeledContent(
                            "Tax amounts",
                            value: result.taxAmounts.isEmpty
                                ? "Not extracted"
                                : result.taxAmounts.joined(separator: ", ")
                        )

                        LabeledContent(
                            "Total",
                            value: result.total ?? "Unknown"
                        )
                    }

                    Section("Extracted items") {
                        ForEach(result.items.indices, id: \.self) { index in
                            let item = result.items[index]

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(.headline)

                                Text(
                                    "Quantity: \(item.quantity ?? "Not shown")"
                                )

                                Text(
                                    "Unit price: \(item.unitPrice ?? "Not shown")"
                                )

                                Text(
                                    "Line total: \(item.lineTotal ?? "Unknown")"
                                )
                            }
                        }
                    }

                    Section("Review notes") {
                        Text(
                            "AI output may contain mistakes. "
                            + "Nothing has been saved."
                        )

                        ForEach(
                            result.warnings.indices,
                            id: \.self
                        ) { index in
                            Text(result.warnings[index])
                        }
                    }
                }
            }
            .navigationTitle("AI Receipt Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isParsing)
                }
            }
            .interactiveDismissDisabled(isParsing)
        }
    }

    @MainActor
    private func extractReceipt() async {
        errorMessage = nil
        extraction = nil
        merchantName = ""

        isParsing = true
        defer { isParsing = false }

        do {
            let result = try await aiService.extractReceipt(from: preparedText)
            merchantName = result.merchantName ?? ""
            extraction = result
        } catch let error as ReceiptAIService.ExtractionError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage =
                "Extraction failed: \(error.localizedDescription). "
                + "Try a shorter receipt or use manual entry."
        }
    }
}
