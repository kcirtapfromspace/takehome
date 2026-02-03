import Foundation

// MARK: - Life Event Scenario Model
// Designed to be LLM-friendly - an agent can generate these parameters from natural language

struct LifeEventScenario: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var category: LifeEventCategory

    // Financial changes
    var incomeChanges: [IncomeChange]
    var expenseChanges: [ExpenseChange]
    var taxChanges: [TaxChange]
    var savingsChanges: [SavingsChange]

    // Timeline
    var startDate: Date?
    var duration: EventDuration?

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        icon: String = "sparkles",
        category: LifeEventCategory = .other,
        incomeChanges: [IncomeChange] = [],
        expenseChanges: [ExpenseChange] = [],
        taxChanges: [TaxChange] = [],
        savingsChanges: [SavingsChange] = [],
        startDate: Date? = nil,
        duration: EventDuration? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.incomeChanges = incomeChanges
        self.expenseChanges = expenseChanges
        self.taxChanges = taxChanges
        self.savingsChanges = savingsChanges
        self.startDate = startDate
        self.duration = duration
    }
}

// MARK: - Life Event Category
enum LifeEventCategory: String, Codable, CaseIterable, Identifiable {
    case family
    case career
    case housing
    case retirement
    case education
    case health
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .family: return "Family"
        case .career: return "Career"
        case .housing: return "Housing"
        case .retirement: return "Retirement"
        case .education: return "Education"
        case .health: return "Health"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .family: return "figure.2.and.child.holdinghands"
        case .career: return "briefcase.fill"
        case .housing: return "house.fill"
        case .retirement: return "sunset.fill"
        case .education: return "graduationcap.fill"
        case .health: return "heart.fill"
        case .other: return "sparkles"
        }
    }
}

// MARK: - Income Change
struct IncomeChange: Identifiable, Codable {
    let id: UUID
    var type: IncomeChangeType
    var amount: Decimal
    var isPercentage: Bool
    var frequency: ChangeFrequency
    var duration: EventDuration?
    var reason: String

    init(
        id: UUID = UUID(),
        type: IncomeChangeType,
        amount: Decimal,
        isPercentage: Bool = false,
        frequency: ChangeFrequency = .monthly,
        duration: EventDuration? = nil,
        reason: String = ""
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.isPercentage = isPercentage
        self.frequency = frequency
        self.duration = duration
        self.reason = reason
    }

    // Convert to monthly impact
    func monthlyImpact(baseSalary: Decimal) -> Decimal {
        // For percentage, calculate based on annual salary then convert
        let annualBase = isPercentage ? baseSalary * (amount / 100) : amount

        // If there's a duration, amortize the impact over 12 months
        // (showing the "average monthly impact" for the first year)
        if let dur = duration, let months = dur.totalMonths, months < 12 {
            // Temporary change - show amortized monthly impact
            let totalImpact: Decimal
            switch frequency {
            case .oneTime: totalImpact = annualBase
            case .monthly: totalImpact = annualBase * Decimal(months)
            case .annual: totalImpact = annualBase
            }
            return totalImpact / 12  // Spread over the year
        }

        // Ongoing or 12+ month changes
        switch frequency {
        case .oneTime: return annualBase / 12
        case .monthly: return annualBase
        case .annual: return annualBase / 12
        }
    }
}

enum IncomeChangeType: String, Codable, CaseIterable {
    case raise
    case reduction
    case bonus
    case sideIncome
    case passiveIncome
    case unemploymentBenefits
    case socialSecurity
    case pension
    case disability
}

// MARK: - Expense Change
struct ExpenseChange: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Decimal
    var frequency: ChangeFrequency
    var category: ExpenseCategory
    var isOneTime: Bool
    var duration: EventDuration?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        frequency: ChangeFrequency = .monthly,
        category: ExpenseCategory = .necessities,
        isOneTime: Bool = false,
        duration: EventDuration? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.category = category
        self.isOneTime = isOneTime
        self.duration = duration
    }

    var monthlyAmount: Decimal {
        if isOneTime { return 0 } // One-time doesn't affect monthly
        switch frequency {
        case .oneTime: return 0
        case .monthly: return amount
        case .annual: return amount / 12
        }
    }
}

// MARK: - Tax Change
struct TaxChange: Identifiable, Codable {
    let id: UUID
    var type: TaxChangeType
    var name: String
    var amount: Decimal
    var isPercentage: Bool

