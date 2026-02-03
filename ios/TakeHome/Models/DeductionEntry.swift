import Foundation

// MARK: - Deduction Entry
/// A single deduction entry with flexible input options
struct DeductionEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var type: DeductionType
    var amount: Decimal
    var frequency: DeductionFrequency
    var inputType: DeductionInputType
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        type: DeductionType,
        amount: Decimal = 0,
        frequency: DeductionFrequency = .annual,
        inputType: DeductionInputType = .dollarAmount,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.frequency = frequency
        self.inputType = inputType
        self.isEnabled = isEnabled
    }

    /// Calculate the annual dollar amount for this deduction
    /// - Parameters:
    ///   - grossSalary: Annual gross salary (used for percentage calculations)
    ///   - payFrequency: Pay frequency (used for per-paycheck conversions)
    ///   - respectLimit: If true (default), caps result at IRS annual limit
    /// - Returns: Annual deduction amount in dollars (capped at IRS limit by default)
    func annualAmount(grossSalary: Decimal, payFrequency: PayFrequency, respectLimit: Bool = true) -> Decimal {
        guard isEnabled && amount > 0 else { return 0 }

        let rawAmount: Decimal
        switch inputType {
        case .dollarAmount:
            // Dollar amounts need frequency conversion
            rawAmount = frequency.toAnnual(amount, payFrequency: payFrequency)
        case .percentageOfSalary:
            // Percentage of salary is already annual (% of annual salary)
            // Frequency is not applicable here
            rawAmount = grossSalary * (amount / 100)
        }

        // Cap at IRS limit if applicable
        if respectLimit, let limit = type.annualLimit {
            return min(rawAmount, limit)
        }
        return rawAmount
    }

    /// Check if this deduction exceeds its IRS limit
    func exceedsLimit(grossSalary: Decimal, payFrequency: PayFrequency) -> Bool {
        guard let limit = type.annualLimit else { return false }
        // Use uncapped amount to check if user's input exceeds limit
        return annualAmount(grossSalary: grossSalary, payFrequency: payFrequency, respectLimit: false) > limit
    }

    /// Create default entries for all deduction types
    static func createDefaults() -> [DeductionEntry] {
        DeductionType.allCases.map { type in
            DeductionEntry(type: type)
        }
    }
}
