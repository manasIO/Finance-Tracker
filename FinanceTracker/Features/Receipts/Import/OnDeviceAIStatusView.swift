import SwiftUI
import FoundationModels

struct OnDeviceAIStatusView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAvailable = false
    @State private var showingExplanation = false

    var body: some View {
        Section("Private on-device analysis") {
            Button { showingExplanation = true } label: {
                HStack {
                    Label(
                        isAvailable ? "Available" : "Unavailable",
                        systemImage: isAvailable ? "checkmark.circle" : "exclamationmark.circle"
                    )
                    .foregroundStyle(isAvailable ? Color.green : Color.secondary)
                    Spacer()
                    Image(systemName: "info.circle").foregroundStyle(Color.accentColor)
                }
            }
            .accessibilityLabel("On-device receipt analysis: \(isAvailable ? "available" : "unavailable"). Learn how it works")
        }
        .sheet(isPresented: $showingExplanation) {
            NavigationStack {
                List {
                    Section("How it works") {
                        Label("Reads your photo", systemImage: "doc.text.viewfinder").font(.headline)
                        Text("Apple's text recognition reads the words and prices in your receipt photo on your iPhone.")
                        Label("Organizes the details", systemImage: "sparkles").font(.headline)
                        Text("Apple's on-device language model identifies the store, items, and amounts, then suggests categories, Need/Want labels, and a grocery spending mix.")
                        Label("You stay in control", systemImage: "square.and.pencil").font(.headline)
                        Text("Suggestions can be wrong, especially with faded photos or abbreviated item names. Review and edit the details before saving.")
                    }
                    Section("On your device") {
                        Text("FinanceTracker processes the receipt locally. It does not send your receipt photo or text to an AI server. Saved receipt details stay in the app's local storage. Cloud sync is disabled, and local app data is excluded from device backups.")
                    }
                    Section("Availability") {
                        Text(isAvailable
                             ? "Your iPhone's on-device model is ready for receipt analysis."
                             : "The on-device model isn't ready right now. Check Apple Intelligence in Settings on a supported iPhone. You can still enter receipts manually.")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color("AppBackground"))
                .navigationTitle("Receipt analysis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingExplanation = false }
                    }
                }
            }
        }
        .onAppear { checkAvailability() }
        .onChange(of: scenePhase) { _, phase in
            // Recheck after the user changes Apple Intelligence settings.
            if phase == .active { checkAvailability() }
        }
    }

    private func checkAvailability() {
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            isAvailable = true
        } else {
            isAvailable = false
        }
    }
}
