import Foundation
import Combine

// MARK: - Retirement Calculator ViewModel
@MainActor
final class RetirementCalculatorViewModel: BaseViewModel {
    // MARK: - Constants

    /// 2024 IRS 401(k) contribution limits
    static let standardLimit: Decimal = 23000
    static let catchUpLimit: Decimal = 7500 // Additional for 50+
    static let totalLimitOver50: Decimal = 30500

    // MARK: - Dependencies
    private let taxCore: TakeHomeCoreProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol

    // MARK: - Published State - User Inputs
    @Published var traditional401k: Decimal = 0
    @Published var roth401k: Decimal = 0
    @Published var isOver50: Bool = false

    // Employer Match Settings
    @Published var hasEmployerMatch: Bool = false
    @Published var employerMatchPercentage: Decimal = 0 // e.g., 50 for 50%
    @Published var employerMatchCap: Decimal = 6 // e.g., 6 for up to 6% of salary
    @Published var vestingPercentage: Decimal = 100 // 0-100

    // Profile data (loaded from repository)
    @Published private(set) var grossSalary: Decimal = 0
    @Published private(set) var filingStatus: FilingStatus = .single
    @Published private(set) var selectedState: USState = .california
    @Published private(set) var preTaxDeductions: Decimal = 0
    @Published private(set) var postTaxDeductions: Decimal = 0

    // MARK: - Published State - Calculated Results
    @Published private(set) var resultWithContributions: TaxCalculationResult?
    @Published private(set) var resultWithoutContributions: TaxCalculationResult?
    @Published private(set) var traditionalOnlyResult: TaxCalculationResult?
    @Published private(set) var rothOnlyResult: TaxCalculationResult?

    // MARK: - Computed Properties - Contributions

    var totalEmployeeContribution: Decimal {
        traditional401k + roth401k
    }

    var contributionLimit: Decimal {
        isOver50 ? Self.totalLimitOver50 : Self.standardLimit
    }

    var remainingContributionRoom: Decimal {
        max(0, contributionLimit - totalEmployeeContribution)
    }

    var isOverLimit: Bool {
        totalEmployeeContribution > contributionLimit
    }

    var limitWarningMessage: String? {
        guard isOverLimit else { return nil }
        let excess = totalEmployeeContribution - contributionLimit
        return "Contributions exceed IRS limit by \(formatCurrency(excess))"
    }

    // MARK: - Computed Properties - Employer Match

    var employerContribution: Decimal {
        guard hasEmployerMatch, grossSalary > 0 else { return 0 }

        // Employee contribution percentage of salary
        let employeeContribPercent = (traditional401k + roth401k) / grossSalary * 100

        // Employer matches up to the cap
        let matchablePercent = min(employeeContribPercent, employerMatchCap)

        // Calculate match amount
        let matchAmount = grossSalary * (matchablePercent / 100) * (employerMatchPercentage / 100)

        return matchAmount
    }

    var vestedEmployerContribution: Decimal {
        employerContribution * (vestingPercentage / 100)
    }

    var totalRetirementContribution: Decimal {
        totalEmployeeContribution + vestedEmployerContribution
    }

    // MARK: - Computed Properties - Tax Impact

    var annualTaxSavings: Decimal {
        guard let withContrib = resultWithContributions,
              let withoutContrib = resultWithoutContributions else { return 0 }
        return withoutContrib.totalTaxes - withContrib.totalTaxes
    }

    var monthlyTaxSavings: Decimal {
        annualTaxSavings / 12
    }

    var effectiveCostOfContribution: Decimal {
        // Traditional 401k reduces taxes, so effective cost is less than contribution
        traditional401k - annualTaxSavings
    }

    var takeHomeReduction: Decimal {
        guard let withContrib = resultWithContributions,
              let withoutContrib = resultWithoutContributions else { return 0 }
        return withoutContrib.netAnnual - withContrib.netAnnual
    }

    var monthlyTakeHomeReduction: Decimal {
        takeHomeReduction / 12
    }

    // MARK: - Computed Properties - Comparison

    /// Net monthly income with all-traditional strategy
    var traditionalNetMonthly: Decimal {
        traditionalOnlyResult?.netMonthly ?? 0
    }

    /// Net monthly income with all-Roth strategy
    var rothNetMonthly: Decimal {
        rothOnlyResult?.netMonthly ?? 0
    }

    /// Monthly difference (positive means traditional gives more take-home)
    var traditionalVsRothDifference: Decimal {
        traditionalNetMonthly - rothNetMonthly
    }

    // MARK: - Display Mode Toggle
    @Published var usePercentageMode: Bool = true

    // MARK: - Slider Bounds & Values

    var maxSliderValueDollar: Double {
        Double(truncating: contributionLimit as NSDecimalNumber)
    }

    var maxSliderValuePercent: Double {
        guard grossSalary > 0 else { return 100 }
        // Cap percentage at what would hit the contribution limit
        let maxPercent = (contributionLimit / grossSalary) * 100
        return min(Double(truncating: maxPercent as NSDecimalNumber), 100)
    }

