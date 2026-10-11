import FoundationModels

@Generable
enum FoodChoice: String, CaseIterable {
    case healthier = "Healthier staples"
    case treat = "Treats"
    case unclassified = "Unclassified"

    // Keep stored values stable when presentation wording changes.
    var label: String {
        switch self {
        case .healthier: "Healthy"
        case .treat: "Junk"
        case .unclassified: "Unclassified"
        }
    }

    static let guidance = """
    For grocery items only, suggest Healthier staples for clearly described everyday
    foods such as plain milk, eggs, vegetables, fruit and unprocessed chicken.
    Suggest Treats for clearly described ice cream, candy, sugary desserts and soda.
    Food names do not establish nutrition facts or personal health. Do not infer
    added sugar, ingredients, preparation or portion sizes that aren't described.
    Use Unclassified for unclear abbreviations, mixed foods, ambiguous versions,
    and all non-grocery items. Suggestions must remain editable.
    """
}
