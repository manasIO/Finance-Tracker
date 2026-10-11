import SwiftUI
import SwiftData

struct RecurringExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringExpense.name) private var expenses: [RecurringExpense]
    @Query private var payments: [RecurringPayment]
    @State private var selectedMonth = Date()
    @State private var showingAdd = false
    @State private var editing: RecurringExpense?
    @State private var removing: RecurringExpense?
    @State private var error: String?
    let currency: String

    private var occurrences: [RecurringSchedule.Occurrence] {
        RecurringSchedule.occurrences(expenses: expenses, payments: payments, month: selectedMonth)
            .filter { $0.currencyCode == currency }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous month")
                    Spacer()
                    Text(selectedMonth, format: .dateTime.month(.wide).year()).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next month")
                }
                .buttonStyle(.borderless)
                LabeledContent("Scheduled total") {
                    Text(occurrences.reduce(Decimal(0)) { $0 + $1.amount }, format: .currency(code: currency))
                }
                Button { showingAdd = true } label: { Label("Add recurring expense", systemImage: "plus.circle.fill") }
            } footer: {
                Text("Bills are reserved in your budget. Mark paid to include them in spending. Bills saved here are counted separately from receipts.")
            }
            Section("Payments this month") {
                if occurrences.isEmpty { Text("No bills scheduled this month.").foregroundStyle(.secondary) }
                ForEach(occurrences) { occurrence in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(occurrence.name).font(.headline)
                                Text(occurrence.dueDate, format: .dateTime.month().day()).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(occurrence.amount, format: .currency(code: currency))
                        }
                        Button {
                            perform {
                                if occurrence.isPaid { try RecurringStore.markUnpaid(occurrence, in: context) }
                                else { try RecurringStore.markPaid(occurrence, in: context) }
                            }
                        } label: {
                            Label(occurrence.isPaid ? "Paid · tap to mark unpaid" : "Mark paid",
                                  systemImage: occurrence.isPaid ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.borderless)
                        if let payment = payments.first(where: { $0.occurrenceID == occurrence.id }) {
                            Toggle("Needs splitting", isOn: Binding(
                                get: { payment.needsSplit },
                                set: { value in perform { try SplitStore.setPending(value, for: .bill(payment), in: context) } }
                            ))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            Section("Your recurring bills") {
                ForEach(expenses.filter { $0.currencyCode == currency }) { expense in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(expense.name).font(.headline)
                            Spacer()
                            Text(Decimal(expense.amountCents) / 100, format: .currency(code: currency))
                        }
                        Text(expense.frequency == "daily" ? "Every day" : "Every month").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Edit") { editing = expense }
                            Spacer()
                            Button("Remove", role: .destructive) { removing = expense }
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color("AppBackground"))
        .navigationTitle("Recurring expenses")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) { RecurringExpenseEditor(currency: currency) }
        .sheet(item: $editing) { RecurringExpenseEditor(expense: $0) }
        .confirmationDialog("Remove recurring bill?", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), titleVisibility: .visible) {
            Button("Remove bill", role: .destructive) {
                if let expense = removing { perform { try RecurringStore.remove(expense, in: context) } }
                removing = nil
            }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: { Text("Future planned payments will be removed. Paid history is kept.") }
        .alert("Couldn't save changes", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func moveMonth(_ offset: Int) {
        let start = Calendar.current.dateInterval(of: .month, for: selectedMonth)!.start
        selectedMonth = Calendar.current.date(byAdding: .month, value: offset, to: start) ?? start
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }
}
