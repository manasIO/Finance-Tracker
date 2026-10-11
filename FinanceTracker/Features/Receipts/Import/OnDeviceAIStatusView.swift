import SwiftUI
import FoundationModels

struct OnDeviceAIStatusView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAvailable = false

    var body: some View {
        Section("On-device receipt analysis") {
            Label(
                isAvailable ? "Available" : "Unavailable",
                systemImage: isAvailable ? "checkmark.circle" : "exclamationmark.circle"
            )
            .foregroundStyle(isAvailable ? Color.green : Color.secondary)
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
