# TakeHome Technical Architecture: Architecture Patterns

## Overview

This document defines the core architectural patterns used in TakeHome iOS app. The architecture prioritizes testability, separation of concerns, and offline-first operation.

---

## 1. MVVM with Combine

### Pattern Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    View     │────▶│  ViewModel  │────▶│    Model    │
│  (SwiftUI)  │◀────│  (ObservableObject)│◀────│   (Data)    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ Repository  │
                    └─────────────┘
```

### Base ViewModel Protocol

```swift
import Combine
import Foundation

/// Base protocol for all ViewModels
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Action

    var state: State { get }
    func send(_ action: Action)
}

/// Base class providing common ViewModel functionality
class BaseViewModel<State, Action>: ObservableObject {
    @Published private(set) var state: State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: AppError?

    var cancellables = Set<AnyCancellable>()

    init(initialState: State) {
        self.state = state
    }

    func send(_ action: Action) {
        fatalError("Subclasses must implement send(_:)")
    }

    func updateState(_ transform: (inout State) -> Void) {
        var newState = state
        transform(&newState)
        state = newState
    }
}
```

### Example: Income ViewModel

```swift
import Combine
import Foundation

// MARK: - State
struct IncomeViewState: Equatable {
    var grossSalary: Decimal = 0
    var payFrequency: PayFrequency = .biWeekly
    var filingStatus: FilingStatus = .single
    var state: USState = .california

    // Calculated values
    var calculatedIncome: CalculatedIncome?
    var taxBreakdown: TaxBreakdown?
}

// MARK: - Actions
enum IncomeViewAction {
    case updateGrossSalary(Decimal)
    case updatePayFrequency(PayFrequency)
    case updateFilingStatus(FilingStatus)
    case updateState(USState)
    case recalculate
    case save
}

// MARK: - ViewModel
final class IncomeViewModel: BaseViewModel<IncomeViewState, IncomeViewAction> {

    private let calculationEngine: TaxCalculationEngineProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol

    init(
        calculationEngine: TaxCalculationEngineProtocol,
        profileRepository: FinancialProfileRepositoryProtocol
    ) {
        self.calculationEngine = calculationEngine
        self.profileRepository = profileRepository
        super.init(initialState: IncomeViewState())

        setupBindings()
    }

    override func send(_ action: IncomeViewAction) {
        switch action {
        case .updateGrossSalary(let salary):
            updateState { $0.grossSalary = salary }
            send(.recalculate)

        case .updatePayFrequency(let frequency):
            updateState { $0.payFrequency = frequency }
            send(.recalculate)

        case .updateFilingStatus(let status):
            updateState { $0.filingStatus = status }
            send(.recalculate)

        case .updateState(let usState):
            updateState { $0.state = usState }
            send(.recalculate)

        case .recalculate:
            recalculateIncome()

        case .save:
            saveProfile()
        }
    }

    private func setupBindings() {
        // Auto-recalculate when any input changes
        $state
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.send(.recalculate)
            }
            .store(in: &cancellables)
    }

    private func recalculateIncome() {
        let input = TaxCalculationInput(
            grossIncome: state.grossSalary,
            filingStatus: state.filingStatus,
            state: state.state,
            payFrequency: state.payFrequency,
            preTaxDeductions: [],
            postTaxDeductions: []
        )

        let result = calculationEngine.calculate(input: input)

        updateState { state in
            state.calculatedIncome = result.income
            state.taxBreakdown = result.taxBreakdown
        }
    }

    private func saveProfile() {
        isLoading = true

        profileRepository.save(state.toProfile())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = .repositoryError(error)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}
```

### SwiftUI View Binding

```swift
import SwiftUI

struct IncomeView: View {
    @StateObject private var viewModel: IncomeViewModel

    init(viewModel: IncomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                salaryInputSection
                taxBreakdownSection
                incomeTimeframesSection
            }
            .padding()
        }
        .navigationTitle("Income")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert(item: $viewModel.error) { error in
            Alert(title: Text("Error"), message: Text(error.localizedDescription))
        }
    }

    private var salaryInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gross Annual Salary")
                .font(.headline)

            CurrencyTextField(
                value: Binding(
                    get: { viewModel.state.grossSalary },
                    set: { viewModel.send(.updateGrossSalary($0)) }
                )
            )

            Picker("Pay Frequency", selection: Binding(
                get: { viewModel.state.payFrequency },
                set: { viewModel.send(.updatePayFrequency($0)) }
            )) {
                ForEach(PayFrequency.allCases) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }
        }
    }

    // Additional sections...
}
```

---

## 2. Repository Pattern

### Purpose

Abstracts data access, providing a clean API for ViewModels while handling:
- Core Data persistence
- CloudKit synchronization
- Caching strategies
- Offline-first operation

### Repository Protocol

```swift
import Combine
import Foundation

