import Foundation

// MARK: - Deduction Input Type
/// How a deduction amount is specified
enum DeductionInputType: String, Codable, CaseIterable, Identifiable {
    case dollarAmount
    case percentageOfSalary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dollarAmount:
            return "$"
        case .percentageOfSalary:
            return "%"
        }
    }

    var fullName: String {
        switch self {
        case .dollarAmount:
            return "Dollar Amount"
        case .percentageOfSalary:
            return "% of Salary"
        }
    }
}
