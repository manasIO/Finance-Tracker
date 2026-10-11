import Foundation

struct ManualReceiptItemDraft: Identifiable {
    let id = UUID()
    var name = ""
    var amount = ""
    var category = "Uncategorized"
    var classification = "Unclassified"
    var categoryEdited = false
    var classificationEdited = false
    var foodChoice = FoodChoice.unclassified.rawValue
    var foodChoiceEdited = false
    var suggestedName: String?

    mutating func nameChanged() {
        if !categoryEdited { category = "Uncategorized" }
        if !classificationEdited { classification = "Unclassified" }
        if !foodChoiceEdited { foodChoice = FoodChoice.unclassified.rawValue }
        suggestedName = nil
    }

    mutating func apply(_ suggestion: ItemAnalysis, for analyzedName: String) {
        // A slow response must never overwrite a renamed item or a user's choice.
        guard name == analyzedName else { return }
        if !categoryEdited { category = suggestion.category.rawValue }
        if !classificationEdited { classification = suggestion.classification.rawValue }
        if !foodChoiceEdited { foodChoice = suggestion.foodChoice.rawValue }
        suggestedName = analyzedName
    }
}
