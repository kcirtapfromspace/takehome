import XCTest
import Combine
@testable import TakeHome

@MainActor
final class ExpenseViewModelTests: XCTestCase {
    private var viewModel: ExpenseViewModel!
    private var mockRepo: MockExpenseRepository!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockRepo = MockExpenseRepository()
        viewModel = ExpenseViewModel(expenseRepository: mockRepo)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepo = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests
    func testInitialState() {
        XCTAssertTrue(viewModel.expenses.isEmpty)
        XCTAssertNil(viewModel.selectedCategory)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.totalMonthlyExpenses, 0)
    }

    // MARK: - Add Expense Tests
    func testAddExpense_CallsRepository() async {
        let expense = Expense(name: "Rent", amount: 2000, category: .home)

        await viewModel.addExpense(expense)

        XCTAssertEqual(mockRepo.saveCallCount, 1)
    }

    func testAddExpense_UpdatesExpensesList() async {
        let expense = Expense(name: "Rent", amount: 2000, category: .home)
        mockRepo.addExpenses([expense])

        await viewModel.loadExpenses()

        XCTAssertEqual(viewModel.expenses.count, 1)
        XCTAssertEqual(viewModel.expenses.first?.name, "Rent")
    }

    // MARK: - Update Expense Tests
    func testUpdateExpense_CallsRepository() async {
        var expense = Expense(name: "Rent", amount: 2000, category: .home)
        mockRepo.addExpenses([expense])
        expense.amount = 2200

        await viewModel.updateExpense(expense)

        XCTAssertEqual(mockRepo.updateCallCount, 1)
    }

    // MARK: - Delete Expense Tests
    func testDeleteExpense_CallsRepository() async {
        let expense = Expense(name: "Rent", amount: 2000, category: .home)
        mockRepo.addExpenses([expense])

        await viewModel.deleteExpense(expense.id)

        XCTAssertEqual(mockRepo.deleteCallCount, 1)
    }

    // MARK: - Filtering Tests
    func testFilteredExpenses_WithNoFilter_ReturnsAll() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, category: .home),
            Expense(name: "Groceries", amount: 500, category: .necessities),
            Expense(name: "Netflix", amount: 15, category: .entertainment)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        XCTAssertEqual(viewModel.filteredExpenses.count, 3)
    }

    func testFilteredExpenses_WithCategoryFilter_ReturnsFiltered() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, category: .home),
            Expense(name: "Groceries", amount: 500, category: .necessities),
            Expense(name: "Netflix", amount: 15, category: .entertainment)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        viewModel.selectedCategory = .home

        XCTAssertEqual(viewModel.filteredExpenses.count, 1)
        XCTAssertEqual(viewModel.filteredExpenses.first?.name, "Rent")
    }

    func testFilteredExpenses_WithSearchText_ReturnsFiltered() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, category: .home),
            Expense(name: "Groceries", amount: 500, category: .necessities),
            Expense(name: "Grocery Delivery", amount: 50, category: .necessities)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        viewModel.searchText = "grocer"  // Matches both "Groceries" and "Grocery Delivery"

        XCTAssertEqual(viewModel.filteredExpenses.count, 2)
    }

    // MARK: - Total Calculations Tests
    func testTotalMonthlyExpenses_CalculatesCorrectly() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home),
            Expense(name: "Groceries", amount: 500, frequency: .monthly, category: .necessities),
            Expense(name: "Phone", amount: 50, frequency: .monthly, category: .tech)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        XCTAssertEqual(viewModel.totalMonthlyExpenses, 2550)
    }

    func testTotalMonthlyExpenses_WithDifferentFrequencies_ConvertsCorrectly() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home),
            Expense(name: "Weekly Groceries", amount: 100, frequency: .weekly, category: .necessities) // ~433.33/mo
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        let weeklyAsMonthly = Decimal(100) * Decimal(52) / 12
        let expected = Decimal(2000) + weeklyAsMonthly

        XCTAssertEqual(viewModel.totalMonthlyExpenses, expected)
    }

    func testTotalAnnualExpenses_CalculatesCorrectly() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home),
            Expense(name: "Insurance", amount: 1200, frequency: .annual, category: .finance)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        let expected = Decimal(2000 * 12) + Decimal(1200)

        XCTAssertEqual(viewModel.totalAnnualExpenses, expected)
    }

    // MARK: - Category Grouping Tests
    func testExpensesByCategory_GroupsCorrectly() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, category: .home),
            Expense(name: "Utilities", amount: 200, category: .home),
            Expense(name: "Groceries", amount: 500, category: .necessities)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        let byCategory = viewModel.expensesByCategory

        XCTAssertEqual(byCategory[.home]?.count, 2)
        XCTAssertEqual(byCategory[.necessities]?.count, 1)
    }

    func testCategoryTotals_CalculatesCorrectly() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home),
            Expense(name: "Utilities", amount: 200, frequency: .monthly, category: .home),
            Expense(name: "Groceries", amount: 500, frequency: .monthly, category: .necessities)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        let totals = viewModel.categoryTotals

        XCTAssertEqual(totals[.home], 2200)
        XCTAssertEqual(totals[.necessities], 500)
    }

    // MARK: - Shared Expenses Tests
    func testSharedExpenses_FiltersCorrectly() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, category: .home, isShared: true),
            Expense(name: "Groceries", amount: 500, category: .necessities, isShared: true),
            Expense(name: "Netflix", amount: 15, category: .entertainment, isShared: false)
        ]
        mockRepo.addExpenses(expenses)
        await viewModel.loadExpenses()

        XCTAssertEqual(viewModel.sharedExpenses.count, 2)
        XCTAssertEqual(viewModel.totalSharedMonthly, 2500)
    }
}
