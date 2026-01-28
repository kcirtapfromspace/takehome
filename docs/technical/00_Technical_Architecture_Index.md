# TakeHome Technical Architecture PRD

## Index

This technical PRD provides comprehensive implementation specifications for the TakeHome iOS financial planning app. The documentation is organized into five focused documents.

---

## Document Overview

### [01. Architecture Patterns](./01_Architecture_Patterns.md)

Core architectural patterns and design principles:
- **MVVM with Combine** - ViewModels, Publishers, data binding patterns
- **Repository Pattern** - Data access abstraction for Core Data + CloudKit
- **Calculation Engine** - Pure functions, protocol-based design
- **Dependency Injection** - Container pattern for testability
- **Coordinator Pattern** - Navigation flow management

### [02. Data Models](./02_Data_Models.md)

Complete data model definitions:
- **Swift Domain Models** - FinancialProfile, Income, Expenses, Scenarios
- **Enums & Types** - USState, FilingStatus, PayFrequency, ExpenseCategory
- **Core Data Schema** - Entity definitions and relationships
- **CloudKit Records** - Cross-device sync structure
- **Entity Conversions** - Domain ↔ Persistence mapping

### [03. Calculation Formulas](./03_Calculation_Formulas.md)

Comprehensive tax and financial calculations:
- **Federal Tax** - All 7 brackets for 4 filing statuses (2024)
- **FICA** - Social Security (6.2%, $168,600 cap) + Medicare (1.45% + 0.9%)
- **State Taxes** - All 50 states + DC with:
  - No-tax states (9)
  - Flat-tax states (10)
  - Progressive bracket states (32)
  - SDI and local tax details
- **Retirement Limits** - 401(k), IRA, HSA contribution limits
- **Timeframe Conversions** - Annual → Hourly divisors
- **Household Split** - Proportional expense calculations

### [04. Tax Data Architecture](./04_Tax_Data_Architecture.md)

Hybrid tax data system with embedded defaults + remote updates:
- **Embedded Data** - Bundle JSON structure for offline operation
- **Remote Config** - API schema for annual updates
- **Cache Service** - Offline access with validation
- **Tax Data Provider** - Unified interface with fallback chain
- **Version Management** - Update detection and notification

### [05. State Machine & Navigation](./05_State_Machine_Navigation.md)

App state and navigation management:
- **App State Machine** - Launch, Onboarding, Main states
- **Navigation Architecture** - Tab + Stack navigation with Coordinator
- **Onboarding Flow** - 7-step guided setup
- **Feature Flags** - Monetization tier gating (Free/Pro/Business)
- **Deep Linking** - URL scheme handling

### [06. Rust Core Engine](./06_Rust_Core_Engine.md)

Cross-platform calculation engine in Rust:
- **Core Library** - Tax calculations, FICA, state taxes in pure Rust
- **UniFFI Bindings** - Auto-generated Swift/Kotlin bindings
- **Domain Models** - Income, Tax, State, Scenario types in Rust
- **Calculators** - Federal, State, FICA, Timeframe modules
- **CLI Tools** - Tax data validator utility
- **Cross-Platform** - iOS (now), Android/Web (future via WASM)

---

## Quick Reference

### Key Technologies

| Technology | Purpose |
|------------|---------|
| **Rust** | Core calculation engine |
| **UniFFI** | Rust → Swift bindings |
| **rust_decimal** | Financial precision in Rust |
| SwiftUI | UI Framework |
| Combine | Reactive data flow |
| Core Data | Local persistence |
| CloudKit | Cross-device sync |

### Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                          │
├─────────────────────────────────────────────────────────────┤
│                     ViewModels (MVVM)                       │
├─────────────────────────────────────────────────────────────┤
│                  Swift Wrapper Layer                        │
├─────────────────────────────────────────────────────────────┤
│                  UniFFI Bindings                            │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │              takehome-core (Rust)                     │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │  Federal Tax │ State Tax │ FICA │ Timeframes │ Scenarios│
│  └───────────────────────────────────────────────────────┘  │
├───────────────────────┬─────────────────────────────────────┤
│   Tax Data Provider   │         Repositories                │
│  (Embedded + Remote)  │    (Core Data + CloudKit)           │
└───────────────────────┴─────────────────────────────────────┘

