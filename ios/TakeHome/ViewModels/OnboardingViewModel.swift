import Foundation
import Combine

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case householdType = 1      // Choose single/twoIncomes/paired
    case income = 2
    case partnerIncome = 3      // Conditional - only for twoIncomes
    case householdSummary = 4   // Conditional - only for twoIncomes, shows combined view
    case location = 5
    case deductionSetup = 6     // Quick vs Detailed choice
    case deductionsPreTax = 7   // Full itemized pre-tax list (detailed mode)
    case deductionsPostTax = 8  // Full itemized post-tax list (detailed mode)
    case reveal = 9
    case expenses = 10
    case complete = 11

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .householdType: return "Household"
        case .income: return "Income"
        case .partnerIncome: return "Partner Income"
        case .householdSummary: return "Your Household"
        case .location: return "Location"
        case .deductionSetup: return "Deductions"
        case .deductionsPreTax: return "Pre-Tax Deductions"
        case .deductionsPostTax: return "Post-Tax Deductions"
        case .reveal: return "Your Take-Home"
        case .expenses: return "Expenses"
        case .complete: return "All Set!"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "Let's calculate your real take-home pay"
        case .householdType: return "Who's in your household?"
        case .income: return "Enter your salary"
        case .partnerIncome: return "Enter your partner's income"
        case .householdSummary: return "Your combined income"
        case .location: return "Where do you live?"
        case .deductionSetup: return "How detailed do you want to go?"
        case .deductionsPreTax: return "Deductions before taxes"
        case .deductionsPostTax: return "Deductions after taxes"
        case .reveal: return "Here's what you actually take home"
        case .expenses: return "Add your expenses to track spending"
        case .complete: return "You're ready to manage your finances"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .householdType: return "person.2.fill"
        case .income: return "dollarsign.circle.fill"
        case .partnerIncome: return "person.fill.badge.plus"
        case .householdSummary: return "house.fill"
        case .location: return "location.fill"
        case .deductionSetup: return "slider.horizontal.3"
        case .deductionsPreTax: return "minus.circle.fill"
        case .deductionsPostTax: return "minus.circle"
        case .reveal: return "sparkles"
        case .expenses: return "creditcard.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }

    /// Determine if this step should be shown based on user context
    func shouldShow(for context: OnboardingContext) -> Bool {
        switch self {
        case .partnerIncome, .householdSummary:
            return context.householdType == .twoIncomes
        case .deductionsPreTax, .deductionsPostTax:
            return context.deductionSetupMode == .detailed
        default:
            return true
        }
    }
}

// MARK: - Onboarding ViewModel
@MainActor
final class OnboardingViewModel: BaseViewModel {
    // MARK: - Dependencies
    private let taxCore: TakeHomeCoreProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol

    // MARK: - Published State
    @Published private(set) var currentStep: OnboardingStep = .welcome
    @Published private(set) var calculatedResult: TaxCalculationResult?
    @Published private(set) var isAnimatingReveal: Bool = false

    // User Input - Basic
    @Published var grossSalary: String = ""
    @Published var payFrequency: PayFrequency = .biWeekly
    @Published var selectedState: USState = .california
    @Published var filingStatus: FilingStatus = .single
    @Published var salaryInputFrequency: DeductionFrequency = .annual

    // User Input - Household
    @Published var householdType: HouseholdType = .single
    @Published var partnerName: String = ""
    @Published var partnerGrossSalary: String = ""
    @Published var partnerPayFrequency: PayFrequency = .biWeekly
    @Published var partnerState: USState = .california
    @Published var partnerFilingStatus: FilingStatus = .marriedFilingJointly
    @Published var partnerSalaryInputFrequency: DeductionFrequency = .annual

    // User Input - Deductions (Quick Mode)
    @Published var traditional401k: String = ""
    @Published var traditional401kInputType: DeductionInputType = .percentageOfSalary
    @Published var healthInsurance: String = ""
    @Published var healthInsuranceInputType: DeductionInputType = .dollarAmount

    // User Input - Deductions (Detailed Mode)
    @Published var deductionSetupMode: DeductionSetupMode = .quick
    @Published var deductionEntries: [DeductionEntry] = DeductionEntry.createDefaults()

