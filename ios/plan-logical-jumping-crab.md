# Enhanced Onboarding Flow - Implementation Plan

## Overview
Redesign the onboarding flow to support multiple household types, flexible income entry, and comprehensive itemized deductions with multiple input modes.

---

## New Data Models

### 1. HouseholdType Enum
```swift
enum HouseholdType: String, CaseIterable, Identifiable {
    case single           // Single person household
    case twoIncomes       // Two incomes, manual partner entry
    case paired           // Paired accounts (coming soon)

    var id: String { rawValue }
    var displayName: String { ... }
    var description: String { ... }
}
```

### 2. PartnerProfile Struct
```swift
struct PartnerProfile: Codable {
    var name: String = ""
    var grossSalary: Decimal = 0
    var payFrequency: PayFrequency = .biWeekly
    var state: USState = .california
    var filingStatus: FilingStatus = .marriedFilingJointly
}
```

### 3. DeductionFrequency Enum
```swift
enum DeductionFrequency: String, CaseIterable {
    case annual
    case monthly
    case perPaycheck

    func toAnnual(_ amount: Decimal, payFrequency: PayFrequency) -> Decimal { ... }
}
```

### 4. DeductionInputType Enum
```swift
enum DeductionInputType: String, CaseIterable {
    case dollarAmount
    case percentageOfSalary
}
```

### 5. DeductionType Enum (18 types)
```swift
enum DeductionType: String, CaseIterable, Identifiable {
    // Pre-tax
    case traditional401k
    case roth401k
    case traditional403b
    case traditional457b
    case healthInsurance
    case dentalInsurance
    case visionInsurance
    case hsa
    case fsa
    case dependentCareFSA
    case commuterTransit
    case commuterParking
    case lifeInsurance

    // Post-tax
    case unionDues
    case garnishments
    case charitableDonations
    case otherPreTax
    case otherPostTax

    var isPreTax: Bool { ... }
    var displayName: String { ... }
    var description: String { ... }
    var annualLimit: Decimal? { ... }  // IRS limits where applicable
}
```

### 6. DeductionEntry Struct
```swift
struct DeductionEntry: Identifiable, Codable {
    let id: UUID
    var type: DeductionType
    var amount: Decimal
    var frequency: DeductionFrequency
    var inputType: DeductionInputType
    var isEnabled: Bool

    func annualAmount(grossSalary: Decimal, payFrequency: PayFrequency) -> Decimal { ... }
}
```

---

## Updated OnboardingStep Enum

```swift
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case householdType      // NEW: Choose single/twoIncomes/paired
    case income
    case partnerIncome      // NEW: Conditional - only for twoIncomes
    case location
    case deductionSetup     // NEW: Quick vs Detailed choice
    case deductionsPreTax   // NEW: Full itemized pre-tax list
    case deductionsPostTax  // NEW: Full itemized post-tax list
    case reveal
    case expenses
    case complete

    func shouldShow(for context: OnboardingContext) -> Bool {
        switch self {
        case .partnerIncome:
            return context.householdType == .twoIncomes
        case .deductionsPreTax, .deductionsPostTax:
            return context.deductionSetupMode == .detailed
        case .deductionSetup:
            return true  // Always show choice
        default:
            return true
        }
    }
}
```

---

## New/Updated Views

### 1. HouseholdTypeStepView
- Three card options: Single, Two Incomes, Paired (disabled with "Coming Soon")
- Clear descriptions for each option
- Visual icons for each type

### 2. PartnerIncomeStepView (Conditional)
- Partner name field
- Gross salary with frequency toggle (annual/monthly/per-paycheck)
- State and filing status pickers
- Summary card showing calculated annual salary

### 3. DeductionSetupStepView
- Two options: "Quick Setup" vs "Detailed Setup"
- Quick: Just 401k + health insurance (current behavior)
- Detailed: Full itemized list with all 18 deduction types

### 4. DetailedDeductionsStepView (Pre-Tax & Post-Tax)
- Expandable sections for each deduction type
- Per-deduction controls:
  - Enable/disable toggle
  - Amount field
  - Frequency picker (annual/monthly/per-paycheck)
  - Input type toggle ($ vs %)
- Running totals at bottom:
  - Total in dollars
  - Total as percentage of salary
- IRS limit warnings where applicable

### 5. Updated IncomeStepView
- Add frequency toggle for salary entry
- Support: annual, monthly, per-paycheck
- Live conversion display showing all frequencies

---

## OnboardingViewModel Updates

### New Properties
```swift
@Published var householdType: HouseholdType = .single
@Published var partnerProfile: PartnerProfile = PartnerProfile()
@Published var deductionSetupMode: DeductionSetupMode = .quick
@Published var deductionEntries: [DeductionEntry] = DeductionType.allCases.map { ... }
@Published var salaryInputFrequency: DeductionFrequency = .annual
```

