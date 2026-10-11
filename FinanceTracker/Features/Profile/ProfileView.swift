import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @AppStorage("appTheme") private var theme: AppTheme = .system
    @State private var choosingAvatar = false
    @State private var avatar: ProfileAvatar = .cat
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var message: String?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { choosingAvatar = true } label: {
                        VStack(spacing: 12) {
                            AnimalAvatarView(avatar: avatar).frame(width: 100, height: 100)
                            Label("Change avatar", systemImage: "pencil")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Change your profile avatar")
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name", text: $name).textContentType(.name)
                    TextField("Email (optional)", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Phone (optional)", text: $phone)
                        .textContentType(.telephoneNumber).keyboardType(.phonePad)
                    Button("Save profile") { save() }
                } header: {
                    Text("Personal information")
                } footer: {
                    Text("Saved on this device. A profile is optional and does not create an online account.")
                }
                Section("Privacy") {
                    Label("Private by design", systemImage: "lock.shield")
                        .foregroundStyle(Color.accentColor)
                    Text("Receipt photos are read and analyzed on your iPhone. No uploads, external AI requests, or analytics.")
                    Text("Your receipts and profile stay in local storage, with cloud sync and storage backups disabled.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        Text("System").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("AppBackground"))
            .navigationTitle("Profile")
            .onAppear {
                guard !didLoad else { return }
                avatar = ProfileAvatar(rawValue: profiles.first?.avatarSymbol ?? "") ?? .cat
                name = profiles.first?.name ?? ""
                email = profiles.first?.email ?? ""
                phone = profiles.first?.phone ?? ""
                didLoad = true
            }
            .sheet(isPresented: $choosingAvatar) {
                AvatarPickerView(selected: avatar, onSelect: selectAvatar)
            }
            .alert("Profile", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private func selectAvatar(_ selected: ProfileAvatar) {
        let profile = profiles.first ?? UserProfile()
        if profiles.isEmpty { context.insert(profile) }
        profile.avatarSymbol = selected.rawValue
        do {
            try context.save()
            avatar = selected
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }

    private func save() {
        let profile = profiles.first ?? UserProfile()
        if profiles.isEmpty { context.insert(profile) }
        profile.avatarSymbol = avatar.rawValue
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try context.save()
            message = "Your profile is saved."
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }
}