/// Generic repository protocol for CRUD operations
protocol RepositoryProtocol {
    associatedtype Entity
    associatedtype ID: Hashable

    func get(id: ID) -> AnyPublisher<Entity?, RepositoryError>
    func getAll() -> AnyPublisher<[Entity], RepositoryError>
    func save(_ entity: Entity) -> AnyPublisher<Entity, RepositoryError>
    func delete(id: ID) -> AnyPublisher<Void, RepositoryError>
    func observe(id: ID) -> AnyPublisher<Entity?, RepositoryError>
    func observeAll() -> AnyPublisher<[Entity], RepositoryError>
}

/// Repository errors
enum RepositoryError: Error, Equatable {
    case notFound
    case saveFailed(String)
    case deleteFailed(String)
    case syncFailed(String)
    case migrationFailed(String)
    case corruptedData
}
```

### Financial Profile Repository

```swift
import Combine
import CoreData

protocol FinancialProfileRepositoryProtocol: RepositoryProtocol
    where Entity == FinancialProfile, ID == UUID {

    func getCurrentProfile() -> AnyPublisher<FinancialProfile?, RepositoryError>
    func setCurrentProfile(_ profile: FinancialProfile) -> AnyPublisher<Void, RepositoryError>
}

final class FinancialProfileRepository: FinancialProfileRepositoryProtocol {

    private let coreDataStack: CoreDataStackProtocol
    private let cloudKitSync: CloudKitSyncProtocol
    private let userDefaults: UserDefaults

    private let currentProfileSubject = CurrentValueSubject<FinancialProfile?, RepositoryError>(nil)

    init(
        coreDataStack: CoreDataStackProtocol,
        cloudKitSync: CloudKitSyncProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.coreDataStack = coreDataStack
        self.cloudKitSync = cloudKitSync
        self.userDefaults = userDefaults

        loadCurrentProfile()
    }

