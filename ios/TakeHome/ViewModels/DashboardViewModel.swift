import Foundation
import Combine
import SwiftUI
import StoreKit

// MARK: - Dashboard ViewModel
@MainActor
final class DashboardViewModel: BaseViewModel {
    // MARK: - Dependencies
    private let taxCore: TakeHomeCoreProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol
    private let expenseRepository: ExpenseRepositoryProtocol

    // MARK: - Published State
    @Published private(set) var profile: FinancialProfile?
    @Published private(set) var taxResult: TaxCalculationResult?
    @Published private(set) var partnerTaxResult: TaxCalculationResult?
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published var selectedTimeframe: Timeframe = .monthly
    @Published var selectedCashflowPeriod: CashflowPeriod = .month
    @Published var isHouseholdMode: Bool = false

    // MARK: - Computed Properties
    var hasProfile: Bool {
        profile != nil
    }

    var hasPartner: Bool {
        profile?.householdType == .twoIncomes && profile?.partnerProfile != nil
    }

    var canEnableHouseholdMode: Bool {
        hasPartner
    }

    // MARK: - Primary Income
    var primaryNetIncome: Decimal {
        guard let result = taxResult else { return 0 }
        switch selectedTimeframe {
        case .annual: return result.netAnnual
        case .monthly: return result.netMonthly
        case .biWeekly: return result.netBiWeekly
        case .weekly: return result.netWeekly
        case .daily: return result.netDaily
        case .hourly: return result.netHourly
        }
    }

    var partnerNetIncome: Decimal {
        guard let result = partnerTaxResult else { return 0 }
        switch selectedTimeframe {
        case .annual: return result.netAnnual
        case .monthly: return result.netMonthly
        case .biWeekly: return result.netBiWeekly
        case .weekly: return result.netWeekly
        case .daily: return result.netDaily
        case .hourly: return result.netHourly
        }
    }

    var netIncome: Decimal {
        if isHouseholdMode && hasPartner {
            return primaryNetIncome + partnerNetIncome
        }
        return primaryNetIncome
    }

    // MARK: - Household Split
    var primarySharePercentage: Double {
        guard isHouseholdMode, hasPartner else { return 100 }
        let total = primaryNetIncome + partnerNetIncome
        guard total > 0 else { return 50 }
        return NSDecimalNumber(decimal: primaryNetIncome / total * 100).doubleValue
    }

    var partnerSharePercentage: Double {
        guard isHouseholdMode, hasPartner else { return 0 }
        let total = primaryNetIncome + partnerNetIncome
        guard total > 0 else { return 50 }
        return NSDecimalNumber(decimal: partnerNetIncome / total * 100).doubleValue
    }

    var partnerName: String {
        profile?.partnerProfile?.name ?? "Partner"
    }

    var totalExpenses: Decimal {
        // In household mode, show all expenses; in single mode, show only non-shared or all
        let relevantExpenses = isHouseholdMode ? expenses : expenses
        let monthlyTotal = relevantExpenses.reduce(0) { $0 + $1.monthlyAmount }
        switch selectedTimeframe {
        case .annual: return monthlyTotal * 12
        case .monthly: return monthlyTotal
        case .biWeekly: return monthlyTotal * 12 / 26
        case .weekly: return monthlyTotal * 12 / 52
        case .daily: return monthlyTotal * 12 / 365
        case .hourly: return monthlyTotal * 12 / (365 * 24)
        }
    }

    var sharedExpensesTotal: Decimal {
        let monthlyTotal = expenses.filter { $0.isShared }.reduce(0) { $0 + $1.monthlyAmount }
        switch selectedTimeframe {
        case .annual: return monthlyTotal * 12
        case .monthly: return monthlyTotal
        case .biWeekly: return monthlyTotal * 12 / 26
        case .weekly: return monthlyTotal * 12 / 52
        case .daily: return monthlyTotal * 12 / 365
        case .hourly: return monthlyTotal * 12 / (365 * 24)
        }
    }

    var primaryExpenseShare: Decimal {
        guard isHouseholdMode, hasPartner else { return totalExpenses }
        let sharedPortion = sharedExpensesTotal * Decimal(primarySharePercentage / 100)
        let personalExpenses = expenses.filter { !$0.isShared }.reduce(0) { $0 + $1.monthlyAmount }
        let personalForTimeframe: Decimal
        switch selectedTimeframe {
        case .annual: personalForTimeframe = personalExpenses * 12
        case .monthly: personalForTimeframe = personalExpenses
        case .biWeekly: personalForTimeframe = personalExpenses * 12 / 26
        case .weekly: personalForTimeframe = personalExpenses * 12 / 52
        case .daily: personalForTimeframe = personalExpenses * 12 / 365
        case .hourly: personalForTimeframe = personalExpenses * 12 / (365 * 24)
        }
        return sharedPortion + personalForTimeframe
    }

