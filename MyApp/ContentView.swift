import Foundation
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Receipt.purchaseData, order: .reverse)
    private var receipts: [Receipt]
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View{
        NavigationStack {
            List {
                Section {
                    Button {
                        addSampleReceipt()
                    } label: {
                        Label("Add sample receipt", systemImage: "plus")
                    }
                }
                
                Section("Saved receipts"){
                    if receipts.isEmpty {
                        Text("No receipts yet. Add a sample to get started. ")
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(receipts) { receipt in
                        NavigationLink{
                            ReceiptDetailView(receipt: receipt)
                        } label: {
                            HStack {
                                VStack(alignement: .leading, spacing: 4) {
                                    Text(receipt.merchantName)
                                        .font(.headline)
                                    
                                    Text(
                                        receipt.purchaseDate,
                                        format: .dateTime.month().day().year()
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(
                                    dollars(receipt.totalCents),
                                    format: .currency(code: receipt.currencyCode)
                                )
                            }
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                }
            }
            .navigationTitle("Finance Tracker")
            .alert("Couldn't save changes", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addSampleReceipt() {
        let reciept = Receipt(
            merchantName: "Walmart",
            totalCents: 1247
        )
        
        let milk = ReceiptItem(
            name: "Milk",
            unitPriceCents: 399,
            lineTotalCents: 399,
            category: "Groceries",
            isLuxury: false
        )
        
        let apples = ReceiptItem(
                    name: "Apples",
                    quantity: 2,
                    unitPriceCents: 149,
                    lineTotalCents: 298,
                    category: "Groceries",
                    isLuxury: false
                )

        let cookies = ReceiptItem(
            name: "Cookies",
            unitPriceCents: 550,
            lineTotalCents: 550,
            category: "Groceries",
            isLuxury: true
        )
        
        reciept.items = [milk, apples, cookies]
        
        modelContext.insert(reciept)
        saveChanges()
    }
    
    private func deleteReceipts(at offsets: IndexSet){
        let recieptsToDelete = offset.map { receipts[$0] }
        
        for receipt in receiptToDelete {
            modelContext.delete(receipt)
        }
        saveChanges()
    }
    
    private func saveChanges(){
        do{
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
