import SwiftUI

struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let selected: ProfileAvatar
    let onSelect: (ProfileAvatar) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Pick a face that feels like you.")
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 24) {
                        ForEach(ProfileAvatar.allCases, id: \.self) { avatar in
                            Button {
                                onSelect(avatar)
                                dismiss()
                            } label: {
                                VStack(spacing: 10) {
                                    AnimalAvatarView(avatar: avatar)
                                        .overlay(alignment: .bottomTrailing) {
                                            if avatar == selected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title2).foregroundStyle(.white, Color.accentColor)
                                                    .padding(8)
                                            }
                                        }
                                        .padding(5)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 23)
                                                .stroke(avatar == selected ? Color.accentColor : .clear, lineWidth: 3)
                                        }
                                    Text(avatar.name).font(.headline).foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(avatar == selected ? .isSelected : [])
                        }
                    }
                }
                .padding(24)
            }
            .background(Color("AppBackground"))
            .navigationTitle("Choose your avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