    init(
        id: UUID = UUID(),
        type: TaxChangeType,
        name: String,
        amount: Decimal,
        isPercentage: Bool = false
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.amount = amount
        self.isPercentage = isPercentage
    }
}

enum TaxChangeType: String, Codable {
    case credit      // Reduces tax owed
    case deduction   // Reduces taxable income
    case exemption   // Dependent exemption
}

// MARK: - Savings Change
struct SavingsChange: Identifiable, Codable {
    let id: UUID
    var type: SavingsChangeType
    var amount: Decimal
    var isPercentage: Bool
    var reason: String

    init(
        id: UUID = UUID(),
        type: SavingsChangeType,
        amount: Decimal,
        isPercentage: Bool = false,
        reason: String = ""
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.isPercentage = isPercentage
        self.reason = reason
    }
}

enum SavingsChangeType: String, Codable {
    case emergency       // Emergency fund contribution
    case retirement      // 401k/IRA changes
    case college529      // Education savings
    case hsa             // Health savings
    case general         // General savings
    case withdrawal      // Using savings
}

// MARK: - Supporting Types
enum ChangeFrequency: String, Codable, CaseIterable {
    case oneTime
    case monthly
    case annual

    var displayName: String {
        switch self {
        case .oneTime: return "One-time"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }
}

enum EventDuration: Codable, Equatable {
    case months(Int)
    case years(Int)
    case ongoing

    var displayName: String {
        switch self {
        case .months(let n): return "\(n) month\(n == 1 ? "" : "s")"
        case .years(let n): return "\(n) year\(n == 1 ? "" : "s")"
        case .ongoing: return "Ongoing"
        }
    }

    var totalMonths: Int? {
        switch self {
        case .months(let n): return n
        case .years(let n): return n * 12
        case .ongoing: return nil
        }
    }
}

// MARK: - Scenario Impact Calculation
struct LifeEventImpact {
    let scenario: LifeEventScenario
    let monthlyIncomeChange: Decimal
    let monthlyExpenseChange: Decimal
    let annualTaxChange: Decimal
    let oneTimeExpenses: Decimal
    let netMonthlyImpact: Decimal
    let netAnnualImpact: Decimal

    var isPositive: Bool {
        netMonthlyImpact >= 0
    }
}

extension LifeEventScenario {
    func calculateImpact(baseSalary: Decimal, currentNetMonthly: Decimal) -> LifeEventImpact {
        // Calculate income changes
        let monthlyIncomeChange = incomeChanges.reduce(Decimal(0)) { sum, change in
            sum + change.monthlyImpact(baseSalary: baseSalary)
        }

        // Calculate expense changes
        let monthlyExpenseChange = expenseChanges.reduce(Decimal(0)) { sum, change in
            sum + change.monthlyAmount
        }

        // Calculate one-time expenses
        let oneTimeExpenses = expenseChanges
            .filter { $0.isOneTime }
            .reduce(Decimal(0)) { sum, change in sum + change.amount }

        // Calculate tax changes (simplified - annual impact)
        let annualTaxChange = taxChanges.reduce(Decimal(0)) { sum, change in
            switch change.type {
            case .credit:
                return sum - change.amount // Credits reduce taxes
            case .deduction:
                return sum - (change.amount * Decimal(0.22)) // Estimate 22% bracket
            case .exemption:
                return sum - (change.amount * Decimal(0.22))
            }
        }

        // Net impact
        let netMonthlyImpact = monthlyIncomeChange - monthlyExpenseChange + (annualTaxChange / 12)
        let netAnnualImpact = netMonthlyImpact * 12

        return LifeEventImpact(
            scenario: self,
            monthlyIncomeChange: monthlyIncomeChange,
            monthlyExpenseChange: monthlyExpenseChange,
            annualTaxChange: annualTaxChange,
            oneTimeExpenses: oneTimeExpenses,
            netMonthlyImpact: netMonthlyImpact,
            netAnnualImpact: netAnnualImpact
        )
    }
}

// MARK: - Pre-built Templates
extension LifeEventScenario {

