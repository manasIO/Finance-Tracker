import SwiftUI
import SwiftData

struct QuickExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var description = ""
    @State private var category = "Uncategorized"
    @State private var date = Date()
    @State private var needsSplit = false
    @State private var currency: String
    @State private var error: String?
    @State private var duplicate: String?
    @FocusState private var amountFocused: Bool

    init(currency: String = "USD") {
        _currency = State(initialValue: currency)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount, e.g. 12.00", text: $amount)
                        .keyboardType(.decimalPad).focused($amountFocused)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    TextField("Store or description (optional)", text: $description)
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(Array(Set(["USD", "EUR", "GBP", "CAD", "AUD", "INR", currency])).sorted(), id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } footer: { Text("Only the amount is required. No receipt needed. Saved privately on your iPhone.") }
                Section {
                    Toggle("Needs splitting", isOn: $needsSplit)
                } footer: { Text("Keep track of purchases to split with others later.") }
            }
            .scrollContentBackground(.hidden).background(Color("AppBackground"))
            .navigationTitle("Quick expense").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear { amountFocused = true }
            .alert("Couldn't save expense", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
            .alert("Possible duplicate", isPresented: Binding(get: { duplicate != nil }, set: { if !$0 { duplicate = nil } })) {
                Button("Cancel", role: .cancel) { duplicate = nil }
                Button("Save anyway") { duplicate = nil; save(allowDuplicate: true) }
            } message: { Text(duplicate ?? "") }
        }
    }

    private func save(allowDuplicate: Bool = false) {
        do {
            _ = try QuickExpenseStore.save(amount: amount, description: description, category: category,
                                          currency: currency, date: date, needsSplit: needsSplit,
                                          allowDuplicate: allowDuplicate, in: context)
            dismiss()
        } catch let error as ReceiptStore.SaveError {
            duplicate = error.localizedDescription
        } catch { self.error = error.localizedDescription }
    }
}
