import Foundation

// MARK: - Scenario
/// A saved scenario for what-if comparisons
struct Scenario: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var input: TaxCalculationInput
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        input: TaxCalculationInput,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.input = input
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Scenario Comparison
/// Result of comparing two scenarios
struct ScenarioComparison: Equatable {
    var base: TaxCalculationResult
    var scenario: TaxCalculationResult
    var netDifference: Decimal
    var monthlyDifference: Decimal
    var isPositive: Bool

    var formattedNetDifference: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let sign = isPositive ? "+" : ""
        return sign + (formatter.string(from: netDifference as NSDecimalNumber) ?? "$0")
    }

    var formattedMonthlyDifference: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let sign = isPositive ? "+" : ""
        return sign + (formatter.string(from: monthlyDifference as NSDecimalNumber) ?? "$0")
    }
}

// MARK: - Household Split
/// Result of household expense splitting
struct HouseholdSplit: Equatable {
    var primaryRatio: Decimal
    var partnerRatio: Decimal
    var primaryAmount: Decimal
    var partnerAmount: Decimal

    var primaryPercentage: Double {
        NSDecimalNumber(decimal: primaryRatio * 100).doubleValue
    }

    var partnerPercentage: Double {
        NSDecimalNumber(decimal: partnerRatio * 100).doubleValue
    }
}

// MARK: - Split Method
enum SplitMethod: Equatable {
    case proportional
    case equal
    case custom(Decimal)

    var displayName: String {
        switch self {
        case .proportional: return "Proportional"
        case .equal: return "Equal (50/50)"
        case .custom(let pct): return "Custom (\(pct)%)"
        }
    }
}

// MARK: - Scenario Type
/// Common scenario types for quick creation
enum ScenarioType: String, CaseIterable, Identifiable {
    case raise
    case stateMove
    case retirementContribution
    case filingStatusChange
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raise: return "Salary Raise"
        case .stateMove: return "Move to Another State"
        case .retirementContribution: return "Change 401k Contribution"
        case .filingStatusChange: return "Filing Status Change"
        case .custom: return "Custom Scenario"
        }
    }

    var description: String {
        switch self {
        case .raise: return "See how a raise affects your take-home pay"
        case .stateMove: return "Compare taxes in different states"
        case .retirementContribution: return "Adjust retirement contributions"
        case .filingStatusChange: return "Marriage, divorce, or other status changes"
        case .custom: return "Create a custom what-if scenario"
        }
    }

    var icon: String {
        switch self {
        case .raise: return "arrow.up.circle.fill"
        case .stateMove: return "map.fill"
        case .retirementContribution: return "chart.line.uptrend.xyaxis"
        case .filingStatusChange: return "person.2.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}
