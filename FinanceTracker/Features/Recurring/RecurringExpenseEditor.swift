import SwiftUI
import SwiftData

struct RecurringExpenseEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var needsSplit: Bool
    @State private var name: String
    @State private var amount: String
    @State private var currency: String
    @State private var frequency: String
    @State private var firstDue: Date
    @State private var category: String
    @State private var error: String?
    let existing: RecurringExpense?

    init(expense: RecurringExpense? = nil, currency: String = "USD") {
        existing = expense
        _needsSplit = State(initialValue: expense?.needsSplit ?? false)
        _name = State(initialValue: expense?.name ?? "")
        _amount = State(initialValue: expense.map { NSDecimalNumber(decimal: Decimal($0.amountCents) / 100).stringValue } ?? "")
        _currency = State(initialValue: expense?.currencyCode ?? currency)
        _frequency = State(initialValue: expense?.frequency ?? "monthly")
        _firstDue = State(initialValue: expense?.firstDueDate ?? .now)
        _category = State(initialValue: expense?.category ?? "Household")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill details") {
                    TextField("Name, e.g. Rent or Wi-Fi", text: $name)
                    Toggle("Needs splitting when paid", isOn: $needsSplit)
                    TextField("Amount per payment", text: $amount).keyboardType(.decimalPad)
                    Picker("Currency", selection: $currency) {
                        ForEach(["USD", "EUR", "GBP", "CAD", "AUD", "INR"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                    }
                }
                Section {
                    Picker("Repeats", selection: $frequency) {
                        Text("Monthly").tag("monthly")
                        Text("Daily").tag("daily")
                    }
                    DatePicker("First due date", selection: $firstDue, displayedComponents: .date)
                } header: { Text("Schedule") }
                footer: {
                    Text("Monthly bills repeat on this day, using the last day in shorter months. Mark each payment paid when it happens. Paid history stays unchanged when you edit a bill.")
                }
            }
            .scrollContentBackground(.hidden).background(Color("AppBackground"))
            .navigationTitle(existing == nil ? "Add recurring expense" : "Edit recurring expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .alert("Couldn't save bill", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func save() {
        do {
            try RecurringStore.save(name: name, amount: amount, currency: currency, frequency: frequency,
                                    firstDue: firstDue, category: category, needsSplit: needsSplit, existing: existing, in: context)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
