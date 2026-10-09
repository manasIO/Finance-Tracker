import SwiftUI
import FoundationModels

struct OnDeviceAIStatusView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var status = "Not checked yet"

    var body: some View {
        Section("On-device receipt AI") {
            Text(status)

            Button("Check availability") {
                checkAvailability()
            }
        }
        .onAppear {
            checkAvailability()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkAvailability()
            }
        }
    }

    private func checkAvailability() {
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                status = "Ready — Apple's on-device model is available."

            case .unavailable(.deviceNotEligible):
                status = "This device doesn't support the on-device model."

            case .unavailable(.appleIntelligenceNotEnabled):
                status = "Enable Apple Intelligence in Settings."

            case .unavailable(.modelNotReady):
                status = "The model isn't ready yet. Try again later."

            case .unavailable:
                status = "The model is currently unavailable."

            @unknown default:
                status = "Model availability couldn't be determined."
            }
        } else {
            status = "On-device receipt AI requires iOS 26 or later."
        }
    }
}
