import Foundation

// MARK: - Partner Profile
/// Profile for a partner in a two-income household
struct PartnerProfile: Codable, Equatable {
    var name: String
    var grossSalary: Decimal
    var payFrequency: PayFrequency
    var state: USState
    var filingStatus: FilingStatus

    init(
        name: String = "",
        grossSalary: Decimal = 0,
        payFrequency: PayFrequency = .biWeekly,
        state: USState = .california,
        filingStatus: FilingStatus = .marriedFilingJointly
    ) {
        self.name = name
        self.grossSalary = grossSalary
        self.payFrequency = payFrequency
        self.state = state
        self.filingStatus = filingStatus
    }

    /// Calculate annual salary based on gross salary (assumed annual input)
    var annualSalary: Decimal {
        grossSalary
    }
}
