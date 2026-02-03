# Fix Deduction Calculation Bug

## Problem Statement

When entering percentage-based deductions (e.g., 7% Roth 401k with "Per Check" frequency), the calculation incorrectly multiplies the result by the pay periods, causing wildly incorrect totals.

**Example from screenshot:**
- User enters: 7% Roth 401(k) with "Per Check" frequency
- Expected: 7% of salary = ~$17,500/year (assuming ~$250k salary)
- Actual: $455,000/year (182% of pay)

## Root Cause

In `ios/TakeHome/Models/DeductionEntry.swift` lines 34-47:

```swift
func annualAmount(grossSalary: Decimal, payFrequency: PayFrequency) -> Decimal {
    let dollarAmount: Decimal
    switch inputType {
    case .dollarAmount:
        dollarAmount = amount
    case .percentageOfSalary:
        dollarAmount = grossSalary * (amount / 100)  // ← Already annual!
    }
    return frequency.toAnnual(dollarAmount, payFrequency: payFrequency)  // ← BUG
}
```

**The bug:** When `inputType == .percentageOfSalary`, the calculated dollar amount is already annual (it's a percentage OF ANNUAL SALARY), but the code still applies frequency conversion:
- `$250,000 × 7% = $17,500` (annual)
- `$17,500 × 26` (bi-weekly periods) = `$455,000` ❌

## Solution

### 1. Fix calculation logic (Required)

**File:** `ios/TakeHome/Models/DeductionEntry.swift`

Only apply frequency conversion for dollar amounts:

```swift
func annualAmount(grossSalary: Decimal, payFrequency: PayFrequency) -> Decimal {
    guard isEnabled && amount > 0 else { return 0 }

    switch inputType {
    case .dollarAmount:
        // Dollar amounts need frequency conversion
        return frequency.toAnnual(amount, payFrequency: payFrequency)
    case .percentageOfSalary:
        // Percentage of salary is already annual (% of annual salary)
        return grossSalary * (amount / 100)
    }
}
```

### 2. Improve UI to prevent confusion (Recommended)

**File:** `ios/TakeHome/Views/Onboarding/DetailedDeductionsStepView.swift`

Hide the frequency picker when inputType is percentage (since frequency doesn't apply):

```swift
// Around line 230, wrap frequency picker in conditional:
if entry.inputType == .dollarAmount {
    Picker("Frequency", selection: ...) { ... }
}
```

Also auto-reset frequency to `.annual` when switching to percentage mode to prevent stale data.

### 3. Add missing test case (Required)

**File:** `ios/TakeHomeTests/ViewModels/OnboardingViewModelTests.swift`

Add test for percentage with non-annual frequency to prevent regression:

```swift
func testAnnualAmount_Percentage_IgnoresFrequency() {
    let entry = DeductionEntry(
        type: .roth401k,
        amount: 7, // 7%
        frequency: .perPaycheck,  // Should be ignored
        inputType: .percentageOfSalary,
        isEnabled: true
    )
    // Should be 7% of salary, NOT multiplied by pay periods
    XCTAssertEqual(entry.annualAmount(grossSalary: 250000, payFrequency: .biWeekly), 17500)
}
```

## Files to Modify

1. `ios/TakeHome/Models/DeductionEntry.swift` - Fix calculation logic
2. `ios/TakeHome/Views/Onboarding/DetailedDeductionsStepView.swift` - Hide frequency picker for percentages
3. `ios/TakeHomeTests/ViewModels/OnboardingViewModelTests.swift` - Add regression test

## Verification

1. Build the app: `xcodebuild -scheme TakeHome -configuration Debug`
2. Run tests: `xcodebuild test -scheme TakeHome -destination 'platform=iOS Simulator,name=iPhone 15'`
3. Manual test:
   - Enter a percentage deduction (e.g., 7% Roth 401k)
   - Verify the annual total shows 7% of gross salary, not a multiplied value
   - Try switching between dollar and percentage input types
   - Verify frequency picker only appears for dollar amounts