Future Platforms (same Rust core):
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Android    │  │     Web      │  │     CLI      │
│  (Kotlin)    │  │   (WASM)     │  │   (Native)   │
└──────────────┘  └──────────────┘  └──────────────┘
```

### File Structure

```
takehome/
│
├── core/                           # 🦀 RUST CORE LIBRARY
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs
│   │   ├── ffi.rs                 # UniFFI exports
│   │   ├── engine.rs              # Main calculation engine
│   │   ├── models/
│   │   │   ├── income.rs
│   │   │   ├── tax.rs
│   │   │   ├── state.rs
│   │   │   └── household.rs
│   │   ├── calculators/
│   │   │   ├── federal.rs
│   │   │   ├── state.rs
│   │   │   ├── fica.rs
│   │   │   └── timeframe.rs
│   │   └── data/
│   │       ├── loader.rs
│   │       └── embedded.rs
│   ├── uniffi/
│   │   └── takehome_core.udl      # Interface definition
│   └── tests/
│
├── bindings/                       # Generated bindings
│   ├── swift/TakeHomeCore/
│   └── TakeHomeCore.xcframework
│
├── ios/                            # 📱 iOS APP (Swift/SwiftUI)
│   ├── TakeHome.xcodeproj
│   └── TakeHome/
│       ├── App/
│       │   ├── TakeHomeApp.swift
│       │   └── DependencyContainer.swift
│       ├── Core/
│       │   ├── TakeHomeCoreWrapper.swift  # Rust bridge
│       │   ├── TaxDataProvider.swift
│       │   └── RemoteConfigService.swift
│       ├── Features/
│       │   ├── Dashboard/
│       │   ├── Income/
│       │   ├── Expenses/
│       │   ├── Scenarios/
│       │   └── Onboarding/
│       ├── Repositories/
│       ├── Navigation/
│       ├── Services/
│       └── Persistence/
│
├── tools/                          # 🔧 CLI UTILITIES
│   └── tax-validator/
│       ├── Cargo.toml
│       └── src/main.rs
│
└── docs/
    └── technical/                  # 📚 This documentation
```

---

## Implementation Priorities

### Phase 0: Rust Core Setup

1. Set up Rust workspace with `takehome-core` crate
2. Implement core models (Income, Tax, State, FICA)
3. Build federal tax calculator with all brackets
4. Build state tax calculator for all 50 states
5. Set up UniFFI and generate Swift bindings
6. Create XCFramework for iOS integration

### Phase 1: iOS MVP

1. Integrate Rust core via XCFramework
2. Build Swift wrapper layer
3. Multi-timeframe income view (SwiftUI)
4. Basic expense management
5. Onboarding flow
6. Local persistence (Core Data)

### Phase 2: Advanced Features

1. Scenario planner (uses Rust `compare_scenarios`)
2. Household mode with proportional splitting
3. Retirement contribution modeling
4. CloudKit sync
5. Remote tax data updates

### Phase 3: Monetization & Polish

1. Subscription management (StoreKit 2)
2. Feature gating by tier
3. Usage analytics
4. Export functionality

### Phase 4: Cross-Platform (Future)

1. Android app (Kotlin + same Rust core)
2. Web app (WASM + React/Vue)
3. CLI tool for power users

---

## Verification Checklist

### Tax Accuracy

- [ ] Federal brackets match IRS Publication 15-T (2024)
- [ ] State tax rates verified against state revenue departments
- [ ] FICA wage base and rates current for tax year
- [ ] Retirement limits match IRS announcements
- [ ] Run `tax-validator` CLI on all JSON data files

### Rust Core

- [ ] `cargo build --release` succeeds
- [ ] `cargo test` passes all unit tests
- [ ] `cargo bench` shows acceptable performance
- [ ] UniFFI bindings generate without errors
- [ ] XCFramework builds for both iOS and simulator
- [ ] `rust_decimal` used for all financial values

### Swift Integration

- [ ] XCFramework links correctly in Xcode
- [ ] `TakeHomeCoreWrapper` provides Swift-friendly API
- [ ] Decimal conversions work correctly
- [ ] All enum mappings are complete

### Code Quality

- [ ] All Swift code compiles (syntax check)
- [ ] Protocols have mock implementations for testing
- [ ] Error handling covers edge cases
- [ ] No `unwrap()` in production Rust code

### Architecture

- [ ] All components injectable via DependencyContainer
- [ ] ViewModels are ObservableObject compliant
- [ ] Repository pattern abstracts Core Data
- [ ] Coordinator manages all navigation
- [ ] Rust core has no UI dependencies (pure logic)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024 | Initial technical architecture |

---

## References

- [IRS Publication 15-T (2024)](https://www.irs.gov/pub/irs-pdf/p15t.pdf) - Federal withholding tables
- [Tax Foundation State Tax Data](https://taxfoundation.org/state-individual-income-tax-rates-and-brackets/) - State tax rates
- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple Combine Framework](https://developer.apple.com/documentation/combine)
- [Apple Core Data](https://developer.apple.com/documentation/coredata)
- [Apple CloudKit](https://developer.apple.com/documentation/cloudkit)
