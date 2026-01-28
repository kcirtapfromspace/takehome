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
