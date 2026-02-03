import Foundation
import Combine

// MARK: - Household ViewModel
@MainActor
final class HouseholdViewModel: BaseViewModel {
    // MARK: - Dependencies
    private let taxCore: TakeHomeCoreProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol
    private let expenseRepository: ExpenseRepositoryProtocol

    // MARK: - Published State
    @Published private(set) var primaryProfile: FinancialProfile?
    @Published private(set) var primaryTaxResult: TaxCalculationResult?
    @Published var partnerName: String = "Partner"
    @Published var partnerGrossSalary: Decimal = 0
    @Published var partnerState: USState = .california
    @Published var partnerFilingStatus: FilingStatus = .single
    @Published private(set) var partnerTaxResult: TaxCalculationResult?
    @Published var splitMethod: SplitMethod = .proportional
    @Published private(set) var currentSplit: HouseholdSplit?
    @Published private(set) var sharedExpenses: [Expense] = []
    @Published var isHouseholdEnabled: Bool = false

    // MARK: - Computed Properties
    var primaryNetMonthly: Decimal {
        primaryTaxResult?.netMonthly ?? 0
    }

    var partnerNetMonthly: Decimal {
        partnerTaxResult?.netMonthly ?? 0
    }

    var totalHouseholdNetMonthly: Decimal {
        primaryNetMonthly + partnerNetMonthly
    }

    var primarySharePercentage: Double {
        guard totalHouseholdNetMonthly > 0 else { return 50 }
        return NSDecimalNumber(decimal: primaryNetMonthly / totalHouseholdNetMonthly * 100).doubleValue
    }

    var partnerSharePercentage: Double {
        guard totalHouseholdNetMonthly > 0 else { return 50 }
        return NSDecimalNumber(decimal: partnerNetMonthly / totalHouseholdNetMonthly * 100).doubleValue
    }

    var totalSharedExpensesMonthly: Decimal {
        sharedExpenses.reduce(0) { $0 + $1.monthlyAmount }
    }

    var primaryShareOfExpenses: Decimal {
        currentSplit?.primaryAmount ?? (totalSharedExpensesMonthly / 2)
    }

    var partnerShareOfExpenses: Decimal {
        currentSplit?.partnerAmount ?? (totalSharedExpensesMonthly / 2)
    }

    var primaryRemainingAfterShared: Decimal {
        primaryNetMonthly - primaryShareOfExpenses
    }

    var partnerRemainingAfterShared: Decimal {
        partnerNetMonthly - partnerShareOfExpenses
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
                self?.primaryProfile = profile
                Task { [weak self] in
                    await self?.calculatePrimaryTaxes()
                }
            }
            .store(in: &cancellables)

        expenseRepository.expensesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expenses in
                self?.sharedExpenses = expenses.filter { $0.isShared }
                Task { [weak self] in
                    await self?.recalculateSplit()
                }
            }
            .store(in: &cancellables)

        // Recalculate when partner details change
        $partnerGrossSalary
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.calculatePartnerTaxes()
                }
            }
            .store(in: &cancellables)

        $partnerState
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.calculatePartnerTaxes()
                }
            }
            .store(in: &cancellables)

        $splitMethod
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.recalculateSplit()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    func loadData() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let profile = try await self.profileRepository.load()
            let expenses = try await self.expenseRepository.loadAll()

            await MainActor.run {
                self.primaryProfile = profile
                self.sharedExpenses = expenses.filter { $0.isShared }
            }

            await self.calculatePrimaryTaxes()
            await self.calculatePartnerTaxes()
        }
    }

    func calculatePrimaryTaxes() async {
        guard let profile = primaryProfile else {
            primaryTaxResult = nil
            return
        }

        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let input = profile.toTaxInput()
            let result = try self.taxCore.computeTaxes(input: input)

            await MainActor.run {
                self.primaryTaxResult = result
            }

            await self.recalculateSplit()
        }
    }

    func calculatePartnerTaxes() async {
        guard partnerGrossSalary > 0 else {
            partnerTaxResult = nil
            await recalculateSplit()
            return
        }

        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let input = TaxCalculationInput(
                grossIncome: self.partnerGrossSalary,
                filingStatus: self.partnerFilingStatus,
                state: self.partnerState
            )
            let result = try self.taxCore.computeTaxes(input: input)

            await MainActor.run {
                self.partnerTaxResult = result
            }

            await self.recalculateSplit()
        }
    }

    func recalculateSplit() async {
        guard primaryNetMonthly > 0 || partnerNetMonthly > 0 else {
            currentSplit = nil
            return
        }

        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let split = try self.taxCore.computeHouseholdSplit(
                primaryNet: self.primaryNetMonthly,
                partnerNet: self.partnerNetMonthly,
                sharedExpense: self.totalSharedExpensesMonthly,
                method: self.splitMethod
            )

            await MainActor.run {
                self.currentSplit = split
            }
        }
    }

    func toggleHouseholdMode() {
        isHouseholdEnabled.toggle()
        if isHouseholdEnabled {
            Task {
                await loadData()
            }
        }
    }

    func markExpenseAsShared(_ expenseId: UUID, isShared: Bool) async {
        var expense: Expense?

        // First check in local shared expenses
        expense = sharedExpenses.first(where: { $0.id == expenseId })

        // If not found, load from repository
        if expense == nil {
            let allExpenses = try? await expenseRepository.loadAll()
            expense = allExpenses?.first(where: { $0.id == expenseId })
        }

        guard var foundExpense = expense else { return }

        foundExpense.isShared = isShared
        await performTaskWithoutResult { [weak self] in
            try await self?.expenseRepository.update(foundExpense)
        }
    }
}