    // MARK: - First Child
    static func firstChild() -> LifeEventScenario {
        LifeEventScenario(
            name: "Having a Baby",
            description: "First child - includes parental leave, childcare, and ongoing expenses",
            icon: "figure.and.child.holdinghands",
            category: .family,
            incomeChanges: [
                // Assume 6 weeks unpaid leave (partial pay during leave)
                // Average impact: ~10% of annual income lost in first year
                IncomeChange(
                    type: .reduction,
                    amount: -10,
                    isPercentage: true,
                    frequency: .annual,
                    duration: .years(1),
                    reason: "Unpaid parental leave (6 weeks)"
                )
            ],
            expenseChanges: [
                ExpenseChange(name: "Childcare/Daycare", amount: 1500, frequency: .monthly, category: .necessities, duration: .years(5)),
                ExpenseChange(name: "Diapers & Supplies", amount: 100, frequency: .monthly, category: .necessities, duration: .years(3)),
                ExpenseChange(name: "Baby Food/Formula", amount: 150, frequency: .monthly, category: .necessities, duration: .years(1)),
                ExpenseChange(name: "Pediatrician & Health", amount: 75, frequency: .monthly, category: .necessities),
                ExpenseChange(name: "Baby Gear & Furniture", amount: 3000, frequency: .oneTime, category: .necessities, isOneTime: true),
                ExpenseChange(name: "Hospital/Birth Costs (after insurance)", amount: 2000, frequency: .oneTime, category: .necessities, isOneTime: true)
            ],
            taxChanges: [
                TaxChange(type: .credit, name: "Child Tax Credit", amount: 2000),
                TaxChange(type: .deduction, name: "Dependent Care FSA", amount: 5000)
            ],
            savingsChanges: [
                SavingsChange(type: .college529, amount: 200, reason: "Start college fund")
            ],
            duration: .ongoing
        )
    }

    // MARK: - Fixed Income / Retirement
    static func retirement() -> LifeEventScenario {
        LifeEventScenario(
            name: "Retirement",
            description: "Transition to fixed income - Social Security and retirement distributions",
            icon: "sunset.fill",
            category: .retirement,
            incomeChanges: [
                // Net change: Social Security + Pension - Work Income
                // For someone making $80k, retiring to ~$4k/month fixed income
                IncomeChange(
                    type: .socialSecurity,
                    amount: 2200,
                    frequency: .monthly,
                    reason: "Social Security benefits"
                ),
                IncomeChange(
                    type: .pension,
                    amount: 1800,
                    frequency: .monthly,
                    reason: "Pension/401k distributions"
                )
            ],
            expenseChanges: [
                ExpenseChange(name: "Medicare Premiums", amount: 175, frequency: .monthly, category: .necessities),
                ExpenseChange(name: "Medicare Supplement", amount: 200, frequency: .monthly, category: .necessities),
                ExpenseChange(name: "Prescription Drugs", amount: 100, frequency: .monthly, category: .necessities),
                // Reduced expenses (negative = savings)
                ExpenseChange(name: "Commuting (eliminated)", amount: -350, frequency: .monthly, category: .vehicle),
                ExpenseChange(name: "Work Clothes (eliminated)", amount: -75, frequency: .monthly, category: .necessities)
            ],
            taxChanges: [
                TaxChange(type: .deduction, name: "Standard Deduction (65+)", amount: 1850)
            ],
            duration: .ongoing
        )
    }

    // MARK: - Job Loss
    static func jobLoss() -> LifeEventScenario {
        LifeEventScenario(
            name: "Job Loss",
            description: "Unexpected unemployment - budget adjustments and job search",
            icon: "briefcase.fill",
            category: .career,
            incomeChanges: [
                // Unemployment benefits typically replace 40-50% of income, capped
                IncomeChange(
                    type: .unemploymentBenefits,
                    amount: 2000,
                    frequency: .monthly,
                    duration: .months(6),
                    reason: "Unemployment benefits (~$500/week)"
                )
            ],
            expenseChanges: [
                ExpenseChange(name: "COBRA Health Insurance", amount: 700, frequency: .monthly, category: .necessities, duration: .months(6)),
                ExpenseChange(name: "Job Search Costs", amount: 150, frequency: .monthly, category: .other, duration: .months(3)),
                // Savings from reduced spending
                ExpenseChange(name: "Commuting (eliminated)", amount: -300, frequency: .monthly, category: .vehicle),
                ExpenseChange(name: "Work Lunches (eliminated)", amount: -200, frequency: .monthly, category: .necessities)
            ],
            savingsChanges: [
                SavingsChange(type: .withdrawal, amount: 5000, reason: "Emergency fund usage")
            ],
            duration: .months(6)
        )
    }