    func get(id: UUID) -> AnyPublisher<FinancialProfile?, RepositoryError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.notFound))
                return
            }

            let context = self.coreDataStack.viewContext
            let request = FinancialProfileEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                let results = try context.fetch(request)
                let profile = results.first.map { FinancialProfile(entity: $0) }
                promise(.success(profile))
            } catch {
                promise(.failure(.notFound))
            }
        }
        .eraseToAnyPublisher()
    }

    func getAll() -> AnyPublisher<[FinancialProfile], RepositoryError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }

            let context = self.coreDataStack.viewContext
            let request = FinancialProfileEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

            do {
                let results = try context.fetch(request)
                let profiles = results.map { FinancialProfile(entity: $0) }
                promise(.success(profiles))
            } catch {
                promise(.failure(.corruptedData))
            }
        }
        .eraseToAnyPublisher()
    }

    func save(_ entity: FinancialProfile) -> AnyPublisher<FinancialProfile, RepositoryError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.saveFailed("Repository deallocated")))
                return
            }

            let context = self.coreDataStack.backgroundContext
            context.perform {
                do {
                    // Find existing or create new
                    let request = FinancialProfileEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", entity.id as CVarArg)

                    let existing = try context.fetch(request).first
                    let profileEntity = existing ?? FinancialProfileEntity(context: context)

                    // Update entity
                    entity.populate(entity: profileEntity)
                    profileEntity.updatedAt = Date()

                    try context.save()

                    // Trigger CloudKit sync
                    self.cloudKitSync.sync(entity: profileEntity)

                    promise(.success(entity))
                } catch {
                    promise(.failure(.saveFailed(error.localizedDescription)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func delete(id: UUID) -> AnyPublisher<Void, RepositoryError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.deleteFailed("Repository deallocated")))
                return
            }

            let context = self.coreDataStack.backgroundContext
            context.perform {
                let request = FinancialProfileEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

                do {
                    if let entity = try context.fetch(request).first {
                        context.delete(entity)
                        try context.save()
                        self.cloudKitSync.delete(recordID: id.uuidString)
                    }
                    promise(.success(()))
                } catch {
                    promise(.failure(.deleteFailed(error.localizedDescription)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func observe(id: UUID) -> AnyPublisher<FinancialProfile?, RepositoryError> {
        // Use NSFetchedResultsController under the hood
        return coreDataStack.observe(
            entityType: FinancialProfileEntity.self,
            predicate: NSPredicate(format: "id == %@", id as CVarArg)
        )
        .map { entities in entities.first.map { FinancialProfile(entity: $0) } }
        .mapError { _ in RepositoryError.corruptedData }
        .eraseToAnyPublisher()
    }

    func observeAll() -> AnyPublisher<[FinancialProfile], RepositoryError> {
        return coreDataStack.observe(entityType: FinancialProfileEntity.self)
            .map { entities in entities.map { FinancialProfile(entity: $0) } }
            .mapError { _ in RepositoryError.corruptedData }
            .eraseToAnyPublisher()
    }

    func getCurrentProfile() -> AnyPublisher<FinancialProfile?, RepositoryError> {
        return currentProfileSubject.eraseToAnyPublisher()
    }

    func setCurrentProfile(_ profile: FinancialProfile) -> AnyPublisher<Void, RepositoryError> {
        userDefaults.set(profile.id.uuidString, forKey: "currentProfileID")
        currentProfileSubject.send(profile)
        return Just(()).setFailureType(to: RepositoryError.self).eraseToAnyPublisher()
    }

    private func loadCurrentProfile() {
        guard let idString = userDefaults.string(forKey: "currentProfileID"),
              let id = UUID(uuidString: idString) else {
            return
        }

        get(id: id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] profile in
                    self?.currentProfileSubject.send(profile)
                }
            )
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}
```

---

## 3. Calculation Engine

### Design Principles

1. **Pure Functions**: No side effects, deterministic outputs
2. **Protocol-Based**: Easy to mock for testing
3. **Composable**: Small, focused calculators combined into larger ones
4. **Decimal Precision**: All financial calculations use `Decimal`

### Engine Protocol

```swift
import Foundation

/// Input for tax calculations
struct TaxCalculationInput {
    let grossIncome: Decimal
    let filingStatus: FilingStatus
    let state: USState
    let payFrequency: PayFrequency
    let preTaxDeductions: [Deduction]
    let postTaxDeductions: [Deduction]
    let retirementContributions: RetirementContributions?
}

/// Complete calculation result
struct TaxCalculationResult {
    let income: CalculatedIncome
    let taxBreakdown: TaxBreakdown
    let deductionsSummary: DeductionsSummary
    let effectiveRates: EffectiveRates
}

/// Main calculation engine protocol
protocol TaxCalculationEngineProtocol {
    func calculate(input: TaxCalculationInput) -> TaxCalculationResult
    func calculateScenario(base: TaxCalculationInput, changes: ScenarioChanges) -> ScenarioComparison
}

/// Individual calculator protocols
protocol FederalTaxCalculatorProtocol {
    func calculate(taxableIncome: Decimal, filingStatus: FilingStatus, year: Int) -> FederalTaxResult
}

protocol StateTaxCalculatorProtocol {
    func calculate(taxableIncome: Decimal, state: USState, filingStatus: FilingStatus, year: Int) -> StateTaxResult
}

protocol FICACalculatorProtocol {
    func calculate(grossIncome: Decimal, year: Int) -> FICAResult
}

protocol TimeframeCalculatorProtocol {
    func convert(annual: Decimal) -> TimeframeIncome
}
```

### Main Calculation Engine

```swift
import Foundation

final class TaxCalculationEngine: TaxCalculationEngineProtocol {

    private let federalCalculator: FederalTaxCalculatorProtocol
    private let stateCalculator: StateTaxCalculatorProtocol
    private let ficaCalculator: FICACalculatorProtocol
    private let timeframeCalculator: TimeframeCalculatorProtocol
    private let taxDataProvider: TaxDataProviderProtocol

    init(
        federalCalculator: FederalTaxCalculatorProtocol,
        stateCalculator: StateTaxCalculatorProtocol,
        ficaCalculator: FICACalculatorProtocol,
        timeframeCalculator: TimeframeCalculatorProtocol,
        taxDataProvider: TaxDataProviderProtocol
    ) {
        self.federalCalculator = federalCalculator
        self.stateCalculator = stateCalculator
        self.ficaCalculator = ficaCalculator
        self.timeframeCalculator = timeframeCalculator
        self.taxDataProvider = taxDataProvider
    }

    func calculate(input: TaxCalculationInput) -> TaxCalculationResult {
        let year = Calendar.current.component(.year, from: Date())

        // Step 1: Calculate pre-tax deductions
        let preTaxTotal = input.preTaxDeductions.reduce(Decimal.zero) { $0 + $1.annualAmount }
        let retirementPreTax = input.retirementContributions?.traditional401k ?? 0
        let totalPreTax = preTaxTotal + retirementPreTax

        // Step 2: Calculate taxable income
        let federalTaxableIncome = input.grossIncome - totalPreTax

        // Step 3: Calculate federal tax
        let federalResult = federalCalculator.calculate(
            taxableIncome: federalTaxableIncome,
            filingStatus: input.filingStatus,
            year: year
        )

        // Step 4: Calculate state tax
        let stateResult = stateCalculator.calculate(
            taxableIncome: federalTaxableIncome,
            state: input.state,
            filingStatus: input.filingStatus,
            year: year
        )

        // Step 5: Calculate FICA (on gross, not reduced by 401k)
        let ficaResult = ficaCalculator.calculate(grossIncome: input.grossIncome, year: year)

        // Step 6: Calculate post-tax deductions
        let postTaxTotal = input.postTaxDeductions.reduce(Decimal.zero) { $0 + $1.annualAmount }
        let retirementPostTax = input.retirementContributions?.roth401k ?? 0
        let totalPostTax = postTaxTotal + retirementPostTax

        // Step 7: Calculate net income
        let totalTaxes = federalResult.tax + stateResult.totalTax + ficaResult.totalFICA
        let totalDeductions = totalPreTax + totalPostTax
        let netIncome = input.grossIncome - totalTaxes - totalDeductions

        // Step 8: Convert to all timeframes
        let timeframes = timeframeCalculator.convert(annual: netIncome)

        // Build result
        return TaxCalculationResult(
            income: CalculatedIncome(
                gross: input.grossIncome,
                net: netIncome,
                timeframes: timeframes
            ),
            taxBreakdown: TaxBreakdown(
                federal: federalResult,
                state: stateResult,
                fica: ficaResult,
                totalTaxes: totalTaxes
            ),
            deductionsSummary: DeductionsSummary(
                preTax: totalPreTax,
                postTax: totalPostTax,
                retirement: input.retirementContributions
            ),
            effectiveRates: EffectiveRates(
                federal: federalResult.tax / input.grossIncome,
                state: stateResult.totalTax / input.grossIncome,
                fica: ficaResult.totalFICA / input.grossIncome,
                total: totalTaxes / input.grossIncome
            )
        )
    }

    func calculateScenario(base: TaxCalculationInput, changes: ScenarioChanges) -> ScenarioComparison {
        let baseResult = calculate(input: base)

        var modifiedInput = base

        if let newSalary = changes.newGrossIncome {
            modifiedInput = TaxCalculationInput(
                grossIncome: newSalary,
                filingStatus: changes.newFilingStatus ?? base.filingStatus,
                state: changes.newState ?? base.state,
                payFrequency: base.payFrequency,
                preTaxDeductions: base.preTaxDeductions,
                postTaxDeductions: base.postTaxDeductions,
                retirementContributions: changes.newRetirementContributions ?? base.retirementContributions
            )
        }

        if let newState = changes.newState {
            modifiedInput = TaxCalculationInput(
                grossIncome: modifiedInput.grossIncome,
                filingStatus: modifiedInput.filingStatus,
                state: newState,
                payFrequency: modifiedInput.payFrequency,
                preTaxDeductions: modifiedInput.preTaxDeductions,
                postTaxDeductions: modifiedInput.postTaxDeductions,
                retirementContributions: modifiedInput.retirementContributions
            )
        }

        let scenarioResult = calculate(input: modifiedInput)

        return ScenarioComparison(
            base: baseResult,
            scenario: scenarioResult,
            netDifference: scenarioResult.income.net - baseResult.income.net,
            monthlyDifference: (scenarioResult.income.net - baseResult.income.net) / 12
        )
    }
}
```

---

## 4. Dependency Injection

### Container Pattern

```swift
import Foundation

/// Main dependency injection container
final class DependencyContainer {

    static let shared = DependencyContainer()

    // MARK: - Core Infrastructure

    lazy var coreDataStack: CoreDataStackProtocol = {
        CoreDataStack(modelName: "TakeHome")
    }()

    lazy var cloudKitSync: CloudKitSyncProtocol = {
        CloudKitSyncService(container: coreDataStack)
    }()

    lazy var userDefaults: UserDefaults = {
        .standard
    }()

    // MARK: - Tax Data

    lazy var taxDataProvider: TaxDataProviderProtocol = {
        TaxDataProvider(
            embeddedDataLoader: EmbeddedTaxDataLoader(),
            remoteConfigService: remoteConfigService,
            cacheService: taxDataCache
        )
    }()

    lazy var remoteConfigService: RemoteConfigServiceProtocol = {
        RemoteConfigService(baseURL: AppConfig.taxDataURL)
    }()

    lazy var taxDataCache: TaxDataCacheProtocol = {
        TaxDataCache(userDefaults: userDefaults)
    }()

    // MARK: - Calculators

    lazy var federalTaxCalculator: FederalTaxCalculatorProtocol = {
        FederalTaxCalculator(taxDataProvider: taxDataProvider)
    }()

    lazy var stateTaxCalculator: StateTaxCalculatorProtocol = {
        StateTaxCalculator(taxDataProvider: taxDataProvider)
    }()

    lazy var ficaCalculator: FICACalculatorProtocol = {
        FICACalculator(taxDataProvider: taxDataProvider)
    }()

    lazy var timeframeCalculator: TimeframeCalculatorProtocol = {
        TimeframeCalculator()
    }()

    lazy var taxCalculationEngine: TaxCalculationEngineProtocol = {
        TaxCalculationEngine(
            federalCalculator: federalTaxCalculator,
            stateCalculator: stateTaxCalculator,
            ficaCalculator: ficaCalculator,
            timeframeCalculator: timeframeCalculator,
            taxDataProvider: taxDataProvider
        )
    }()

    // MARK: - Repositories

    lazy var financialProfileRepository: FinancialProfileRepositoryProtocol = {
        FinancialProfileRepository(
            coreDataStack: coreDataStack,
            cloudKitSync: cloudKitSync,
            userDefaults: userDefaults
        )
    }()

    lazy var expenseRepository: ExpenseRepositoryProtocol = {
        ExpenseRepository(
            coreDataStack: coreDataStack,
            cloudKitSync: cloudKitSync
        )
    }()

    lazy var scenarioRepository: ScenarioRepositoryProtocol = {
        ScenarioRepository(
            coreDataStack: coreDataStack,
            cloudKitSync: cloudKitSync
        )
    }()

    // MARK: - ViewModels Factory

    func makeIncomeViewModel() -> IncomeViewModel {
        IncomeViewModel(
            calculationEngine: taxCalculationEngine,
            profileRepository: financialProfileRepository
        )
    }

    func makeExpenseViewModel() -> ExpenseViewModel {
        ExpenseViewModel(
            expenseRepository: expenseRepository,
            profileRepository: financialProfileRepository
        )
    }

    func makeScenarioViewModel() -> ScenarioViewModel {
        ScenarioViewModel(
            calculationEngine: taxCalculationEngine,
            scenarioRepository: scenarioRepository,
            profileRepository: financialProfileRepository
        )
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            calculationEngine: taxCalculationEngine,
            profileRepository: financialProfileRepository,
            expenseRepository: expenseRepository
        )
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            profileRepository: financialProfileRepository,
            calculationEngine: taxCalculationEngine
        )
    }

    func makeHouseholdViewModel() -> HouseholdViewModel {
        HouseholdViewModel(
            profileRepository: financialProfileRepository,
            calculationEngine: taxCalculationEngine
        )
    }

    // MARK: - Coordinators Factory

    func makeAppCoordinator() -> AppCoordinator {
        AppCoordinator(container: self)
    }

    func makeOnboardingCoordinator() -> OnboardingCoordinator {
        OnboardingCoordinator(container: self)
    }

    func makeMainCoordinator() -> MainCoordinator {
        MainCoordinator(container: self)
    }
}

// MARK: - Test Container

#if DEBUG
final class MockDependencyContainer: DependencyContainer {

    override init() {
        super.init()
    }

    override lazy var taxDataProvider: TaxDataProviderProtocol = {
        MockTaxDataProvider()
    }()

    override lazy var coreDataStack: CoreDataStackProtocol = {
        InMemoryCoreDataStack(modelName: "TakeHome")
    }()

    override lazy var cloudKitSync: CloudKitSyncProtocol = {
        MockCloudKitSync()
    }()
}
#endif
```

### Environment Injection for SwiftUI

```swift
import SwiftUI

// MARK: - Environment Keys

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .shared
}