    // User Input - Expenses
    @Published var expenses: [Expense] = []

    // MARK: - Computed Properties - Context
    var onboardingContext: OnboardingContext {
        OnboardingContext(
            householdType: householdType,
            deductionSetupMode: deductionSetupMode
        )
    }

    var visibleSteps: [OnboardingStep] {
        OnboardingStep.allCases.filter { $0.shouldShow(for: onboardingContext) }
    }

    var progress: Double {
        guard let currentIndex = visibleSteps.firstIndex(of: currentStep) else { return 0 }
        return Double(currentIndex) / Double(max(visibleSteps.count - 1, 1))
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .householdType:
            return householdType.isAvailable
        case .income:
            return grossSalaryDecimal > 0
        case .partnerIncome:
            return partnerGrossSalaryDecimal > 0 && !partnerName.trimmingCharacters(in: .whitespaces).isEmpty
        case .householdSummary:
            return true // Just a summary view
        case .location:
            return true // State and filing status have defaults
        case .deductionSetup:
            return true
        case .deductionsPreTax, .deductionsPostTax:
            return true // Deductions are optional
        case .reveal:
            return calculatedResult != nil
        case .expenses:
            return true // Expenses are optional in onboarding
        case .complete:
            return true
        }
    }

    // MARK: - Computed Properties - Salary Conversions
    var grossSalaryDecimal: Decimal {
        let raw = Decimal(string: grossSalary.replacingOccurrences(of: ",", with: "")) ?? 0
        return salaryInputFrequency.toAnnual(raw, payFrequency: payFrequency)
    }

    var partnerGrossSalaryDecimal: Decimal {
        let raw = Decimal(string: partnerGrossSalary.replacingOccurrences(of: ",", with: "")) ?? 0
        return partnerSalaryInputFrequency.toAnnual(raw, payFrequency: partnerPayFrequency)
    }

    // MARK: - Computed Properties - Household Totals
    var combinedGrossSalary: Decimal {
        grossSalaryDecimal + partnerGrossSalaryDecimal
    }

    var yourSharePercentage: Double {
        guard combinedGrossSalary > 0 else { return 0 }
        return NSDecimalNumber(decimal: grossSalaryDecimal / combinedGrossSalary * 100).doubleValue
    }

    var partnerSharePercentage: Double {
        guard combinedGrossSalary > 0 else { return 0 }
        return NSDecimalNumber(decimal: partnerGrossSalaryDecimal / combinedGrossSalary * 100).doubleValue
    }

    /// Raw value entered for 401k (could be dollars or percentage)
    private var traditional401kRawValue: Decimal {
        Decimal(string: traditional401k.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    /// Raw value entered for health insurance (could be dollars or percentage)
    private var healthInsuranceRawValue: Decimal {
        Decimal(string: healthInsurance.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    /// Annual 401k amount (converts percentage to dollars if needed, respects IRS limit)
    var traditional401kAnnual: Decimal {
        let rawAmount: Decimal
        switch traditional401kInputType {
        case .dollarAmount:
            rawAmount = traditional401kRawValue
        case .percentageOfSalary:
            rawAmount = grossSalaryDecimal * (traditional401kRawValue / 100)
        }
        // Cap at IRS 401k limit ($23,000 for 2024)
        let limit: Decimal = 23000
        return min(rawAmount, limit)
    }

    /// Annual health insurance amount (converts percentage to dollars if needed)
    var healthInsuranceAnnual: Decimal {
        switch healthInsuranceInputType {
        case .dollarAmount:
            return healthInsuranceRawValue
        case .percentageOfSalary:
            return grossSalaryDecimal * (healthInsuranceRawValue / 100)
        }
    }

    // Legacy computed properties for backwards compatibility
    var traditional401kDecimal: Decimal { traditional401kAnnual }
    var healthInsuranceDecimal: Decimal { healthInsuranceAnnual }

    // MARK: - Computed Properties - Deduction Totals
    var preTaxDeductionEntries: [DeductionEntry] {
        deductionEntries.filter { $0.type.isPreTax }
    }

    var postTaxDeductionEntries: [DeductionEntry] {
        deductionEntries.filter { !$0.type.isPreTax }
    }

    var totalPreTaxAnnual: Decimal {
        if deductionSetupMode == .quick {
            return traditional401kDecimal + healthInsuranceDecimal
        }
        return preTaxDeductionEntries.reduce(Decimal(0)) { sum, entry in
            sum + entry.annualAmount(grossSalary: grossSalaryDecimal, payFrequency: payFrequency)
        }
    }

    var totalPostTaxAnnual: Decimal {
        if deductionSetupMode == .quick {
            return 0
        }
        return postTaxDeductionEntries.reduce(Decimal(0)) { sum, entry in
            sum + entry.annualAmount(grossSalary: grossSalaryDecimal, payFrequency: payFrequency)
        }
    }

    var totalPreTaxPercent: Double {
        guard grossSalaryDecimal > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalPreTaxAnnual / grossSalaryDecimal * 100).doubleValue
    }

    var totalPostTaxPercent: Double {
        guard grossSalaryDecimal > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalPostTaxAnnual / grossSalaryDecimal * 100).doubleValue
    }

    var availableStates: [USState] {
        taxCore.allStateCodes
    }

    var availableFilingStatuses: [FilingStatus] {
        taxCore.allFilingStatuses
    }

    // MARK: - Initialization
    init(
        taxCore: TakeHomeCoreProtocol,
        profileRepository: FinancialProfileRepositoryProtocol
    ) {
        self.taxCore = taxCore
        self.profileRepository = profileRepository
        super.init()
    }

    // MARK: - Navigation
    func next() async {
        print("🔵 next() called, currentStep: \(currentStep), canProceed: \(canProceed)")
        guard canProceed else {
            print("🔴 Cannot proceed from step \(currentStep)")
            return
        }

        let context = onboardingContext
        let allSteps = OnboardingStep.allCases
        print("🟢 Proceeding from step \(currentStep)")

        // Special handling for steps that need actions before advancing
        switch currentStep {
        case .deductionSetup where deductionSetupMode == .quick:
            // Quick mode skips detailed deductions, go straight to reveal after calculating
            await calculateTakeHome()
            advanceToNextVisibleStep(from: currentStep, context: context, steps: allSteps)
            return
        case .deductionsPostTax:
            // After detailed deductions, calculate and advance
            await calculateTakeHome()
            advanceToNextVisibleStep(from: currentStep, context: context, steps: allSteps)
            return
        case .reveal:
            await saveProfile()
            advanceToNextVisibleStep(from: currentStep, context: context, steps: allSteps)
            return
        case .complete:
            return
        default:
            break
        }

        advanceToNextVisibleStep(from: currentStep, context: context, steps: allSteps)
    }

    private func advanceToNextVisibleStep(from step: OnboardingStep, context: OnboardingContext, steps: [OnboardingStep]) {
        guard let currentIndex = steps.firstIndex(of: step) else {
            print("🔴 Could not find index for step \(step)")
            return
        }

        print("🟡 Looking for next step after \(step) (index \(currentIndex))")
        for nextStep in steps[(currentIndex + 1)...] {
            if nextStep.shouldShow(for: context) {
                print("🟢 Advancing to step \(nextStep)")
                currentStep = nextStep
                return
            }
        }
        print("🔴 No valid next step found")
    }

    func back() {
        let context = onboardingContext
        let allSteps = OnboardingStep.allCases

        guard let currentIndex = allSteps.firstIndex(of: currentStep), currentIndex > 0 else { return }

        // Find previous visible step
        for prevStep in allSteps[..<currentIndex].reversed() {
            if prevStep.shouldShow(for: context) {
                currentStep = prevStep
                return
            }
        }
    }

    func skip() async {
        if currentStep == .expenses {
            currentStep = .complete
        }
    }

    // MARK: - Calculations
    func calculateTakeHome() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }

            let preTax: Decimal
            let trad401k: Decimal
            let roth401k: Decimal

            if self.deductionSetupMode == .quick {
                preTax = self.healthInsuranceDecimal
                trad401k = self.traditional401kDecimal
                roth401k = 0
            } else {
                // Calculate from entries, excluding 401k (handled separately)
                let nonRetirementPreTax = self.preTaxDeductionEntries
                    .filter { $0.type != .traditional401k && $0.type != .roth401k }
                    .reduce(Decimal(0)) { sum, entry in
                        sum + entry.annualAmount(grossSalary: self.grossSalaryDecimal, payFrequency: self.payFrequency)
                    }
                preTax = nonRetirementPreTax
                trad401k = self.deductionEntries
                    .first { $0.type == .traditional401k && $0.isEnabled }?
                    .annualAmount(grossSalary: self.grossSalaryDecimal, payFrequency: self.payFrequency) ?? 0
                roth401k = self.deductionEntries
                    .first { $0.type == .roth401k && $0.isEnabled }?
                    .annualAmount(grossSalary: self.grossSalaryDecimal, payFrequency: self.payFrequency) ?? 0
            }

            let input = TaxCalculationInput(
                grossIncome: self.grossSalaryDecimal,
                filingStatus: self.filingStatus,
                state: self.selectedState,
                preTaxDeductions: preTax,
                postTaxDeductions: self.totalPostTaxAnnual,
                traditional401k: trad401k,
                roth401k: roth401k
            )

            let result = try self.taxCore.computeTaxes(input: input)

            await MainActor.run {
                self.calculatedResult = result
                self.animateReveal()
            }
        }
    }

    private func animateReveal() {
        isAnimatingReveal = true
        // Animation will be handled by the view
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isAnimatingReveal = false
        }
    }

    // MARK: - Save Profile
    func saveProfile() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }

            let partnerProfile: PartnerProfile?
            if self.householdType == .twoIncomes {
                partnerProfile = PartnerProfile(
                    name: self.partnerName,
                    grossSalary: self.partnerGrossSalaryDecimal,
                    payFrequency: self.partnerPayFrequency,
                    state: self.partnerState,
                    filingStatus: self.partnerFilingStatus
                )
            } else {
                partnerProfile = nil
            }

            let deductions: DeductionProfile
            if self.deductionSetupMode == .quick {
                deductions = DeductionProfile(
                    traditional401k: self.traditional401kDecimal,
                    healthInsurance: self.healthInsuranceDecimal
                )
            } else {
                deductions = DeductionProfile(entries: self.deductionEntries.filter { $0.isEnabled })
            }

            let profile = FinancialProfile(
                name: "My Profile",
                income: IncomeProfile(
                    grossSalary: self.grossSalaryDecimal,
                    payFrequency: self.payFrequency
                ),
                location: LocationProfile(
                    state: self.selectedState,
                    filingStatus: self.filingStatus
                ),
                deductions: deductions,
                householdType: self.householdType,
                partnerProfile: partnerProfile
            )

            try await self.profileRepository.save(profile)
        }
    }

    // MARK: - Deduction Entry Helpers
    func updateDeductionEntry(_ entry: DeductionEntry) {
        if let index = deductionEntries.firstIndex(where: { $0.id == entry.id }) {
            deductionEntries[index] = entry
        }
    }

    func toggleDeductionEntry(id: UUID) {
        if let index = deductionEntries.firstIndex(where: { $0.id == id }) {
            deductionEntries[index].isEnabled.toggle()
        }
    }

    // MARK: - Expense Entry Helpers
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
    }

    func removeExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
    }

    func updateExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        }
    }

    var totalMonthlyExpenses: Decimal {
        expenses.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
    }

    var totalAnnualExpenses: Decimal {
        expenses.reduce(Decimal(0)) { $0 + $1.annualAmount }
    }

    // MARK: - Reset
    func reset() {
        currentStep = .welcome
        calculatedResult = nil

        // Basic income
        grossSalary = ""
        payFrequency = .biWeekly
        selectedState = .california
        filingStatus = .single
        salaryInputFrequency = .annual

        // Household
        householdType = .single
        partnerName = ""
        partnerGrossSalary = ""
        partnerPayFrequency = .biWeekly
        partnerState = .california
        partnerFilingStatus = .marriedFilingJointly
        partnerSalaryInputFrequency = .annual

        // Deductions
        traditional401k = ""
        traditional401kInputType = .percentageOfSalary
        healthInsurance = ""
        healthInsuranceInputType = .dollarAmount
        deductionSetupMode = .quick
        deductionEntries = DeductionEntry.createDefaults()

        // Expenses
        expenses = []
    }
}
