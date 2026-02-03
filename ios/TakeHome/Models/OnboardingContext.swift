import Foundation

// MARK: - Deduction Setup Mode
/// How the user wants to enter deductions
enum DeductionSetupMode: String, Codable, CaseIterable, Identifiable {
    case quick
    case detailed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quick:
            return "Quick Setup"
        case .detailed:
            return "Detailed Setup"
        }
    }

    var description: String {
        switch self {
        case .quick:
            return "Just 401(k) and health insurance"
        case .detailed:
            return "All deduction types with flexible input"
        }
    }

    var icon: String {
        switch self {
        case .quick:
            return "hare.fill"
        case .detailed:
            return "slider.horizontal.3"
        }
    }
}

// MARK: - Onboarding Context
/// Context for determining which onboarding steps to show
struct OnboardingContext {
    var householdType: HouseholdType
    var deductionSetupMode: DeductionSetupMode

    init(
        householdType: HouseholdType = .single,
        deductionSetupMode: DeductionSetupMode = .quick
    ) {
        self.householdType = householdType
        self.deductionSetupMode = deductionSetupMode
    }
}