    // MARK: - Getting Married
    static func gettingMarried() -> LifeEventScenario {
        LifeEventScenario(
            name: "Getting Married",
            description: "Combining finances with a partner",
            icon: "heart.fill",
            category: .family,
            incomeChanges: [
                IncomeChange(
                    type: .sideIncome,
                    amount: 0, // User will customize
                    frequency: .monthly,
                    reason: "Spouse's income contribution"
                )
            ],
            expenseChanges: [
                ExpenseChange(name: "Wedding Costs", amount: 25000, frequency: .oneTime, category: .other, isOneTime: true),
                ExpenseChange(name: "Honeymoon", amount: 5000, frequency: .oneTime, category: .entertainment, isOneTime: true),
                ExpenseChange(name: "Housing (shared)", amount: -500, frequency: .monthly, category: .home),
                ExpenseChange(name: "Insurance (combined)", amount: -100, frequency: .monthly, category: .necessities)
            ],
            taxChanges: [
                TaxChange(type: .deduction, name: "Married Filing Jointly", amount: 13850)
            ],
            duration: .ongoing
        )
    }

    // MARK: - Buying a Car
    static func buyingCar() -> LifeEventScenario {
        LifeEventScenario(
            name: "Buying a Car",
            description: "New vehicle purchase with financing",
            icon: "car.fill",
            category: .other,
            expenseChanges: [
                ExpenseChange(name: "Car Payment", amount: 500, frequency: .monthly, category: .vehicle, duration: .years(5)),
                ExpenseChange(name: "Full Coverage Insurance", amount: 150, frequency: .monthly, category: .vehicle),
                ExpenseChange(name: "Down Payment", amount: 5000, frequency: .oneTime, category: .vehicle, isOneTime: true),
                ExpenseChange(name: "Registration & Taxes", amount: 1500, frequency: .oneTime, category: .vehicle, isOneTime: true)
            ],
            duration: .years(5)
        )
    }

    // MARK: - Going Back to School
    static func backToSchool() -> LifeEventScenario {
        LifeEventScenario(
            name: "Going Back to School",
            description: "Pursuing additional education while working",
            icon: "graduationcap.fill",
            category: .education,
            incomeChanges: [
                IncomeChange(
                    type: .reduction,
                    amount: -20,
                    isPercentage: true,
                    frequency: .monthly,
                    duration: .years(2),
                    reason: "Reduced hours while studying"
                )
            ],
            expenseChanges: [
                ExpenseChange(name: "Tuition", amount: 15000, frequency: .annual, category: .other, duration: .years(2)),
                ExpenseChange(name: "Books & Supplies", amount: 500, frequency: .annual, category: .other, duration: .years(2))
            ],
            taxChanges: [
                TaxChange(type: .credit, name: "Lifetime Learning Credit", amount: 2000)
            ],
            duration: .years(2)
        )
    }

    // MARK: - Disability
    static func disability() -> LifeEventScenario {
        LifeEventScenario(
            name: "Disability",
            description: "Long-term disability affecting income",
            icon: "figure.roll",
            category: .health,
            incomeChanges: [
                IncomeChange(
                    type: .reduction,
                    amount: -100,
                    isPercentage: true,
                    frequency: .monthly,
                    reason: "Unable to work"
                ),
                IncomeChange(
                    type: .disability,
                    amount: 2000,
                    frequency: .monthly,
                    reason: "Disability benefits (60% of salary typical)"
                )
            ],
            expenseChanges: [
                ExpenseChange(name: "Medical Expenses", amount: 500, frequency: .monthly, category: .necessities),
                ExpenseChange(name: "Home Modifications", amount: 10000, frequency: .oneTime, category: .home, isOneTime: true),
                ExpenseChange(name: "Commuting (eliminated)", amount: -300, frequency: .monthly, category: .vehicle)
            ],
            duration: .ongoing
        )
    }

    // MARK: - All Templates
    static var allTemplates: [LifeEventScenario] {
        [
            .firstChild(),
            .retirement(),
            .jobLoss(),
            .gettingMarried(),
            .buyingCar(),
            .backToSchool(),
            .disability()
        ]
    }
}
