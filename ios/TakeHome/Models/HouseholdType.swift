import Foundation

// MARK: - Household Type
/// Defines the type of household for expense splitting and multi-person scenarios
enum HouseholdType: String, Codable, CaseIterable, Identifiable {
    case single           // Single person household
    case twoIncomes       // Two incomes, manual partner entry
    case paired           // Paired accounts (coming soon)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single:
            return "Single"
        case .twoIncomes:
            return "Two Incomes"
        case .paired:
            return "Paired Accounts"
        }
    }

    var description: String {
        switch self {
        case .single:
            return "Track your finances individually"
        case .twoIncomes:
            return "Enter your partner's income for proportional expense splitting"
        case .paired:
            return "Link accounts for real-time household sync"
        }
    }

    var icon: String {
        switch self {
        case .single:
            return "person.fill"
        case .twoIncomes:
            return "person.2.fill"
        case .paired:
            return "link.circle.fill"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .single, .twoIncomes:
            return true
        case .paired:
            return false // Coming soon
        }
    }
}
