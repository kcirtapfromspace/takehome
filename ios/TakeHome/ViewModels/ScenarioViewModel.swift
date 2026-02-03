import Foundation
import Combine

// MARK: - Scenario ViewModel
@MainActor
final class ScenarioViewModel: BaseViewModel {
    // MARK: - Dependencies
    let taxCore: TakeHomeCoreProtocol
    private let scenarioRepository: ScenarioRepositoryProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol

    // MARK: - Published State
    @Published private(set) var scenarios: [Scenario] = []
    @Published private(set) var baseProfile: FinancialProfile?
    @Published private(set) var baseTaxResult: TaxCalculationResult?
    @Published private(set) var activeComparison: ScenarioComparison?
    @Published var selectedScenario: Scenario?

    // Scenario Editor State
    @Published var editingScenario: Scenario?
    @Published var scenarioName: String = ""
    @Published var scenarioGrossSalary: Decimal = 0
    @Published var scenarioFilingStatus: FilingStatus = .single
    @Published var scenarioState: USState = .california
    @Published var scenarioTraditional401k: Decimal = 0
    @Published var scenarioRoth401k: Decimal = 0
    @Published var scenarioPreTax: Decimal = 0
    @Published var scenarioPostTax: Decimal = 0

    // MARK: - Computed Properties
    var hasBaseProfile: Bool {
        baseProfile != nil
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
        scenarioRepository: ScenarioRepositoryProtocol,
        profileRepository: FinancialProfileRepositoryProtocol
    ) {
        self.taxCore = taxCore
        self.scenarioRepository = scenarioRepository
        self.profileRepository = profileRepository
        super.init()
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        scenarioRepository.scenariosPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$scenarios)

        profileRepository.profilePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$baseProfile)
    }

    // MARK: - Actions
    func loadData() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let loadedScenarios = try await self.scenarioRepository.loadAll()
            let profile = try await self.profileRepository.load()

            await MainActor.run {
                self.scenarios = loadedScenarios
                self.baseProfile = profile
            }

            // Calculate base tax result
            if let profile = profile {
                let input = profile.toTaxInput()
                if let result = try? self.taxCore.computeTaxes(input: input) {
                    await MainActor.run {
                        self.baseTaxResult = result
                    }
                }
            }
        }
    }

    func createScenario(type: ScenarioType) {
        guard let base = baseProfile else { return }

        // Pre-fill from base profile
        scenarioName = type.displayName
        scenarioGrossSalary = base.income.grossSalary
        scenarioFilingStatus = base.location.filingStatus
        scenarioState = base.location.state
        scenarioTraditional401k = base.deductions.traditional401k
        scenarioRoth401k = base.deductions.roth401k
        scenarioPreTax = base.deductions.preTaxTotal
        scenarioPostTax = base.deductions.postTaxTotal

        // Apply type-specific defaults
        switch type {
        case .raise:
            scenarioGrossSalary = base.income.grossSalary * Decimal(1.1) // 10% raise
        case .stateMove:
            scenarioState = .texas // Default to no-income-tax state
        case .retirementContribution:
            scenarioTraditional401k = min(base.deductions.traditional401k + 5000, 22500)
        case .filingStatusChange:
            scenarioFilingStatus = .marriedFilingJointly
        case .custom:
            break
        }

        editingScenario = nil // New scenario, not editing
    }

    func saveScenario() async {
        let input = TaxCalculationInput(
            grossIncome: scenarioGrossSalary,
            filingStatus: scenarioFilingStatus,
            state: scenarioState,
            preTaxDeductions: scenarioPreTax,
            postTaxDeductions: scenarioPostTax,
            traditional401k: scenarioTraditional401k,
            roth401k: scenarioRoth401k
        )

        let scenario = Scenario(
            id: editingScenario?.id ?? UUID(),
            name: scenarioName,
            input: input
        )

        await performTaskWithoutResult { [weak self] in
            if self?.editingScenario != nil {
                try await self?.scenarioRepository.update(scenario)
            } else {
                try await self?.scenarioRepository.save(scenario)
            }
        }

        clearEditor()
    }

    func deleteScenario(_ id: UUID) async {
        await performTaskWithoutResult { [weak self] in
            try await self?.scenarioRepository.delete(id)
        }

        if selectedScenario?.id == id {
            selectedScenario = nil
            activeComparison = nil
        }
    }

    func compareScenario(_ scenario: Scenario) async {
        guard let base = baseProfile else { return }

        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let comparison = try self.taxCore.computeScenarioComparison(
                base: base.toTaxInput(),
                scenario: scenario.input
            )

            await MainActor.run {
                self.selectedScenario = scenario
                self.activeComparison = comparison
            }
        }
    }

    func editScenario(_ scenario: Scenario) {
        editingScenario = scenario
        scenarioName = scenario.name
        scenarioGrossSalary = scenario.input.grossIncome
        scenarioFilingStatus = scenario.input.filingStatus
        scenarioState = scenario.input.state
        scenarioTraditional401k = scenario.input.traditional401k
        scenarioRoth401k = scenario.input.roth401k
        scenarioPreTax = scenario.input.preTaxDeductions
        scenarioPostTax = scenario.input.postTaxDeductions
    }

    func clearEditor() {
        editingScenario = nil
        scenarioName = ""
        scenarioGrossSalary = 0
        scenarioFilingStatus = .single
        scenarioState = .california
        scenarioTraditional401k = 0
        scenarioRoth401k = 0
        scenarioPreTax = 0
        scenarioPostTax = 0
    }

    func clearComparison() {
        selectedScenario = nil
        activeComparison = nil
    }
}
