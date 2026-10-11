import FoundationModels

@Generable
enum ItemCategory: String, CaseIterable {
    case uncategorized = "Uncategorized"
    case groceries = "Groceries"
    case dining = "Dining"
    case household = "Household"
    case transport = "Transport"
    case health = "Health"
    case entertainment = "Entertainment"
    case gifts = "Gifts"
    case other = "Other"
}

@Generable
enum SpendingKind: String {
    case unclassified = "Unclassified"
    case need = "Need"
    case want = "Want"
}