    var partnerExpenseShare: Decimal {
        guard isHouseholdMode, hasPartner else { return 0 }
        return sharedExpensesTotal * Decimal(partnerSharePercentage / 100)
    }

    var remainingAfterExpenses: Decimal {
        netIncome - totalExpenses
    }

    var expensesPercentage: Double {
        guard netIncome > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalExpenses / netIncome * 100).doubleValue
    }

    var remainingPercentage: Double {
        guard netIncome > 0 else { return 0 }
        return NSDecimalNumber(decimal: remainingAfterExpenses / netIncome * 100).doubleValue
    }

    var topExpenseCategories: [(ExpenseCategory, Decimal)] {
        let byCategory = Dictionary(grouping: expenses, by: { $0.category })
        return byCategory
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.monthlyAmount }) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { ($0.0, $0.1) }
    }

    // MARK: - Financial Health Ratios
    var housingExpensesMonthly: Decimal {
        expenses.filter { $0.category == .home || $0.category == .debt }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    var housingRatio: Double {
        guard let result = taxResult, result.netMonthly > 0 else { return 0 }
        return NSDecimalNumber(decimal: housingExpensesMonthly / result.netMonthly * 100).doubleValue
    }

    var housingRatioStatus: RatioStatus {
        switch housingRatio {
        case ..<30: return .good
        case 30..<35: return .warning
        default: return .danger
        }
    }

    var savingsRate: Double {
        guard remainingPercentage > 0 else { return 0 }
        return remainingPercentage
    }

    var savingsRateStatus: RatioStatus {
        switch savingsRate {
        case 20...: return .good
        case 10..<20: return .warning
        default: return .danger
        }
    }

    var necessitiesExpensesMonthly: Decimal {
        expenses.filter { $0.category == .necessities }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    var necessitiesRatio: Double {
        guard let result = taxResult, result.netMonthly > 0 else { return 0 }
        return NSDecimalNumber(decimal: necessitiesExpensesMonthly / result.netMonthly * 100).doubleValue
    }

    var discretionaryExpensesMonthly: Decimal {
        expenses.filter { $0.category == .entertainment || $0.category == .tech }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    var discretionaryRatio: Double {
        guard let result = taxResult, result.netMonthly > 0 else { return 0 }
        return NSDecimalNumber(decimal: discretionaryExpensesMonthly / result.netMonthly * 100).doubleValue
    }

    var discretionaryRatioStatus: RatioStatus {
        switch discretionaryRatio {
        case ..<20: return .good
        case 20..<30: return .warning
        default: return .danger
        }
    }

    // MARK: - Cashflow Properties

    /// Whether transactions have been connected
    var hasTransactions: Bool {
        !transactions.isEmpty
    }

    /// Current period's cashflow summary
    var currentCashflow: CashflowSummary {
        let range = selectedCashflowPeriod.dateRange()
        let periodTransactions = transactions.filter {
            $0.date >= range.start && $0.date <= range.end
        }

        let income = periodTransactions
            .filter { $0.type == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }

        let expenses = periodTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }

        return CashflowSummary(
            period: selectedCashflowPeriod,
            startDate: range.start,
            endDate: range.end,
            totalIncome: income,
            totalExpenses: expenses,
            transactions: periodTransactions
        )
    }

    /// Projected cashflow based on expected income and budgeted expenses
    var projectedCashflow: CashflowSummary {
        // Use expected net income and budgeted expenses when no transactions
        let range = selectedCashflowPeriod.dateRange()
        let calendar = Calendar.current
        let daysInPeriod = calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 30

        // Scale monthly values to period
        let periodMultiplier: Decimal
        switch selectedCashflowPeriod {
        case .week: periodMultiplier = Decimal(7) / Decimal(30)
        case .month: periodMultiplier = 1
        case .quarter: periodMultiplier = 3
        case .year: periodMultiplier = 12
        }

        let projectedIncome = (taxResult?.netMonthly ?? 0) * periodMultiplier
        let monthlyExpenses = expenses.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
        let projectedExpenses = monthlyExpenses * periodMultiplier

        return CashflowSummary(
            period: selectedCashflowPeriod,
            startDate: range.start,
            endDate: range.end,
            totalIncome: projectedIncome,
            totalExpenses: projectedExpenses,
            transactions: []
        )
    }

    /// The active cashflow (actual if transactions exist, projected otherwise)
    var activeCashflow: CashflowSummary {
        hasTransactions ? currentCashflow : projectedCashflow
    }

    /// Cashflow status for visual indicator
    var cashflowStatus: CashflowStatus {
        let cashflow = activeCashflow
        let savingsRate = cashflow.savingsRate

        if savingsRate >= 20 {
            return .excellent
        } else if savingsRate >= 10 {
            return .good
        } else if savingsRate >= 0 {
            return .warning
        } else {
            return .danger
        }
    }

    /// Progress toward monthly savings goal (as percentage 0-100+)
    var cashflowProgress: Double {
        let cashflow = activeCashflow
        guard cashflow.totalIncome > 0 else { return 0 }

        // Target is 20% savings rate
        let targetSavings = cashflow.totalIncome * Decimal(0.20)
        guard targetSavings > 0 else { return 0 }

        let actualSavings = max(cashflow.netCashflow, 0)
        return min(NSDecimalNumber(decimal: actualSavings / targetSavings * 100).doubleValue, 150)
    }

    /// Days remaining in current period
    var daysRemainingInPeriod: Int {
        let range = selectedCashflowPeriod.dateRange()
        let calendar = Calendar.current
        return max(0, calendar.dateComponents([.day], from: Date(), to: range.end).day ?? 0)
    }

    /// Daily budget remaining
    var dailyBudgetRemaining: Decimal {
        let cashflow = activeCashflow
        let remaining = cashflow.netCashflow
        let daysLeft = max(1, daysRemainingInPeriod)
        return remaining / Decimal(daysLeft)
    }

    // MARK: - Initialization
    init(
        taxCore: TakeHomeCoreProtocol,
        profileRepository: FinancialProfileRepositoryProtocol,
        expenseRepository: ExpenseRepositoryProtocol
    ) {
        self.taxCore = taxCore
        self.profileRepository = profileRepository
        self.expenseRepository = expenseRepository
        super.init()
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        profileRepository.profilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
                Task { [weak self] in
                    await self?.recalculate()
                }
            }
            .store(in: &cancellables)

        expenseRepository.expensesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$expenses)
    }

    // MARK: - Review Prompt
    private static let dashboardLoadCountKey = "dashboardLoadCount"
    private static let reviewRequestThreshold = 5

    private func requestReviewIfEligible() {
        let count = UserDefaults.standard.integer(forKey: Self.dashboardLoadCountKey) + 1
        UserDefaults.standard.set(count, forKey: Self.dashboardLoadCountKey)

        guard count >= Self.reviewRequestThreshold, profile != nil else { return }

        // Only request once at the threshold (Apple rate-limits automatically per version)
        guard count == Self.reviewRequestThreshold else { return }

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    // MARK: - Actions
    func loadData() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let loadedProfile = try await self.profileRepository.load()
            let loadedExpenses = try await self.expenseRepository.loadAll()

            await MainActor.run {
                self.profile = loadedProfile
                self.expenses = loadedExpenses
            }

            await self.recalculate()
        }

        requestReviewIfEligible()
    }

    func recalculate() async {
        guard let profile = profile else {
            taxResult = nil
            partnerTaxResult = nil
            return
        }

        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let input = profile.toTaxInput()
            let result = try self.taxCore.computeTaxes(input: input)

            await MainActor.run {
                self.taxResult = result
            }
        }

        // Calculate partner taxes if applicable
        if let partner = profile.partnerProfile {
            await performTaskWithoutResult { [weak self] in
                guard let self = self else { return }
                let partnerInput = TaxCalculationInput(
                    grossIncome: partner.grossSalary,
                    filingStatus: partner.filingStatus,
                    state: partner.state
                )
                let result = try self.taxCore.computeTaxes(input: partnerInput)

                await MainActor.run {
                    self.partnerTaxResult = result
                }
            }
        } else {
            partnerTaxResult = nil
        }
    }

    func refresh() async {
        await loadData()
    }

    func toggleHouseholdMode() {
        guard canEnableHouseholdMode else { return }
        isHouseholdMode.toggle()
    }
}

