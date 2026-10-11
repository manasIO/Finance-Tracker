import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var error: String?
    let onCompleted: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if step == 0 {
                    Spacer()
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 72)).foregroundStyle(Color.accentColor)
                    Text("Your money. Your privacy.").font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text("Track receipts, budgets and recurring bills. Everything is processed and stored on your iPhone.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("No online account. No receipt uploads. No external AI requests.")
                        .font(.subheadline).multilineTextAlignment(.center)
                    Spacer()
                    Button("Get started") { step = 1 }.buttonStyle(.borderedProminent).controlSize(.large)
                } else {
                    Text("Make it yours").font(.title.bold())
                    Form {
                        Section {
                            TextField("Full name (optional)", text: $name).textContentType(.name)
                            TextField("Email (optional)", text: $email)
                                .textContentType(.emailAddress).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            TextField("Phone (optional)", text: $phone)
                                .textContentType(.telephoneNumber).keyboardType(.phonePad)
                        } footer: {
                            Text("All fields are optional and stay on this device. You can add or change them later in Profile.")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    Button("Continue") { finish() }.buttonStyle(.borderedProminent).controlSize(.large)
                }
                Button("Skip setup") { onCompleted() }
                    .padding(.bottom)
            }
            .padding(.horizontal, 24)
            .background(Color("AppBackground").ignoresSafeArea())
            .alert("Couldn't save profile", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func finish() {
        do {
            try ProfileStore.save(name: name, email: email, phone: phone, in: context)
            onCompleted()
        } catch { self.error = error.localizedDescription }
    }
}
