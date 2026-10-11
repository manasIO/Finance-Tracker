import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var analyzingGroceries = false
    @State private var groceryAnalysisError: String?
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
    @Query private var recurringExpenses: [RecurringExpense]
    @Query private var recurringPayments: [RecurringPayment]
    @Query private var budgets: [MonthlyBudget]
    @State private var showingQuickExpense = false
    @State private var showingBudget = false
    @State private var showingReceiptOptions = false
    @State private var showingManualReceipt = false
    @State private var importingPhoto = false
    @State private var takingPhoto = false
    @State private var monthCount = 6
    @State private var selectedDate: Date?
    @State private var selectedCurrency = "USD"

    private var currencies: [String] { Array(Set(receipts.map(\.currencyCode) + recurringExpenses.map(\.currencyCode) + recurringPayments.map(\.currencyCode) + budgets.map(\.currencyCode))).sorted() }
    private var currency: String {
        currencies.contains(selectedCurrency) ? selectedCurrency : (currencies.first ?? "USD")
    }

    var body: some View {
        NavigationStack {
            // Refresh at midnight and after foregrounding without querying a server.
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                dashboard(now: timeline.date)
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingQuickExpense) { QuickExpenseView(currency: currency) }
            .confirmationDialog("Add receipt", isPresented: $showingReceiptOptions, titleVisibility: .visible) {
                Button("Import photo") { importingPhoto = true }
                Button("Take photo") { takingPhoto = true }
                Button("Enter manually") { showingManualReceipt = true }
            }
            .navigationDestination(isPresented: $importingPhoto) { ReceiptImportView() }
            .navigationDestination(isPresented: $takingPhoto) { ReceiptImportView(source: .camera) }
            .sheet(isPresented: $showingManualReceipt) { AddReceiptView() }
            .task { await analyzeGroceries(silent: true) }
            .alert("Couldn't analyze groceries", isPresented: Binding(
                get: { groceryAnalysisError != nil },
                set: { if !$0 { groceryAnalysisError = nil } }
            )) {
                Button("OK", role: .cancel) { groceryAnalysisError = nil }
            } message: { Text(groceryAnalysisError ?? "") }
        }
    }

    private func dashboard(now: Date) -> some View {
        let summary = SpendingSummary(
            entries: receipts.map { .init(date: $0.purchaseDate, totalCents: $0.totalCents, currencyCode: $0.currencyCode) }
                + recurringPayments.map { .init(date: $0.paidDate, totalCents: $0.amountCents, currencyCode: $0.currencyCode, isReceipt: false) },
            now: now,
            currencyCode: currency
        )
        let recurring = RecurringSchedule.occurrences(expenses: recurringExpenses, payments: recurringPayments,
                                                    month: now).filter { $0.currencyCode == currency }
        let planned = recurring.reduce(Decimal(0)) { $0 + $1.amount }
        let reserved = recurring.filter { !$0.isPaid }.reduce(Decimal(0)) { $0 + $1.amount }
        let budget = budgets.first { $0.month == summary.currentMonth.start && $0.currencyCode == currency && $0.amountCents > 0 }
        let itemEntries: [CategorySummary.Entry] = receipts.map { receipt in
            .init(date: receipt.purchaseDate, currency: receipt.currencyCode, totalCents: receipt.totalCents,
                  items: receipt.items.map { .init(category: $0.category, isLuxury: $0.isLuxury, cents: $0.lineTotalCents, foodChoice: $0.foodChoice) })
        } + recurringPayments.map { payment in
            .init(date: payment.paidDate, currency: payment.currencyCode, totalCents: payment.amountCents,
                  items: [.init(category: payment.category, isLuxury: nil, cents: payment.amountCents)])
        }
        let categories = CategorySummary(entries: itemEntries, now: now, currency: currency)
        let food = FoodSpendingSummary(entries: itemEntries, now: now, currency: currency)
        return List {
            Section {
                Button { showingQuickExpense = true } label: {
                    Label("Quick expense", systemImage: "plus.circle.fill")
                        .font(.headline).padding(.vertical, 6)
                }
                Button { showingReceiptOptions = true } label: {
                    Label("Add receipt", systemImage: "doc.viewfinder")
                        .font(.headline).padding(.vertical, 6)
                }
            } footer: {
                Label("Private · Saved on your iPhone", systemImage: "lock.shield")
            }
            if currencies.count > 1 {
                Section {
                    Picker("Currency", selection: Binding(get: { currency }, set: { selectedCurrency = $0 })) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    Text("Spending is shown separately for each currency.")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(now, format: .dateTime.month(.wide).year())
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(summary.currentMonth.total, format: .currency(code: currency))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text("Spent so far")
                        .foregroundStyle(.secondary)
                    comparison(summary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color("SummaryBackground"))
            } header: {
                Text("This month")
            }

            Section {
                NavigationLink {
                    RecurringExpensesView(currency: currency)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Recurring expenses", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(planned, format: .currency(code: currency))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("\(recurring.count) payments this month · \(recurring.filter(\.isPaid).count) paid")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color("SummaryBackground"))
            }

            Section {
                NavigationLink { SplitExpensesView() } label: {
                    HStack {
                        Label("Split expenses", systemImage: "person.2")
                        Spacer()
                        Text("\(receipts.filter(\.needsSplit).count + recurringPayments.filter(\.needsSplit).count) pending")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Monthly budget") {
                if let budget {
                    let status = RecurringBudgetStatus(limitCents: budget.amountCents, spent: summary.currentMonth.total, recurring: recurring)
                    let limit = status.limit
                    let committed = status.committed
                    let remaining = status.remaining
                    LabeledContent("Budget") { Text(limit, format: .currency(code: currency)) }
                    ProgressView(value: min(max(NSDecimalNumber(decimal: committed / limit).doubleValue, 0), 1))
                        .accessibilityLabel("Budget spent or reserved")
                        .accessibilityValue(Text(committed, format: .currency(code: currency)))
                    LabeledContent(remaining >= 0 ? "Available after bills" : "Over budget") {
                        Text(abs(remaining), format: .currency(code: currency))
                            .foregroundStyle(remaining >= 0 ? Color.accentColor : Color.orange)
                    }
                    LabeledContent("Reserved for unpaid bills") { Text(reserved, format: .currency(code: currency)) }
                    Button("Edit budget") { showingBudget = true }
                } else {
                    Button { showingBudget = true } label: {
                        Label("Set this month's budget", systemImage: "target")
                    }
                }
            }

            // Keep detailed breakdowns one tap away so the dashboard stays focused.
            Section("Insights") {
                if !categories.categories.isEmpty || categories.adjustment != 0 {
                    NavigationLink {
                        List { categoryBreakdown(categories) }
                            .navigationTitle("Spending categories")
                    } label: { Label("Categories & needs", systemImage: "chart.pie") }
                }
                NavigationLink {
                    List { foodSpending(food) }.navigationTitle("Grocery spending")
                } label: { Label("Grocery spending mix", systemImage: "carrot") }
            }

            if summary.firstRecordedMonth == nil {
                ContentUnavailableView(
                    "Start tracking your spending",
                    systemImage: "chart.bar",
                    description: Text("Add a receipt or mark a recurring bill paid to see monthly totals and trends.")
                )
            } else {
                Section("History") {
                    NavigationLink {
                        List { trends(summary) }.navigationTitle("Spending trends")
                    } label: { Label("Spending trends", systemImage: "chart.bar") }
                    NavigationLink {
                        List {
                            ForEach(summary.history) { month in
                                NavigationLink {
                                    MonthReceiptsView(month: month.start, currencyCode: currency)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(month.start, format: .dateTime.month(.wide).year())
                                                .font(.headline)
                                            Text(month.start == summary.currentMonth.start
                                                 ? "Purchases and paid bills · month to date"
                                                 : "Purchases and paid bills")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(month.total, format: .currency(code: currency))
                                    }
                                }
                            }
                        }
                        .navigationTitle("Monthly history")
                    } label: { Label("Monthly history", systemImage: "calendar") }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .sheet(isPresented: $showingBudget) {
            BudgetEditorView(month: summary.currentMonth.start, currency: currency, amountCents: budget?.amountCents)
        }
        .onChange(of: monthCount) { _, _ in selectedDate = nil }
        .onChange(of: currency) { _, _ in selectedDate = nil }
    }

    private func analyzeGroceries(silent: Bool) async {
        guard !analyzingGroceries else { return }
        analyzingGroceries = true
        defer { analyzingGroceries = false }
        do {
            try await SavedGroceryAnalysis().classify(receipts.flatMap(\.items), in: modelContext)
        } catch is CancellationError {
        } catch {
            if !silent { groceryAnalysisError = error.localizedDescription }
        }
    }

    private func foodSpending(_ summary: FoodSpendingSummary) -> some View {
        Section {
            if summary.total > 0 {
                Chart(summary.slices.filter { $0.amount > 0 }) { slice in
                    SectorMark(angle: .value("Spending", NSDecimalNumber(decimal: slice.amount).doubleValue),
                               innerRadius: .ratio(0.65), angularInset: 3)
                        .foregroundStyle(by: .value("Food spending", slice.choice.label))
                        .accessibilityLabel(slice.choice.label)
                        .accessibilityValue(NSDecimalNumber(decimal: slice.share).doubleValue.formatted(.percent))
                }
                .chartForegroundStyleScale([
                    FoodChoice.healthier.label: Color.green,
                    FoodChoice.treat.label: Color.orange,
                    FoodChoice.unclassified.label: Color.gray
                ])
                .frame(height: 190)
                ForEach(summary.slices) { slice in
                    LabeledContent(slice.choice.label) {
                        VStack(alignment: .trailing) {
                            Text(NSDecimalNumber(decimal: slice.share).doubleValue,
                                 format: .percent.precision(.fractionLength(0)))
                            Text(slice.amount, format: .currency(code: currency))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Save a receipt with grocery items to see your food spending mix.")
                    .foregroundStyle(.secondary)
            }
            if analyzingGroceries {
                ProgressView("Analyzing groceries on your iPhone…")
            } else if receipts.flatMap(\.items).contains(where: { $0.category == "Groceries" && $0.foodChoice == nil }) {
                Button("Analyze saved groceries") { Task { await analyzeGroceries(silent: false) } }
            }
        } header: { Text("Grocery spending mix") }
        footer: {
            Text("Estimated from grocery item names, not nutrition labels or what you eat. Percentages use item spending, excluding tax and discounts. Unclear items remain unclassified; edit suggestions in review or receipt details.")
        }
    }

    @ViewBuilder
    private func categoryBreakdown(_ summary: CategorySummary) -> some View {
        Section {
            ForEach(summary.categories) { row in
                LabeledContent(row.name) {
                    Text(row.total, format: .currency(code: currency))
                }
            }
            if summary.adjustment != 0 {
                LabeledContent("Tax, adjustments & missing items") {
                    Text(summary.adjustment, format: .currency(code: currency))
                }
                .foregroundStyle(.secondary)
            }
        } header: { Text("This month's categories") }
        footer: { Text("Based on item prices. Unallocated receipt amounts are shown separately so totals match your spending.") }
        Section {
            LabeledContent("Needs") { Text(summary.needs, format: .currency(code: currency)) }
            LabeledContent("Wants") { Text(summary.wants, format: .currency(code: currency)) }
            LabeledContent("Unclassified") { Text(summary.unclassified, format: .currency(code: currency)) }
        } header: { Text("Needs & wants") }
        footer: { Text("Item classifications are suggestions. Tax and other adjustments are excluded.") }
    }

    @ViewBuilder
    private func comparison(_ summary: SpendingSummary) -> some View {
        if let ratio = summary.changeRatio {
            let change = NSDecimalNumber(decimal: abs(ratio)).doubleValue.formatted(.percent.precision(.fractionLength(1)))
            Label(
                ratio == 0 ? "Same spending as last month" : "\(change) \(ratio > 0 ? "more" : "less") than last month",
                systemImage: ratio == 0 ? "equal" : (ratio > 0 ? "arrow.up.right" : "arrow.down.right")
            )
            .font(.subheadline)
            Text("Compared with the same elapsed days last month.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Text(summary.previousMonthToDateCount == 0
                 ? "No spending recorded for the same period last month."
                 : "Last month's comparable spending was zero.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func trends(_ summary: SpendingSummary) -> some View {
        let months = Array(summary.months.suffix(monthCount))
        let selected = selectedDate.flatMap { date in
            months.first { Calendar.current.isDate($0.start, equalTo: date, toGranularity: .month) }
        }
        return Section {
            Picker("Period", selection: $monthCount) {
                Text("6 months").tag(6)
                Text("12 months").tag(12)
            }
            .pickerStyle(.segmented)

            Chart(months) { month in
                BarMark(
                    x: .value("Month", month.start, unit: .month),
                    y: .value("Spending", NSDecimalNumber(decimal: month.total).doubleValue)
                )
                .foregroundStyle(month.start == summary.currentMonth.start ? Color.accentColor : Color.accentColor.opacity(0.4))
                .accessibilityLabel(Text(month.start, format: .dateTime.month(.wide).year()))
                .accessibilityValue(Text(month.total, format: .currency(code: currency)))
                if let selected, month.id == selected.id {
                    RuleMark(x: .value("Selected month", month.start, unit: .month))
                        .foregroundStyle(.secondary)
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: months.enumerated().filter { monthCount == 6 || $0.offset % 2 == 0 }.map { $0.element.start }) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: currency).precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .frame(height: 220)

            if let selected {
                LabeledContent {
                    Text(selected.total, format: .currency(code: currency))
                } label: {
                    Text(selected.start, format: .dateTime.month(.wide).year())
                }
            }
        } header: {
            Text("Spending trend")
        } footer: {
            Text("Tap the chart to inspect a month. The highlighted bar is the current, incomplete month.")
        }
    }
}

#Preview {
    DashboardView().modelContainer(for: [Receipt.self, ReceiptItem.self, MonthlyBudget.self, RecurringExpense.self, RecurringPayment.self], inMemory: true)
}