extension EnvironmentValues {
    var container: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withDependencies(_ container: DependencyContainer) -> some View {
        environment(\.container, container)
    }
}

// MARK: - Usage in App

@main
struct TakeHomeApp: App {
    private let container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .withDependencies(container)
        }
    }
}
```

---

## 5. Coordinator Pattern

### Navigation Flow Management

```swift
import SwiftUI
import Combine

/// Navigation destination for the app
enum AppDestination: Hashable {
    case onboarding
    case main
    case income
    case expenses
    case scenario(ScenarioType)
    case household
    case settings
    case taxBreakdown
    case expenseDetail(UUID)
    case scenarioResult(UUID)
}

/// Protocol for all coordinators
protocol CoordinatorProtocol: ObservableObject {
    associatedtype Route: Hashable
    var navigationPath: NavigationPath { get set }
    func navigate(to route: Route)
    func pop()
    func popToRoot()
}

/// App-level coordinator managing top-level navigation
final class AppCoordinator: CoordinatorProtocol {
    @Published var navigationPath = NavigationPath()
    @Published var showOnboarding: Bool = false
    @Published var currentTab: MainTab = .dashboard

    private let container: DependencyContainer
    private var cancellables = Set<AnyCancellable>()

    init(container: DependencyContainer) {
        self.container = container
        checkOnboardingStatus()
    }