    // Traditional 401k - Percentage
    var traditional401kPercent: Double {
        guard grossSalary > 0 else { return 0 }
        return Double(truncating: (traditional401k / grossSalary * 100) as NSDecimalNumber)
    }

    var traditional401kPercentSlider: Double {
        get { traditional401kPercent }
        set {
            guard grossSalary > 0 else { return }
            traditional401k = (Decimal(newValue) / 100) * grossSalary
        }
    }

    // Traditional 401k - Dollar
    var traditional401kSliderValue: Double {
        get { Double(truncating: traditional401k as NSDecimalNumber) }
        set { traditional401k = Decimal(newValue) }
    }

    // Roth 401k - Percentage
    var roth401kPercent: Double {
        guard grossSalary > 0 else { return 0 }
        return Double(truncating: (roth401k / grossSalary * 100) as NSDecimalNumber)
    }

    var roth401kPercentSlider: Double {
        get { roth401kPercent }
        set {
            guard grossSalary > 0 else { return }
            roth401k = (Decimal(newValue) / 100) * grossSalary
        }
    }

    // Roth 401k - Dollar
    var roth401kSliderValue: Double {
        get { Double(truncating: roth401k as NSDecimalNumber) }
        set { roth401k = Decimal(newValue) }
    }

    // Combined percentage
    var totalContributionPercent: Double {
        guard grossSalary > 0 else { return 0 }
        return Double(truncating: (totalEmployeeContribution / grossSalary * 100) as NSDecimalNumber)
    }

    // MARK: - Initialization

    init(
        taxCore: TakeHomeCoreProtocol,
        profileRepository: FinancialProfileRepositoryProtocol
    ) {
        self.taxCore = taxCore
        self.profileRepository = profileRepository
        super.init()
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Recalculate when contribution amounts change
        Publishers.CombineLatest($traditional401k, $roth401k)
            .combineLatest($isOver50)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.recalculateAll()
                }
            }
            .store(in: &cancellables)

        // Recalculate when employer match settings change
        Publishers.CombineLatest4(
            $hasEmployerMatch,
            $employerMatchPercentage,
            $employerMatchCap,
            $vestingPercentage
        )
        .dropFirst()
        .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            Task { [weak self] in
                await self?.recalculateAll()
            }
        }
        .store(in: &cancellables)

        // Subscribe to profile updates
        profileRepository.profilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let profile = profile else { return }
                self?.loadFromProfile(profile)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func loadData() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            if let profile = try await self.profileRepository.load() {
                await MainActor.run {
                    self.loadFromProfile(profile)
                }
            }
            await self.recalculateAll()
        }
    }

    func recalculateAll() async {
        guard grossSalary > 0 else {
            resultWithContributions = nil
            resultWithoutContributions = nil
            traditionalOnlyResult = nil
            rothOnlyResult = nil
            return
        }

        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }

            // Calculate with current contributions
            let withContrib = try self.calculateTaxes(
                traditional: self.traditional401k,
                roth: self.roth401k
            )

            // Calculate without any 401k contributions
            let withoutContrib = try self.calculateTaxes(
                traditional: 0,
                roth: 0
            )

            // Calculate with all contribution going to Traditional
            let traditionalOnly = try self.calculateTaxes(
                traditional: self.totalEmployeeContribution,
                roth: 0
            )

            // Calculate with all contribution going to Roth
            let rothOnly = try self.calculateTaxes(
                traditional: 0,
                roth: self.totalEmployeeContribution
            )

            await MainActor.run {
                self.resultWithContributions = withContrib
                self.resultWithoutContributions = withoutContrib
                self.traditionalOnlyResult = traditionalOnly
                self.rothOnlyResult = rothOnly
            }
        }
    }

    func setMaxTraditional() {
        let available = contributionLimit - roth401k
        traditional401k = max(0, available)
    }

    func setMaxRoth() {
        let available = contributionLimit - traditional401k
        roth401k = max(0, available)
    }

    func saveContributions() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }

            // Load current profile, update deductions, and save
            var profile = try await self.profileRepository.load() ?? FinancialProfile()
            profile.deductions.traditional401k = self.traditional401k
            profile.deductions.roth401k = self.roth401k
            try await self.profileRepository.save(profile)
        }
    }

    // MARK: - Private Helpers

    private func calculateTaxes(traditional: Decimal, roth: Decimal) throws -> TaxCalculationResult {
        let input = TaxCalculationInput(
            grossIncome: grossSalary,
            filingStatus: filingStatus,
            state: selectedState,
            preTaxDeductions: preTaxDeductions,
            postTaxDeductions: postTaxDeductions,
            traditional401k: traditional,
            roth401k: roth
        )
        return try taxCore.computeTaxes(input: input)
    }

    private func loadFromProfile(_ profile: FinancialProfile) {
        grossSalary = profile.income.grossSalary
        filingStatus = profile.location.filingStatus
        selectedState = profile.location.state
        preTaxDeductions = profile.deductions.preTaxTotal
        postTaxDeductions = profile.deductions.postTaxTotal
        traditional401k = profile.deductions.traditional401k
        roth401k = profile.deductions.roth401k
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
