# TakeHome iOS App Foundation - Implementation Plan

## Current State
- **Rust Core Engine**: Complete (3,597 lines, 53 tests) at `/core/`
- **Swift Bindings**: Not generated (UniFFI ready in `core/Makefile`)
- **iOS App**: Not started (no Xcode project)

## Goal
Create the iOS app foundation with ViewModels and comprehensive tests.

---

## Phase 1: Generate Swift Bindings & Create Xcode Project

### 1.1 Generate Bindings from Rust Core
```bash
cd core
make setup        # Install Rust iOS targets
make ios          # Build for iOS device + simulator
make bindings-swift  # Generate Swift code
make xcframework  # Create XCFramework
```

**Outputs:**
- `bindings/swift/TakeHomeCore.swift`
- `bindings/swift/TakeHomeCoreFFI.h`
- `bindings/TakeHomeCore.xcframework`

### 1.2 Create Xcode Project Structure
```
ios/
├── TakeHome.xcodeproj
├── TakeHome/
│   ├── App/
│   │   ├── TakeHomeApp.swift
│   │   └── DependencyContainer.swift
│   ├── Core/
│   │   ├── TakeHomeCoreWrapper.swift    # Swift-friendly FFI wrapper
│   │   └── DecimalConversions.swift
│   ├── Models/
│   │   ├── FinancialProfile.swift
│   │   ├── Income.swift
│   │   ├── Expense.swift
│   │   └── Scenario.swift
│   ├── ViewModels/
│   │   ├── BaseViewModel.swift
│   │   ├── IncomeViewModel.swift
│   │   ├── ExpenseViewModel.swift
│   │   ├── ScenarioViewModel.swift
│   │   ├── DashboardViewModel.swift
│   │   └── OnboardingViewModel.swift
│   ├── Views/
│   │   ├── MainTabView.swift
│   │   ├── Income/
│   │   ├── Dashboard/
│   │   └── Onboarding/
│   └── Repositories/
│       └── RepositoryProtocols.swift
├── TakeHomeTests/
│   ├── Core/
│   │   └── TakeHomeCoreWrapperTests.swift
│   ├── ViewModels/
│   │   ├── IncomeViewModelTests.swift
│   │   ├── ExpenseViewModelTests.swift
│   │   └── ScenarioViewModelTests.swift
│   ├── Mocks/
│   │   ├── MockTakeHomeCore.swift
│   │   └── MockRepositories.swift
│   └── Integration/
│       └── RustCoreIntegrationTests.swift
└── TakeHomeUITests/
    └── OnboardingUITests.swift
```

---

## Phase 2: Swift Wrapper Layer

### 2.1 TakeHomeCoreWrapper
Wraps the FFI layer with Swift-friendly API:
- Converts `String` ↔ `Decimal` (FFI uses strings for precision)
- Maps Swift enums to FFI string codes
- Provides async/await interface
- Converts `TaxResultFFI` → Swift `TaxCalculationResult`

```swift
protocol TakeHomeCoreProtocol {
    func calculateTaxes(input: TaxCalculationInput) throws -> TaxCalculationResult
    func compareScenarios(base: TaxCalculationInput, scenario: TaxCalculationInput) throws -> ScenarioComparison
    func convertTimeframes(annual: Decimal) -> TimeframeIncome
    func calculateHouseholdSplit(...) -> HouseholdSplit
    var allStateCodes: [USState] { get }
    var allFilingStatuses: [FilingStatus] { get }
}
```

### 2.2 Tests for Wrapper
- Decimal string parsing edge cases
- All enum conversions
- FFI error handling
- Integration tests calling real Rust core

---

## Phase 3: ViewModels with Tests

### 3.1 BaseViewModel (MVVM + Combine)
```swift
class BaseViewModel<State, Action>: ObservableObject {
    @Published private(set) var state: State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: AppError?
    var cancellables = Set<AnyCancellable>()

    func send(_ action: Action) { }
}
```

### 3.2 IncomeViewModel
**State:** grossSalary, payFrequency, filingStatus, state, calculatedResult
**Actions:** updateGrossSalary, updateState, recalculate, save
**Tests:** State updates, calculation triggers, error handling

### 3.3 ExpenseViewModel
**State:** expenses, categories, totalMonthly
**Actions:** addExpense, updateExpense, deleteExpense, filter
**Tests:** CRUD operations, category filtering, total calculations

### 3.4 ScenarioViewModel
**State:** scenarios, activeComparison, baseProfile
**Actions:** createScenario, runComparison, saveScenario
**Tests:** Scenario creation, comparison results, persistence

### 3.5 OnboardingViewModel
**State:** currentStep (enum), profileData, calculatedResult
**Steps:** welcome → income → location → deductions → reveal → expenses → complete
**Tests:** Step progression, validation, skip handling

---

## Phase 4: Initial SwiftUI Views

### 4.1 App Entry & Navigation
- `TakeHomeApp.swift` with DependencyContainer
- `MainTabView` with 5 tabs: Dashboard, Income, Expenses, Scenarios, Settings

### 4.2 Income Views
- `IncomeView` - Salary input, state picker, filing status
- `TimeframeCardsView` - All 6 timeframes (annual → hourly)
- `TaxBreakdownView` - Federal, state, FICA breakdown

### 4.3 Onboarding Flow
7-step flow per PRD with "reveal" animation showing take-home pay

---

## Phase 5: Test Infrastructure

### 5.1 Mock Implementations
- `MockTakeHomeCore` - Returns predictable results for ViewModel tests
- `MockFinancialProfileRepository`
- `MockExpenseRepository`

### 5.2 Test Coverage Targets
| Component | Target |
|-----------|--------|
| TakeHomeCoreWrapper | 95% |
| ViewModels | 80% |
| Integration (FFI) | Key paths |

---

## Implementation Order

1. **Generate bindings** - Run make commands to create XCFramework
2. **Create Xcode project** - Set up structure, link framework
3. **TakeHomeCoreWrapper + tests** - Swift-friendly FFI wrapper
4. **IncomeViewModel + tests** - Core calculation flow
5. **ExpenseViewModel + tests** - Expense management
6. **ScenarioViewModel + tests** - What-if comparisons
7. **Basic SwiftUI views** - Income, Dashboard
8. **OnboardingViewModel + flow** - First-time experience
9. **Integration tests** - Verify Rust FFI works correctly

---

## Key Files to Reference

- `core/uniffi/takehome_core.udl` - FFI interface definition
- `core/src/ffi.rs` - FFI implementation details
- `docs/technical/01_Architecture_Patterns.md` - MVVM patterns
- `docs/technical/02_Data_Models.md` - Domain models
- `core/Makefile` - Build commands

---

## Verification

1. **Unit tests pass**: `xcodebuild test -scheme TakeHome -destination 'platform=iOS Simulator,name=iPhone 15'`
2. **Integration tests**: Verify Rust FFI returns correct tax calculations
3. **Manual testing**: Run app in simulator, complete onboarding flow