    func navigate(to route: AppDestination) {
        switch route {
        case .onboarding:
            showOnboarding = true
        case .main:
            showOnboarding = false
        default:
            navigationPath.append(route)
        }
    }

    func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    func switchTab(to tab: MainTab) {
        currentTab = tab
        popToRoot()
    }

    private func checkOnboardingStatus() {
        container.financialProfileRepository.getCurrentProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] profile in
                    self?.showOnboarding = profile == nil
                }
            )
            .store(in: &cancellables)
    }

    func completeOnboarding() {
        showOnboarding = false
    }
}

/// Main tabs
enum MainTab: String, CaseIterable, Identifiable {
    case dashboard
    case income
    case expenses
    case scenarios
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .income: return "Income"
        case .expenses: return "Expenses"
        case .scenarios: return "Scenarios"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .income: return "dollarsign.circle.fill"
        case .expenses: return "creditcard.fill"
        case .scenarios: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }
}
```

### Root View with Navigation

```swift
import SwiftUI

struct RootView: View {
    @StateObject private var coordinator: AppCoordinator
    @Environment(\.container) private var container

    init() {
        let container = DependencyContainer.shared
        _coordinator = StateObject(wrappedValue: container.makeAppCoordinator())
    }

    var body: some View {
        Group {
            if coordinator.showOnboarding {
                OnboardingFlow(
                    viewModel: container.makeOnboardingViewModel(),
                    onComplete: { coordinator.completeOnboarding() }
                )
            } else {
                MainTabView(coordinator: coordinator)
            }
        }
        .environmentObject(coordinator)
    }
}

