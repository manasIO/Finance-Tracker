import Foundation
import SwiftData

@MainActor
enum SplitStore {
    static func setPending(_ pending: Bool, for source: SplitExpenseSource, at date: Date = .now,
                           in context: ModelContext) throws {
        let resolved = pending ? nil : (source.pending ? date : source.resolvedAt)
        switch source {
        case .purchase(let receipt):
            receipt.needsSplit = pending
            receipt.splitResolvedAt = resolved
        case .bill(let payment):
            payment.needsSplit = pending
            payment.splitResolvedAt = resolved
        }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
