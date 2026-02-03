import Foundation
import Combine

// MARK: - Expense ViewModel
@MainActor
final class ExpenseViewModel: BaseViewModel {
    // MARK: - Dependencies
    private let expenseRepository: ExpenseRepositoryProtocol

    // MARK: - Published State
    @Published private(set) var expenses: [Expense] = []
    @Published var selectedCategory: ExpenseCategory?
    @Published var searchText: String = ""

    // MARK: - Computed Properties
    var filteredExpenses: [Expense] {
        var result = expenses

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var totalMonthlyExpenses: Decimal {
        expenses.reduce(0) { $0 + $1.monthlyAmount }
    }

    var totalAnnualExpenses: Decimal {
        expenses.reduce(0) { $0 + $1.annualAmount }
    }

    var expensesByCategory: [ExpenseCategory: [Expense]] {
        Dictionary(grouping: expenses, by: { $0.category })
    }

    var categoryTotals: [ExpenseCategory: Decimal] {
        var totals: [ExpenseCategory: Decimal] = [:]
        for category in ExpenseCategory.allCases {
            totals[category] = expensesByCategory[category]?.reduce(0) { $0 + $1.monthlyAmount } ?? 0
        }
        return totals
    }

    var sharedExpenses: [Expense] {
        expenses.filter { $0.isShared }
    }

    var totalSharedMonthly: Decimal {
        sharedExpenses.reduce(0) { $0 + $1.monthlyAmount }
    }

    // MARK: - Initialization
    init(expenseRepository: ExpenseRepositoryProtocol) {
        self.expenseRepository = expenseRepository
        super.init()
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        expenseRepository.expensesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$expenses)
    }

    // MARK: - Actions
    func loadExpenses() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let loadedExpenses = try await self.expenseRepository.loadAll()
            await MainActor.run {
                self.expenses = loadedExpenses
            }
        }
    }

    func addExpense(_ expense: Expense) async {
        await performTaskWithoutResult { [weak self] in
            try await self?.expenseRepository.save(expense)
        }
    }

    func updateExpense(_ expense: Expense) async {
        await performTaskWithoutResult { [weak self] in
            try await self?.expenseRepository.update(expense)
        }
    }

    func deleteExpense(_ id: UUID) async {
        await performTaskWithoutResult { [weak self] in
            try await self?.expenseRepository.delete(id)
        }
    }

    func deleteExpenses(at offsets: IndexSet) async {
        let expensesToDelete = offsets.map { filteredExpenses[$0] }
        for expense in expensesToDelete {
            await deleteExpense(expense.id)
        }
    }

    // MARK: - Quick Add Templates
    func addTemplateExpenses(for category: ExpenseCategory) async {
        guard let templates = ExpenseCategory.defaultExpenses[category] else { return }

        for name in templates {
            let expense = Expense(
                name: name,
                amount: 0,
                frequency: .monthly,
                category: category
            )
            await addExpense(expense)
        }
    }
}
