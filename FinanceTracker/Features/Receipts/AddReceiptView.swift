import Foundation
import SwiftUI
import SwiftData

struct AddReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var needsSplit = false
    @State private var merchantName = ""
    @State private var purchaseDate = Date()
    @State private var items = [ManualReceiptItemDraft()]

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var duplicateMessage: String?

    private let categories = ItemCategory.allCases.map(\.rawValue)

    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt") {
                    Toggle("Needs splitting", isOn: $needsSplit)
                    TextField("Store name", text: $merchantName)

                    DatePicker(
                        "Purchase date",
                        selection: $purchaseDate,
                        displayedComponents: .date
                    )
                }

                Section {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Item name", text: $item.name)
                                .onChange(of: item.name) { _, _ in item.nameChanged() }

                            TextField(
                                "Line total in USD, e.g. 3.99",
                                text: $item.amount
                            )
                            .keyboardType(.decimalPad)

                            Picker("Category", selection: Binding(
                                get: { item.category },
                                set: { item.category = $0; item.categoryEdited = true }
                            )) {
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }

                            Picker(
                                "Classification",
                                selection: Binding(
                                    get: { item.classification },
                                    set: { item.classification = $0; item.classificationEdited = true }
                                )
                            ) {
                                Text("Unclassified").tag("Unclassified")
                                Text("Need").tag("Need")
                                Text("Want").tag("Want")
                            }
                            if item.category == "Groceries" {
                                Picker("Food spending", selection: Binding(
                                    get: { item.foodChoice },
                                    set: { item.foodChoice = $0; item.foodChoiceEdited = true }
                                )) {
                                    ForEach(FoodChoice.allCases, id: \.self) { Text($0.label).tag($0.rawValue) }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }

                    Button {
                        items.append(ManualReceiptItemDraft())
                    } label: {
                        Label("Add another item", systemImage: "plus")
                    }
                } header: {
                    Text("Items")
                } footer: {
                    Text(
                        "Enter each line's total, not its unit price. "
                        + "Use a decimal point, without $ or commas. "
                        + "Categories and Need/Want labels are editable suggestions."
                    )
                }

                Section("Calculated total") {
                    if let total = calculatedTotalCents {
                        Text(
                            Decimal(total) / Decimal(100),
                            format: .currency(code: "USD")
                        )
                        .font(.headline)
                    } else {
                        Text("Enter a valid amount for every item.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("AppBackground"))
            .navigationTitle("New Receipt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(!canSave)
                }
            }
            .task(id: items.map(\.name)) {
                // Debounce typing; only apply suggestions to fields still untouched.
                do {
                    try await Task.sleep(for: .milliseconds(700))
                    for snapshot in items where !snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        guard snapshot.suggestedName != snapshot.name, !snapshot.categoryEdited || !snapshot.classificationEdited || !snapshot.foodChoiceEdited else { continue }
                        let result = try await ItemAnalysisService().analyze(name: snapshot.name)
                        try Task.checkCancellation()
                        guard let index = items.firstIndex(where: { $0.id == snapshot.id && $0.name == snapshot.name }) else { continue }
                        items[index].apply(result, for: snapshot.name)
                    }
                } catch {
                    // Manual entry remains available when on-device AI is unavailable.
                }
            }
            .alert("Possible duplicate", isPresented: Binding(
                get: { duplicateMessage != nil },
                set: { if !$0 { duplicateMessage = nil } }
            )) {
                Button("Cancel", role: .cancel) { duplicateMessage = nil }
                Button("Save anyway") { duplicateMessage = nil; saveReceipt(allowDuplicate: true) }
            } message: {
                Text(duplicateMessage ?? "")
            }
            .interactiveDismissDisabled()
            .alert("Couldn't save receipt", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var calculatedTotalCents: Int64? {
        guard !items.isEmpty else { return nil }

        var total: Int64 = 0

        for item in items {
            guard let cents = parseCents(item.amount) else {
                return nil
            }

            let result = total.addingReportingOverflow(cents)
            guard !result.overflow else { return nil }
            total = result.partialValue
        }

        return total
    }

    private var canSave: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && calculatedTotalCents != nil
        && items.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveReceipt(allowDuplicate: Bool = false) {
        guard canSave, let total = calculatedTotalCents else {
            return
        }

        let receipt = Receipt(
            merchantName: merchantName.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            purchaseDate: purchaseDate,
            totalCents: total
        )

        var savedItems: [ReceiptItem] = []

        for draft in items {
            guard let cents = parseCents(draft.amount) else {
                return
            }

            let isLuxury: Bool?
            switch draft.classification {
            case "Need":
                isLuxury = false
            case "Want":
                isLuxury = true
            default:
                isLuxury = nil
            }

            savedItems.append(
                ReceiptItem(
                    name: draft.name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    lineTotalCents: cents,
                    category: draft.category,
                    isLuxury: isLuxury
                )
            )
            savedItems[savedItems.count - 1].foodChoice = draft.foodChoice
        }

        receipt.needsSplit = needsSplit
        receipt.items = savedItems
        do {
            try ReceiptStore.save(receipt, in: modelContext, allowDuplicate: allowDuplicate)
            dismiss()
        } catch let error as ReceiptStore.SaveError {
            duplicateMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // Convert text directly to integer cents without using Double.
    private func parseCents(_ input: String) -> Int64? {
        let text = input.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard text.range(
            of: #"^[0-9]{1,9}(\.[0-9]{1,2})?$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }

        let parts = text.split(
            separator: ".",
            omittingEmptySubsequences: false
        )

        guard let dollars = Int64(String(parts[0])) else {
            return nil
        }

        let fraction = parts.count == 2 ? String(parts[1]) : ""
        let paddedFraction = fraction.padding(
            toLength: 2,
            withPad: "0",
            startingAt: 0
        )

        guard let cents = Int64(paddedFraction) else {
            return nil
        }

        return dollars * 100 + cents
    }
}

#Preview {
    AddReceiptView()
        .modelContainer(
            for: [Receipt.self, ReceiptItem.self],
            inMemory: true
        )
}