struct MainTabView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.container) private var container

    var body: some View {
        TabView(selection: $coordinator.currentTab) {
            ForEach(MainTab.allCases) { tab in
                NavigationStack(path: $coordinator.navigationPath) {
                    tabContent(for: tab)
                        .navigationDestination(for: AppDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: MainTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView(viewModel: container.makeDashboardViewModel())
        case .income:
            IncomeView(viewModel: container.makeIncomeViewModel())
        case .expenses:
            ExpenseListView(viewModel: container.makeExpenseViewModel())
        case .scenarios:
            ScenarioListView(viewModel: container.makeScenarioViewModel())
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .taxBreakdown:
            TaxBreakdownView(viewModel: container.makeIncomeViewModel())
        case .expenseDetail(let id):
            ExpenseDetailView(expenseId: id, viewModel: container.makeExpenseViewModel())
        case .scenarioResult(let id):
            ScenarioResultView(scenarioId: id, viewModel: container.makeScenarioViewModel())
        case .household:
            HouseholdView(viewModel: container.makeHouseholdViewModel())
        default:
            EmptyView()
        }
    }
}
```

---

## Summary

| Pattern | Purpose | Key Components |
|---------|---------|----------------|
| **MVVM + Combine** | UI binding & state management | ViewModels, Publishers, @Published |
| **Repository** | Data access abstraction | Protocols, Core Data, CloudKit |
| **Calculation Engine** | Pure tax/income calculations | Composable calculators, Decimal precision |
| **Dependency Injection** | Testability & flexibility | Container, Factory methods |
| **Coordinator** | Navigation flow | NavigationPath, Destinations |

These patterns work together to create a maintainable, testable, and scalable iOS application architecture.
