import Foundation
import SwiftData

@MainActor
enum ProfileStore {
    static func save(name: String, email: String, phone: String, in context: ModelContext) throws {
        let clean = [name, email, phone].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let existing = try context.fetch(FetchDescriptor<UserProfile>()).first
        // Skipping all optional fields needs no empty personal-information record.
        guard existing != nil || clean.contains(where: { !$0.isEmpty }) else { return }
        let profile = existing ?? UserProfile()
        if existing == nil { context.insert(profile) }
        profile.name = clean[0]
        profile.email = clean[1]
        profile.phone = clean[2]
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
