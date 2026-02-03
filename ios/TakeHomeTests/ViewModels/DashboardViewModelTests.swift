import XCTest
import Combine
@testable import TakeHome

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private var viewModel: DashboardViewModel!
    private var mockTaxCore: MockTakeHomeCore!
    private var mockProfileRepo: MockFinancialProfileRepository!
    private var mockExpenseRepo: MockExpenseRepository!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockTaxCore = MockTakeHomeCore()
        mockProfileRepo = MockFinancialProfileRepository()
        mockExpenseRepo = MockExpenseRepository()
        viewModel = DashboardViewModel(
            taxCore: mockTaxCore,
            profileRepository: mockProfileRepo,
            expenseRepository: mockExpenseRepo
        )
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        viewModel = nil
        mockTaxCore = nil
        mockProfileRepo = nil
        mockExpenseRepo = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests
    func testInitialState() {
        XCTAssertNil(viewModel.profile)
        XCTAssertNil(viewModel.taxResult)
        XCTAssertTrue(viewModel.expenses.isEmpty)
        XCTAssertEqual(viewModel.selectedTimeframe, .monthly)
        XCTAssertFalse(viewModel.hasProfile)
    }

    // MARK: - HasProfile Tests
    func testHasProfile_WithNoProfile_ReturnsFalse() {
        XCTAssertFalse(viewModel.hasProfile)
    }

    func testHasProfile_WithProfile_ReturnsTrue() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 100000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)
        await viewModel.loadData()

        XCTAssertTrue(viewModel.hasProfile)
    }

    // MARK: - Net Income Tests
    func testNetIncome_WithNoResult_ReturnsZero() {
        XCTAssertEqual(viewModel.netIncome, 0)
    }

    func testNetIncome_Monthly_ReturnsMonthlyValue() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 120000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)
        await viewModel.loadData()

        viewModel.selectedTimeframe = .monthly
        // Mock returns 10000 monthly based on default implementation
        XCTAssertGreaterThan(viewModel.netIncome, 0)
    }

    func testNetIncome_Timeframes_ChangeWithSelection() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 120000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)
        await viewModel.loadData()

        viewModel.selectedTimeframe = .annual
        let annual = viewModel.netIncome

        viewModel.selectedTimeframe = .monthly
        let monthly = viewModel.netIncome

        // Annual should be greater than monthly
        XCTAssertGreaterThan(annual, monthly)
    }

    // MARK: - Total Expenses Tests
    func testTotalExpenses_WithNoExpenses_ReturnsZero() {
        XCTAssertEqual(viewModel.totalExpenses, 0)
    }

    func testTotalExpenses_Monthly_SumsMonthlyAmounts() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home),
            Expense(name: "Utilities", amount: 200, frequency: .monthly, category: .home)
        ]
        mockExpenseRepo.addExpenses(expenses)
        await viewModel.loadData()

        viewModel.selectedTimeframe = .monthly
        XCTAssertEqual(viewModel.totalExpenses, 2200)
    }

    func testTotalExpenses_Annual_MultipliesBy12() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home)
        ]
        mockExpenseRepo.addExpenses(expenses)
        await viewModel.loadData()

        viewModel.selectedTimeframe = .annual
        XCTAssertEqual(viewModel.totalExpenses, 24000)
    }

    // MARK: - Remaining After Expenses Tests
    func testRemainingAfterExpenses_CalculatesCorrectly() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 120000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)

        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home)
        ]
        mockExpenseRepo.addExpenses(expenses)

        await viewModel.loadData()

        viewModel.selectedTimeframe = .monthly
        let remaining = viewModel.remainingAfterExpenses

        // Remaining should be net income minus expenses
        XCTAssertEqual(remaining, viewModel.netIncome - viewModel.totalExpenses)
    }

    // MARK: - Percentage Calculations Tests
    func testExpensesPercentage_WithNoIncome_ReturnsZero() {
        XCTAssertEqual(viewModel.expensesPercentage, 0)
    }

    func testExpensesPercentage_CalculatesCorrectly() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 120000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)

        let expenses = [
            Expense(name: "Rent", amount: 1000, frequency: .monthly, category: .home)
        ]
        mockExpenseRepo.addExpenses(expenses)

        await viewModel.loadData()

        viewModel.selectedTimeframe = .monthly
        XCTAssertGreaterThan(viewModel.expensesPercentage, 0)
        XCTAssertLessThanOrEqual(viewModel.expensesPercentage, 100)
    }

    func testRemainingPercentage_CalculatesCorrectly() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 120000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)

        await viewModel.loadData()

        // With no expenses, remaining should be 100%
        XCTAssertEqual(viewModel.remainingPercentage, 100, accuracy: 0.01)
    }

    // MARK: - Top Expense Categories Tests
    func testTopExpenseCategories_ReturnsTopFive() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home),
            Expense(name: "Groceries", amount: 500, frequency: .monthly, category: .necessities),
            Expense(name: "Netflix", amount: 15, frequency: .monthly, category: .entertainment),
            Expense(name: "Car Payment", amount: 400, frequency: .monthly, category: .vehicle),
            Expense(name: "Gym", amount: 50, frequency: .monthly, category: .necessities),
            Expense(name: "Phone", amount: 80, frequency: .monthly, category: .tech),
            Expense(name: "Internet", amount: 60, frequency: .monthly, category: .tech)
        ]
        mockExpenseRepo.addExpenses(expenses)
        await viewModel.loadData()

        let topCategories = viewModel.topExpenseCategories
        XCTAssertLessThanOrEqual(topCategories.count, 5)
    }

    func testTopExpenseCategories_SortedByAmount() async {
        let expenses = [
            Expense(name: "Rent", amount: 2000, frequency: .monthly, category: .home),
            Expense(name: "Groceries", amount: 500, frequency: .monthly, category: .necessities),
            Expense(name: "Netflix", amount: 15, frequency: .monthly, category: .entertainment)
        ]
        mockExpenseRepo.addExpenses(expenses)
        await viewModel.loadData()

        let topCategories = viewModel.topExpenseCategories

        // First should be home (highest amount)
        XCTAssertEqual(topCategories.first?.0, .home)
        XCTAssertEqual(topCategories.first?.1, 2000)
    }

    // MARK: - Load Data Tests
    func testLoadData_LoadsProfileAndExpenses() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 100000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)

        let expenses = [
            Expense(name: "Rent", amount: 2000, category: .home)
        ]
        mockExpenseRepo.addExpenses(expenses)

        await viewModel.loadData()

        XCTAssertNotNil(viewModel.profile)
        XCTAssertEqual(viewModel.expenses.count, 1)
    }

    // MARK: - Recalculate Tests
    func testRecalculate_WithProfile_CallsTaxCore() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 100000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)
        await viewModel.loadData()

        XCTAssertGreaterThan(mockTaxCore.calculateTaxesCallCount, 0)
        XCTAssertNotNil(viewModel.taxResult)
    }

    func testRecalculate_WithNoProfile_SetsTaxResultToNil() async {
        await viewModel.recalculate()
        XCTAssertNil(viewModel.taxResult)
    }

    // MARK: - Refresh Tests
    func testRefresh_ReloadsData() async {
        let profile = FinancialProfile(
            name: "Test",
            income: IncomeProfile(grossSalary: 100000, payFrequency: .biWeekly),
            location: LocationProfile(state: .california, filingStatus: .single),
            deductions: DeductionProfile()
        )
        mockProfileRepo.setProfile(profile)

        await viewModel.refresh()

        XCTAssertNotNil(viewModel.profile)
    }

    // MARK: - Timeframe Enum Tests
    func testTimeframe_DisplayNames() {
        XCTAssertEqual(Timeframe.annual.displayName, "Annual")
        XCTAssertEqual(Timeframe.monthly.displayName, "Monthly")
        XCTAssertEqual(Timeframe.biWeekly.displayName, "Bi-Weekly")
        XCTAssertEqual(Timeframe.weekly.displayName, "Weekly")
        XCTAssertEqual(Timeframe.daily.displayName, "Daily")
        XCTAssertEqual(Timeframe.hourly.displayName, "Hourly")
    }

    func testTimeframe_ShortNames() {
        XCTAssertEqual(Timeframe.annual.shortName, "Year")
        XCTAssertEqual(Timeframe.monthly.shortName, "Month")
        XCTAssertEqual(Timeframe.biWeekly.shortName, "2 Wks")
    }
}