### New Computed Properties
```swift
var preTaxDeductionEntries: [DeductionEntry] { ... }
var postTaxDeductionEntries: [DeductionEntry] { ... }
var totalPreTaxAnnual: Decimal { ... }
var totalPostTaxAnnual: Decimal { ... }
var totalPreTaxPercent: Double { ... }
var totalPostTaxPercent: Double { ... }
```

### Updated Navigation
```swift
func next() async {
    let allSteps = OnboardingStep.allCases
    let context = OnboardingContext(
        householdType: householdType,
        deductionSetupMode: deductionSetupMode
    )

    // Find next visible step
    guard let currentIndex = allSteps.firstIndex(of: currentStep) else { return }
    for step in allSteps[(currentIndex + 1)...] {
        if step.shouldShow(for: context) {
            currentStep = step
            return
        }
    }
}
```

---

## Data Model Updates

### FinancialProfile
```swift
struct FinancialProfile: Codable {
    var income: IncomeProfile
    var location: LocationProfile
    var deductions: DeductionProfile
    var householdType: HouseholdType = .single      // NEW
    var partnerProfile: PartnerProfile?              // NEW
}
```

### DeductionProfile
```swift
struct DeductionProfile: Codable {
    // Existing fields remain for backward compatibility
    var traditional401k: Decimal = 0
    var roth401k: Decimal = 0
    var healthInsurance: Decimal = 0
    var hsa: Decimal = 0

    // NEW: Full itemized entries
    var entries: [DeductionEntry] = []

    // Computed totals from entries
    var preTaxTotal: Decimal { ... }
    var postTaxTotal: Decimal { ... }
}
```

---

## Implementation Order

1. **Add new enums and models** (HouseholdType, DeductionFrequency, DeductionInputType, DeductionType, DeductionEntry, PartnerProfile)

2. **Update FinancialProfile and DeductionProfile** with new fields

3. **Add OnboardingContext** struct for conditional navigation

4. **Update OnboardingStep** with new cases and `shouldShow(for:)` method

5. **Update OnboardingViewModel** with new properties and navigation logic

6. **Create HouseholdTypeStepView** - household type selection

7. **Create PartnerIncomeStepView** - partner income entry (conditional)

8. **Create DeductionSetupStepView** - quick vs detailed choice

9. **Create DetailedDeductionsStepView** - itemized deductions with flexible input

10. **Update IncomeStepView** - add salary frequency toggle

11. **Update OnboardingView** - wire up new steps

12. **Add tests** for new view models and navigation logic

---

## UI/UX Details

### Frequency Toggle Design
```
┌─────────────────────────────────────┐
│  Annual  │  Monthly  │  Per Check  │
└─────────────────────────────────────┘
```

### Input Type Toggle Design
```
┌─────────────────────────────────────┐
│  [$] Amount  │  [%] Of Salary      │
└─────────────────────────────────────┘
```

### Running Totals Display
```
┌─────────────────────────────────────┐
│ Pre-Tax Deductions                  │
│ ─────────────────────────────────── │
│ Total: $15,000/year  •  15% of pay  │
└─────────────────────────────────────┘
```

### Deduction Entry Row
```
┌─────────────────────────────────────────────┐
│ ○ Traditional 401(k)           [Enabled ✓]  │
│   Reduces taxable income now                │
│   ┌────────────┐  ┌─────────┐  ┌───────┐   │
│   │ $6,000     │  │ Annual ▾│  │ $ │ % │   │
│   └────────────┘  └─────────┘  └───────┘   │
│   IRS Limit: $23,000 (under 50)             │
└─────────────────────────────────────────────┘
```

---

## Files to Create/Modify

### New Files
- `TakeHome/Models/HouseholdType.swift`
- `TakeHome/Models/PartnerProfile.swift`
- `TakeHome/Models/DeductionEntry.swift`
- `TakeHome/Models/DeductionType.swift`
- `TakeHome/Models/DeductionFrequency.swift`
- `TakeHome/Models/DeductionInputType.swift`
- `TakeHome/Views/Onboarding/HouseholdTypeStepView.swift`
- `TakeHome/Views/Onboarding/PartnerIncomeStepView.swift`
- `TakeHome/Views/Onboarding/DeductionSetupStepView.swift`
- `TakeHome/Views/Onboarding/DetailedDeductionsStepView.swift`

### Modified Files
- `TakeHome/Models/FinancialProfile.swift` - Add householdType, partnerProfile
- `TakeHome/Models/DeductionProfile.swift` - Add entries array
- `TakeHome/ViewModels/OnboardingViewModel.swift` - New properties, updated navigation
- `TakeHome/Views/Onboarding/OnboardingView.swift` - New step views
- `TakeHomeTests/ViewModels/OnboardingViewModelTests.swift` - New tests

---

## Verification

1. Unit tests pass for all new models
2. OnboardingViewModel tests cover conditional navigation
3. Manual testing: Complete onboarding as single, two-incomes
4. Verify deduction calculations with different frequencies and input types
5. Verify running totals update correctly
