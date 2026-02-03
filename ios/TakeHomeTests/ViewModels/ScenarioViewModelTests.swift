import XCTest
import Combine
@testable import TakeHome

@MainActor
final class ScenarioViewModelTests: XCTestCase {
    private var viewModel: ScenarioViewModel!
    private var mockCore: MockTakeHomeCore!
    private var mockScenarioRepo: MockScenarioRepository!
    private var mockProfileRepo: MockFinancialProfileRepository!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockCore = MockTakeHomeCore()
        mockScenarioRepo = MockScenarioRepository()
        mockProfileRepo = MockFinancialProfileRepository()
        viewModel = ScenarioViewModel(
            taxCore: mockCore,
            scenarioRepository: mockScenarioRepo,
            profileRepository: mockProfileRepo
        )
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        viewModel = nil
        mockCore = nil
        mockScenarioRepo = nil
        mockProfileRepo = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests
    func testInitialState() {
        XCTAssertTrue(viewModel.scenarios.isEmpty)
        XCTAssertNil(viewModel.baseProfile)
        XCTAssertNil(viewModel.activeComparison)
        XCTAssertNil(viewModel.selectedScenario)
        XCTAssertFalse(viewModel.hasBaseProfile)
    }

    // MARK: - Profile Tests
    func testHasBaseProfile_WithProfile_ReturnsTrue() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000)
        )
        mockProfileRepo.setProfile(profile)

        await viewModel.loadData()

        XCTAssertTrue(viewModel.hasBaseProfile)
    }

    // MARK: - Create Scenario Tests
    func testCreateScenario_RaiseType_PreFillsWithIncrease() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            location: LocationProfile(state: .california, filingStatus: .single)
        )
        mockProfileRepo.setProfile(profile)
        await viewModel.loadData()

        viewModel.createScenario(type: .raise)

        XCTAssertEqual(viewModel.scenarioName, "Salary Raise")
        XCTAssertEqual(viewModel.scenarioGrossSalary, 110000) // 10% raise
        XCTAssertEqual(viewModel.scenarioState, .california)
    }

    func testCreateScenario_StateMoveType_PreFillsWithTexas() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            location: LocationProfile(state: .california, filingStatus: .single)
        )
        mockProfileRepo.setProfile(profile)
        await viewModel.loadData()

        viewModel.createScenario(type: .stateMove)

        XCTAssertEqual(viewModel.scenarioState, .texas)
    }

    func testCreateScenario_RetirementType_IncreasesContribution() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            deductions: DeductionProfile(traditional401k: 10000)
        )
        mockProfileRepo.setProfile(profile)
        await viewModel.loadData()

        viewModel.createScenario(type: .retirementContribution)

        XCTAssertEqual(viewModel.scenarioTraditional401k, 15000) // +5000
    }

    // MARK: - Save Scenario Tests
    func testSaveScenario_NewScenario_CallsSave() async {
        viewModel.scenarioName = "Test Scenario"
        viewModel.scenarioGrossSalary = 120000
        viewModel.scenarioState = .newYork
        viewModel.scenarioFilingStatus = .single

        await viewModel.saveScenario()

        XCTAssertEqual(mockScenarioRepo.saveCallCount, 1)
    }

    func testSaveScenario_EditingScenario_CallsUpdate() async {
        let scenario = Scenario(
            name: "Original",
            input: TaxCalculationInput(grossIncome: 100000)
        )
        mockScenarioRepo.addScenarios([scenario])
        await viewModel.loadData()

        viewModel.editScenario(scenario)
        viewModel.scenarioName = "Updated"
        await viewModel.saveScenario()

        XCTAssertEqual(mockScenarioRepo.updateCallCount, 1)
    }

    func testSaveScenario_ClearsEditor() async {
        viewModel.scenarioName = "Test"
        viewModel.scenarioGrossSalary = 100000

        await viewModel.saveScenario()

        XCTAssertEqual(viewModel.scenarioName, "")
        XCTAssertEqual(viewModel.scenarioGrossSalary, 0)
    }

    // MARK: - Delete Scenario Tests
    func testDeleteScenario_CallsRepository() async {
        let scenario = Scenario(
            name: "Test",
            input: TaxCalculationInput(grossIncome: 100000)
        )
        mockScenarioRepo.addScenarios([scenario])

        await viewModel.deleteScenario(scenario.id)

        XCTAssertEqual(mockScenarioRepo.deleteCallCount, 1)
    }

    func testDeleteScenario_ClearsSelectionIfSelected() async {
        let scenario = Scenario(
            name: "Test",
            input: TaxCalculationInput(grossIncome: 100000)
        )
        mockScenarioRepo.addScenarios([scenario])
        await viewModel.loadData()

        // Manually set selected scenario
        viewModel.selectedScenario = scenario

        await viewModel.deleteScenario(scenario.id)

        XCTAssertNil(viewModel.selectedScenario)
        XCTAssertNil(viewModel.activeComparison)
    }

    // MARK: - Compare Scenario Tests
    func testCompareScenario_CallsTaxCore() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            location: LocationProfile(state: .california, filingStatus: .single)
        )
        mockProfileRepo.setProfile(profile)

        let scenario = Scenario(
            name: "Raise",
            input: TaxCalculationInput(grossIncome: 120000, state: .california)
        )
        mockScenarioRepo.addScenarios([scenario])
        await viewModel.loadData()

        await viewModel.compareScenario(scenario)

        XCTAssertEqual(mockCore.compareScenariosCallCount, 1)
        XCTAssertNotNil(viewModel.activeComparison)
        XCTAssertEqual(viewModel.selectedScenario?.id, scenario.id)
    }

    // MARK: - Edit Scenario Tests
    func testEditScenario_LoadsValues() {
        let scenario = Scenario(
            name: "Test Scenario",
            input: TaxCalculationInput(
                grossIncome: 120000,
                filingStatus: .marriedFilingJointly,
                state: .texas,
                traditional401k: 15000
            )
        )

        viewModel.editScenario(scenario)

        XCTAssertEqual(viewModel.scenarioName, "Test Scenario")
        XCTAssertEqual(viewModel.scenarioGrossSalary, 120000)
        XCTAssertEqual(viewModel.scenarioFilingStatus, .marriedFilingJointly)
        XCTAssertEqual(viewModel.scenarioState, .texas)
        XCTAssertEqual(viewModel.scenarioTraditional401k, 15000)
        XCTAssertEqual(viewModel.editingScenario?.id, scenario.id)
    }

    // MARK: - Clear Tests
    func testClearEditor_ResetsAllFields() {
        viewModel.scenarioName = "Test"
        viewModel.scenarioGrossSalary = 100000
        viewModel.scenarioState = .texas
        viewModel.editingScenario = Scenario(name: "Edit", input: TaxCalculationInput())

        viewModel.clearEditor()

        XCTAssertEqual(viewModel.scenarioName, "")
        XCTAssertEqual(viewModel.scenarioGrossSalary, 0)
        XCTAssertEqual(viewModel.scenarioState, .california)
        XCTAssertNil(viewModel.editingScenario)
    }

    func testClearComparison_ClearsSelection() {
        viewModel.selectedScenario = Scenario(name: "Test", input: TaxCalculationInput())

        viewModel.clearComparison()

        XCTAssertNil(viewModel.selectedScenario)
        XCTAssertNil(viewModel.activeComparison)
    }
}
