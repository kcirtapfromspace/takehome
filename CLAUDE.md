# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TakeHome is an iOS financial planning app (not yet built) based on a proven 10-year Google Sheets system. The complete Product Requirements Document is in `TakeHome_PRD_v2.md`.

**Platform:** iOS 16+ with SwiftUI
**Storage:** Core Data (local-first) with CloudKit sync
**Security:** Zero-knowledge encryption, offline-first calculations

## Build Commands (Once Project is Initialized)

```bash
# Build
xcodebuild -scheme TakeHome -configuration Debug

# Run tests
xcodebuild test -scheme TakeHome -destination 'platform=iOS Simulator,name=iPhone 15'

# Lint (if SwiftLint configured)
swiftlint
```

## Architecture

### Core Calculation Engine

The tax calculation engine uses progressive bracket lookups:
```swift
Tax = BaseTax + (Income - BracketFloor) × MarginalRate
```

Key calculations:
- Federal withholding with all tax brackets
- Social Security with $142,800 wage base cap
- Medicare at 1.45%
- State-specific taxes (all 50 states required)

### Multi-Timeframe Synchronization

All income views sync from annual as the base:
- Annual → Monthly (÷12) → Bi-Weekly (÷26) → Weekly (÷52) → Daily (÷260) → Hourly (÷2080)

### Data Model

```
FinancialProfile
├── Income (gross salary, bonuses, pay frequency)
├── Location (state, filing status)
├── Deductions (pre-tax, post-tax, 401k)
├── Expenses (9 categories: Debt, Home, Necessities, Tech, Entertainment, Vehicle, Education, Finance, Other)
└── Household (optional partner profile with proportional expense splitting)
```

### Household Expense Split
```
Partner's Share% = Partner's Net Income ÷ Total Household Net Income
Partner's Expense = Shared Expense × Partner's Share%
```

## Key Differentiators

1. **Multi-Timeframe Display** - 6 simultaneous income views (unique in market)
2. **Household Proportional Split** - Auto-fair expense division based on income ratios
3. **Scenario Planner** - What-if for raises, state moves, 401k changes
4. **Time-Value Calculator** - Convert expenses to work-hours needed

## Development Priorities

Phase 1 MVP features (in priority order):
1. Tax calculation engine with all 50 states
2. Multi-timeframe income view
3. Expense management with category templates
4. Scenario planner
5. Household mode with proportional splitting
6. Retirement contribution modeling

## Critical Implementation Notes

- Tax calculations require annual updates for law changes; include prominent disclaimer
- All calculations must work offline (no network dependency)
- Decimal precision required for all financial calculations
- Accessibility (VoiceOver, Dynamic Type) required from day 1

---

## Go-Live Guidelines

### Release Readiness: ~70% Technical, ~30% Release Ready

**What's Ship-Quality:**
- Rust tax engine: ALL 50 states + DC, federal, FICA, progressive brackets
- 53 passing tests with benchmarks
- UniFFI Swift bindings + XCFramework (TakeHomeCore.xcframework) built
- 27 SwiftUI views with MVVM architecture
- Onboarding flow, dashboard (6 timeframes), household mode, scenario planner, expense management
- Core Data local persistence

### Must-Fix Before Release

1. **Superwall Paywall (CRITICAL — not integrated at all)**
   - Add Superwall SDK via SPM
   - Initialize in TakeHomeApp.swift
   - Gate after first calculation result (user sees value → paywall)
   - Configure products in App Store Connect: $6.99/mo or $39.99/yr
   - Primary placement: `first_calculation_complete`

2. **Code Signing** — Dev certs only, need production certs + provisioning profiles

3. **ViewModel Wiring** — Test full onboarding → dashboard flow end-to-end; some views may not be connected

4. **Tax Year Disclaimer** — Data is 2024 rates, add "Rates as of 2024" prominently

5. **App Icon** — None exists, need 1024x1024

6. **Screenshots** — Key shots: multi-timeframe view, household mode, scenario planner

7. **App Store Metadata:**
   - Name: "TakeHome — Salary After Tax Calculator"
   - Subtitle: "See Your Real Pay in 6 Timeframes"
   - Keywords: "take home pay calculator", "salary after tax", "paycheck calculator", "net pay calculator", "income tax calculator", "salary calculator [state]"
   - Category: Finance

8. **Privacy Policy** — Required even for local-only data (use template generator)

### Nice-to-Have (Post-Launch)
- Fastlane build/deploy automation
- CI/CD workflows (GitHub Actions)
- CloudKit sync
- WASM web calculator (for SEO landing pages)

### Distribution Strategy
- **Primary channel:** ASO — evergreen financial keywords with massive search volume
- **Secondary:** Reddit (r/personalfinance 18M+, r/cscareerquestions, r/financialindependence)
- **Tertiary:** State-specific SEO landing pages (50 states × WASM calculator)
- **Timing:** Tax season (Jan-Apr) and job switch season (Jan, Sep) are peak
- **Onboarding → hard paywall** after showing first calculation result

### No-Go Items
- Do NOT add social features or sharing
- Do NOT connect to any external APIs — all calculations must be offline
- Do NOT store any PII beyond what's needed for calculations (local only)