// MARK: - Ratio Status
enum RatioStatus {
    case good
    case warning
    case danger

    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }

    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.circle.fill"
        }
    }
}

// MARK: - Cashflow Status
enum CashflowStatus {
    case excellent  // 20%+ savings rate
    case good       // 10-20% savings rate
    case warning    // 0-10% savings rate
    case danger     // Negative (spending more than earning)

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .danger: return .red
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "arrow.up.circle.fill"
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "arrow.down.circle.fill"
        }
    }

    var message: String {
        switch self {
        case .excellent: return "Excellent! You're saving 20%+"
        case .good: return "Good progress on savings"
        case .warning: return "Consider reducing expenses"
        case .danger: return "Spending exceeds income"
        }
    }

    var meterColor: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .danger: return .red
        }
    }
}

// MARK: - Timeframe Enum
enum Timeframe: String, CaseIterable, Identifiable {
    case annual
    case monthly
    case biWeekly
    case weekly
    case daily
    case hourly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .biWeekly: return "Bi-Weekly"
        case .weekly: return "Weekly"
        case .daily: return "Daily"
        case .hourly: return "Hourly"
        }
    }

    var shortName: String {
        switch self {
        case .annual: return "Year"
        case .monthly: return "Month"
        case .biWeekly: return "2 Wks"
        case .weekly: return "Week"
        case .daily: return "Day"
        case .hourly: return "Hour"
        }
    }
}
