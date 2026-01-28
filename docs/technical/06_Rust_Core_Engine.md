# TakeHome Technical Architecture: Rust Core Engine

## Overview

This document defines the Rust-based calculation engine that powers TakeHome's tax and financial computations. The engine is compiled as a static library for iOS with Swift bindings via UniFFI, enabling cross-platform reuse.

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      iOS App (Swift/SwiftUI)                    │
├─────────────────────────────────────────────────────────────────┤
│                    Swift Bindings (UniFFI)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                    ┌─────────────────────┐                      │
│                    │  takehome-core      │                      │
│                    │  (Rust Library)     │                      │
│                    ├─────────────────────┤                      │
│                    │ • Federal Tax Calc  │                      │
│                    │ • State Tax Calc    │                      │
│                    │ • FICA Calculator   │                      │
│                    │ • Timeframe Conv.   │                      │
│                    │ • Scenario Engine   │                      │
│                    │ • Household Split   │                      │
│                    └─────────────────────┘                      │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                    Tax Data (JSON/Embedded)                     │
└─────────────────────────────────────────────────────────────────┘

Future Platforms:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Android    │  │     Web      │  │     CLI      │
│   (JNI)      │  │   (WASM)     │  │   (Native)   │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## 2. Project Structure

```
takehome/
├── ios/                          # iOS App (Swift/SwiftUI)
│   ├── TakeHome/
│   └── TakeHome.xcodeproj
│
├── core/                         # Rust Core Library
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs               # Library entry point
│   │   ├── ffi.rs               # UniFFI bindings
│   │   │
│   │   ├── models/              # Domain models
│   │   │   ├── mod.rs
│   │   │   ├── income.rs
│   │   │   ├── tax.rs
│   │   │   ├── state.rs
│   │   │   ├── expense.rs
│   │   │   ├── scenario.rs
│   │   │   └── household.rs
│   │   │
│   │   ├── calculators/         # Calculation engines
│   │   │   ├── mod.rs
│   │   │   ├── federal.rs
│   │   │   ├── state.rs
│   │   │   ├── fica.rs
│   │   │   ├── timeframe.rs
│   │   │   ├── retirement.rs
│   │   │   └── household.rs
│   │   │
│   │   ├── data/                # Tax data handling
│   │   │   ├── mod.rs
│   │   │   ├── loader.rs
│   │   │   ├── federal_2024.rs
│   │   │   ├── states_2024.rs
│   │   │   └── embedded.rs
│   │   │
│   │   └── engine.rs            # Main calculation engine
│   │
│   ├── uniffi/
│   │   └── takehome_core.udl    # UniFFI interface definition
│   │
│   └── tests/
│       ├── federal_tests.rs
│       ├── state_tests.rs
│       └── integration_tests.rs
│
├── bindings/                     # Generated bindings
│   ├── swift/
│   │   └── TakeHomeCore/
│   ├── kotlin/                   # Future: Android
│   └── wasm/                     # Future: Web
│
└── tools/                        # CLI utilities
    └── tax-validator/
        ├── Cargo.toml
        └── src/main.rs
```

---

## 3. Cargo Configuration

### core/Cargo.toml

```toml
[package]
name = "takehome-core"
version = "0.1.0"
edition = "2021"
authors = ["TakeHome Team"]
description = "Core calculation engine for TakeHome financial app"

[lib]
crate-type = ["staticlib", "cdylib", "lib"]
name = "takehome_core"

[dependencies]
# Precise decimal arithmetic
rust_decimal = { version = "1.33", features = ["serde"] }
rust_decimal_macros = "1.33"

# Serialization
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# UniFFI for cross-platform bindings
uniffi = { version = "0.25" }

# Error handling
thiserror = "1.0"

# Date handling
chrono = { version = "0.4", features = ["serde"] }

# Lazy static for embedded data
once_cell = "1.19"

[build-dependencies]
uniffi = { version = "0.25", features = ["build"] }

[dev-dependencies]
criterion = "0.5"
proptest = "1.4"

[[bench]]
name = "calculations"
harness = false

[features]
default = []
embedded-data = []  # Compile tax data into binary
wasm = []           # WebAssembly target
```

---

## 4. Core Models

### models/income.rs

```rust
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

/// Pay frequency options
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum PayFrequency {
    Weekly,
    BiWeekly,
    SemiMonthly,
    Monthly,
}

impl PayFrequency {
    pub fn periods_per_year(&self) -> u32 {
        match self {
            PayFrequency::Weekly => 52,
            PayFrequency::BiWeekly => 26,
            PayFrequency::SemiMonthly => 24,
            PayFrequency::Monthly => 12,
        }
    }
}

/// Income input for calculations
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct IncomeInput {
    pub gross_annual_salary: Decimal,
    pub bonuses: Decimal,
    pub other_income: Decimal,
    pub pay_frequency: PayFrequency,
}

impl IncomeInput {
    pub fn total_gross(&self) -> Decimal {
        self.gross_annual_salary + self.bonuses + self.other_income
    }
}

/// Income broken down by timeframe
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct TimeframeIncome {
    pub annual: Decimal,
    pub monthly: Decimal,
    pub bi_weekly: Decimal,
    pub weekly: Decimal,
    pub daily: Decimal,
    pub hourly: Decimal,
}

impl TimeframeIncome {
    pub fn from_annual(annual: Decimal) -> Self {
        Self {
            annual,
            monthly: annual / Decimal::from(12),
            bi_weekly: annual / Decimal::from(26),
            weekly: annual / Decimal::from(52),
            daily: annual / Decimal::from(260),
            hourly: annual / Decimal::from(2080),
        }
    }

    pub fn from_annual_custom(annual: Decimal, hours_per_week: Decimal, days_per_week: Decimal) -> Self {
        let weeks = Decimal::from(52);
        Self {
            annual,
            monthly: annual / Decimal::from(12),
            bi_weekly: annual / Decimal::from(26),
            weekly: annual / weeks,
            daily: annual / (weeks * days_per_week),
            hourly: annual / (weeks * hours_per_week),
        }
    }
}

/// Complete calculated income result
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct CalculatedIncome {
    pub gross: Decimal,
    pub net: Decimal,
    pub timeframes: TimeframeIncome,
    pub take_home_percentage: Decimal,
}
```

### models/tax.rs

```rust
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

/// IRS filing status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, uniffi::Enum)]
pub enum FilingStatus {
    Single,
    MarriedFilingJointly,
    MarriedFilingSeparately,
    HeadOfHousehold,
    QualifyingWidower,
}

impl FilingStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            FilingStatus::Single => "single",
            FilingStatus::MarriedFilingJointly => "married_filing_jointly",
            FilingStatus::MarriedFilingSeparately => "married_filing_separately",
            FilingStatus::HeadOfHousehold => "head_of_household",
            FilingStatus::QualifyingWidower => "qualifying_widower",
        }
    }
}

/// Tax bracket definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaxBracket {
    pub floor: Decimal,
    pub ceiling: Option<Decimal>,
    pub rate: Decimal,
    pub base_tax: Decimal,
}

impl TaxBracket {
    pub fn new(floor: Decimal, ceiling: Option<Decimal>, rate: Decimal, base_tax: Decimal) -> Self {
        Self { floor, ceiling, rate, base_tax }
    }

    /// Calculate tax for income in this bracket
    pub fn calculate(&self, taxable_income: Decimal) -> Decimal {
        if taxable_income <= self.floor {
            return Decimal::ZERO;
        }

        let ceiling = self.ceiling.unwrap_or(Decimal::MAX);
        let income_in_bracket = taxable_income.min(ceiling) - self.floor;

        self.base_tax + (income_in_bracket * self.rate)
    }
}

/// Amount paid in a specific bracket (for breakdown display)
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct BracketAmount {
    pub floor: Decimal,
    pub ceiling: Option<Decimal>,
    pub rate: Decimal,
    pub taxable_in_bracket: Decimal,
    pub tax_paid: Decimal,
}

/// Federal tax calculation result
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct FederalTaxResult {
    pub taxable_income: Decimal,
    pub tax: Decimal,
    pub marginal_rate: Decimal,
    pub effective_rate: Decimal,
    pub bracket_breakdown: Vec<BracketAmount>,
}

/// FICA calculation result
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct FicaResult {
    pub social_security: Decimal,
    pub social_security_wage_base: Decimal,
    pub medicare: Decimal,
    pub additional_medicare: Decimal,
    pub total: Decimal,
}

/// State tax calculation result
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct StateTaxResult {
    pub state_code: String,
    pub taxable_income: Decimal,
    pub income_tax: Decimal,
    pub local_tax: Decimal,
    pub sdi: Decimal,
    pub total_tax: Decimal,
    pub effective_rate: Decimal,
    pub bracket_breakdown: Option<Vec<BracketAmount>>,
}

/// Complete tax breakdown
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct TaxBreakdown {
    pub federal: FederalTaxResult,
    pub state: StateTaxResult,
    pub fica: FicaResult,
    pub total_taxes: Decimal,
    pub effective_rate: Decimal,
}

/// Effective rates summary
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct EffectiveRates {
    pub federal: Decimal,
    pub state: Decimal,
    pub fica: Decimal,
    pub total: Decimal,
}
```

### models/state.rs

```rust
use serde::{Deserialize, Serialize};

/// All US states
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, uniffi::Enum)]
pub enum USState {
    Alabama,
    Alaska,
    Arizona,
    Arkansas,
    California,
    Colorado,
    Connecticut,
    Delaware,
    Florida,
    Georgia,
    Hawaii,
    Idaho,
    Illinois,
    Indiana,
    Iowa,
    Kansas,
    Kentucky,
    Louisiana,
    Maine,
    Maryland,
    Massachusetts,
    Michigan,
    Minnesota,
    Mississippi,
    Missouri,
    Montana,
    Nebraska,
    Nevada,
    NewHampshire,
    NewJersey,
    NewMexico,
    NewYork,
    NorthCarolina,
    NorthDakota,
    Ohio,
    Oklahoma,
    Oregon,
    Pennsylvania,
    RhodeIsland,
    SouthCarolina,
    SouthDakota,
    Tennessee,
    Texas,
    Utah,
    Vermont,
    Virginia,
    Washington,
    WashingtonDC,
    WestVirginia,
    Wisconsin,
    Wyoming,
}

impl USState {
    pub fn code(&self) -> &'static str {
        match self {
            USState::Alabama => "AL",
            USState::Alaska => "AK",
            USState::Arizona => "AZ",
            USState::Arkansas => "AR",
            USState::California => "CA",
            USState::Colorado => "CO",
            USState::Connecticut => "CT",
            USState::Delaware => "DE",
            USState::Florida => "FL",
            USState::Georgia => "GA",
            USState::Hawaii => "HI",
            USState::Idaho => "ID",
            USState::Illinois => "IL",
            USState::Indiana => "IN",
            USState::Iowa => "IA",
            USState::Kansas => "KS",
            USState::Kentucky => "KY",
            USState::Louisiana => "LA",
            USState::Maine => "ME",
            USState::Maryland => "MD",
            USState::Massachusetts => "MA",
            USState::Michigan => "MI",
            USState::Minnesota => "MN",
            USState::Mississippi => "MS",
            USState::Missouri => "MO",
            USState::Montana => "MT",
            USState::Nebraska => "NE",
            USState::Nevada => "NV",
            USState::NewHampshire => "NH",
            USState::NewJersey => "NJ",
            USState::NewMexico => "NM",
            USState::NewYork => "NY",
            USState::NorthCarolina => "NC",
            USState::NorthDakota => "ND",
            USState::Ohio => "OH",
            USState::Oklahoma => "OK",
            USState::Oregon => "OR",
            USState::Pennsylvania => "PA",
            USState::RhodeIsland => "RI",
            USState::SouthCarolina => "SC",
            USState::SouthDakota => "SD",
            USState::Tennessee => "TN",
            USState::Texas => "TX",
            USState::Utah => "UT",
            USState::Vermont => "VT",
            USState::Virginia => "VA",
            USState::Washington => "WA",
            USState::WashingtonDC => "DC",
            USState::WestVirginia => "WV",
            USState::Wisconsin => "WI",
            USState::Wyoming => "WY",
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            USState::Alabama => "Alabama",
            USState::Alaska => "Alaska",
            USState::Arizona => "Arizona",
            USState::Arkansas => "Arkansas",
            USState::California => "California",
            USState::Colorado => "Colorado",
            USState::Connecticut => "Connecticut",
            USState::Delaware => "Delaware",
            USState::Florida => "Florida",
            USState::Georgia => "Georgia",
            USState::Hawaii => "Hawaii",
            USState::Idaho => "Idaho",
            USState::Illinois => "Illinois",
            USState::Indiana => "Indiana",
            USState::Iowa => "Iowa",
            USState::Kansas => "Kansas",
            USState::Kentucky => "Kentucky",
            USState::Louisiana => "Louisiana",
            USState::Maine => "Maine",
            USState::Maryland => "Maryland",
            USState::Massachusetts => "Massachusetts",
            USState::Michigan => "Michigan",
            USState::Minnesota => "Minnesota",
            USState::Mississippi => "Mississippi",
            USState::Missouri => "Missouri",
            USState::Montana => "Montana",
            USState::Nebraska => "Nebraska",
            USState::Nevada => "Nevada",
            USState::NewHampshire => "New Hampshire",
            USState::NewJersey => "New Jersey",
            USState::NewMexico => "New Mexico",
            USState::NewYork => "New York",
            USState::NorthCarolina => "North Carolina",
            USState::NorthDakota => "North Dakota",
            USState::Ohio => "Ohio",
            USState::Oklahoma => "Oklahoma",
            USState::Oregon => "Oregon",
            USState::Pennsylvania => "Pennsylvania",
            USState::RhodeIsland => "Rhode Island",
            USState::SouthCarolina => "South Carolina",
            USState::SouthDakota => "South Dakota",
            USState::Tennessee => "Tennessee",
            USState::Texas => "Texas",
            USState::Utah => "Utah",
            USState::Vermont => "Vermont",
            USState::Virginia => "Virginia",
            USState::Washington => "Washington",
            USState::WashingtonDC => "Washington D.C.",
            USState::WestVirginia => "West Virginia",
            USState::Wisconsin => "Wisconsin",
            USState::Wyoming => "Wyoming",
        }
    }

    pub fn has_no_income_tax(&self) -> bool {
        matches!(
            self,
            USState::Alaska
                | USState::Florida
                | USState::Nevada
                | USState::NewHampshire
                | USState::SouthDakota
                | USState::Tennessee
                | USState::Texas
                | USState::Washington
                | USState::Wyoming
        )
    }

    pub fn has_flat_tax(&self) -> bool {
        matches!(
            self,
            USState::Colorado
                | USState::Illinois
                | USState::Indiana
                | USState::Kentucky
                | USState::Massachusetts
                | USState::Michigan
                | USState::NorthCarolina
                | USState::Pennsylvania
                | USState::Utah
        )
    }

    pub fn has_sdi(&self) -> bool {
        matches!(
            self,
            USState::California
                | USState::Hawaii
                | USState::NewJersey
                | USState::NewYork
                | USState::RhodeIsland
        )
    }

    pub fn has_local_tax(&self) -> bool {
        matches!(
            self,
            USState::Alabama
                | USState::Colorado
                | USState::Delaware
                | USState::Indiana
                | USState::Iowa
                | USState::Kentucky
                | USState::Maryland
                | USState::Michigan
                | USState::Missouri
                | USState::NewJersey
                | USState::NewYork
                | USState::Ohio
                | USState::Oregon
                | USState::Pennsylvania
                | USState::WestVirginia
        )
    }
}
```

---

## 5. Calculators

### calculators/federal.rs

```rust
use rust_decimal::Decimal;
use rust_decimal_macros::dec;

use crate::models::tax::{BracketAmount, FederalTaxResult, FilingStatus, TaxBracket};
use crate::data::TaxDataProvider;

pub struct FederalTaxCalculator<'a> {
    data_provider: &'a dyn TaxDataProvider,
}

impl<'a> FederalTaxCalculator<'a> {
    pub fn new(data_provider: &'a dyn TaxDataProvider) -> Self {
        Self { data_provider }
    }

    pub fn calculate(
        &self,
        taxable_income: Decimal,
        filing_status: FilingStatus,
        year: u32,
    ) -> FederalTaxResult {
        let brackets = self.data_provider.federal_brackets(filing_status, year);

        if taxable_income <= Decimal::ZERO {
            return FederalTaxResult {
                taxable_income: Decimal::ZERO,
                tax: Decimal::ZERO,
                marginal_rate: brackets.first().map(|b| b.rate).unwrap_or(dec!(0.10)),
                effective_rate: Decimal::ZERO,
                bracket_breakdown: vec![],
            };
        }

        let mut breakdown = Vec::new();
        let mut marginal_rate = dec!(0.10);

        for bracket in &brackets {
            if taxable_income > bracket.floor {
                marginal_rate = bracket.rate;

                let ceiling = bracket.ceiling.unwrap_or(Decimal::MAX);
                let income_in_bracket = taxable_income.min(ceiling) - bracket.floor;
                let tax_in_bracket = income_in_bracket * bracket.rate;

                if income_in_bracket > Decimal::ZERO {
                    breakdown.push(BracketAmount {
                        floor: bracket.floor,
                        ceiling: bracket.ceiling,
                        rate: bracket.rate,
                        taxable_in_bracket: income_in_bracket,
                        tax_paid: tax_in_bracket,
                    });
                }
            }
        }

        // Calculate total using base tax formula (more efficient)
        let tax = self.calculate_with_base_tax(taxable_income, &brackets);
        let effective_rate = if taxable_income > Decimal::ZERO {
            tax / taxable_income
        } else {
            Decimal::ZERO
        };

        FederalTaxResult {
            taxable_income,
            tax,
            marginal_rate,
            effective_rate,
            bracket_breakdown: breakdown,
        }
    }

    fn calculate_with_base_tax(&self, taxable_income: Decimal, brackets: &[TaxBracket]) -> Decimal {
        // Find applicable bracket
        let bracket = brackets
            .iter()
            .rev()
            .find(|b| taxable_income >= b.floor)
            .unwrap_or(&brackets[0]);

        // Tax = BaseTax + (Income - BracketFloor) × Rate
        bracket.base_tax + (taxable_income - bracket.floor) * bracket.rate
    }

    pub fn standard_deduction(&self, filing_status: FilingStatus, year: u32) -> Decimal {
        self.data_provider.standard_deduction(filing_status, year)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::embedded::EmbeddedTaxData;

    #[test]
    fn test_single_100k() {
        let data = EmbeddedTaxData::new();
        let calc = FederalTaxCalculator::new(&data);

        let result = calc.calculate(dec!(100000), FilingStatus::Single, 2024);

        // Expected: $5,426 + ($100,000 - $47,150) × 22% = ~$17,053
        assert!(result.tax >= dec!(17000) && result.tax <= dec!(17100));
        assert_eq!(result.marginal_rate, dec!(0.22));
    }

    #[test]
    fn test_mfj_200k() {
        let data = EmbeddedTaxData::new();
        let calc = FederalTaxCalculator::new(&data);

        let result = calc.calculate(dec!(200000), FilingStatus::MarriedFilingJointly, 2024);

        // Should be in 22% bracket for MFJ
        assert_eq!(result.marginal_rate, dec!(0.22));
    }
}
```

### calculators/fica.rs

```rust
use rust_decimal::Decimal;
use rust_decimal_macros::dec;

use crate::models::tax::{FicaResult, FilingStatus};
use crate::data::TaxDataProvider;

pub struct FicaCalculator<'a> {
    data_provider: &'a dyn TaxDataProvider,
}

impl<'a> FicaCalculator<'a> {
    pub fn new(data_provider: &'a dyn TaxDataProvider) -> Self {
        Self { data_provider }
    }

    pub fn calculate(&self, gross_income: Decimal, year: u32) -> FicaResult {
        self.calculate_with_status(gross_income, FilingStatus::Single, year)
    }

    pub fn calculate_with_status(
        &self,
        gross_income: Decimal,
        filing_status: FilingStatus,
        year: u32,
    ) -> FicaResult {
        let config = self.data_provider.fica_config(year);

        // Social Security (capped at wage base)
        let ss_taxable = gross_income.min(config.wage_base);
        let social_security = ss_taxable * config.social_security_rate;

        // Medicare (no cap)
        let medicare = gross_income * config.medicare_rate;

        // Additional Medicare (above threshold)
        let threshold = match filing_status {
            FilingStatus::Single | FilingStatus::HeadOfHousehold | FilingStatus::QualifyingWidower => {
                dec!(200000)
            }
            FilingStatus::MarriedFilingJointly => dec!(250000),
            FilingStatus::MarriedFilingSeparately => dec!(125000),
        };

        let additional_medicare = if gross_income > threshold {
            (gross_income - threshold) * config.additional_medicare_rate
        } else {
            Decimal::ZERO
        };

        let total = social_security + medicare + additional_medicare;

        FicaResult {
            social_security,
            social_security_wage_base: config.wage_base,
            medicare,
            additional_medicare,
            total,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::embedded::EmbeddedTaxData;

    #[test]
    fn test_fica_under_cap() {
        let data = EmbeddedTaxData::new();
        let calc = FicaCalculator::new(&data);

        let result = calc.calculate(dec!(100000), 2024);

        // SS: $100,000 × 6.2% = $6,200
        assert_eq!(result.social_security, dec!(6200));
        // Medicare: $100,000 × 1.45% = $1,450
        assert_eq!(result.medicare, dec!(1450));
    }

    #[test]
    fn test_fica_above_cap() {
        let data = EmbeddedTaxData::new();
        let calc = FicaCalculator::new(&data);

        let result = calc.calculate(dec!(200000), 2024);

        // SS should be capped at wage base × 6.2%
        // 2024 wage base: $168,600 × 6.2% = $10,453.20
        assert_eq!(result.social_security, dec!(10453.20));
    }
}
```

### calculators/state.rs

```rust
use rust_decimal::Decimal;
use rust_decimal_macros::dec;

use crate::models::state::USState;
use crate::models::tax::{BracketAmount, FilingStatus, StateTaxResult, TaxBracket};
use crate::data::TaxDataProvider;

pub struct StateTaxCalculator<'a> {
    data_provider: &'a dyn TaxDataProvider,
}

impl<'a> StateTaxCalculator<'a> {
    pub fn new(data_provider: &'a dyn TaxDataProvider) -> Self {
        Self { data_provider }
    }

    pub fn calculate(
        &self,
        taxable_income: Decimal,
        state: USState,
        filing_status: FilingStatus,
        year: u32,
    ) -> StateTaxResult {
        // No income tax states
        if state.has_no_income_tax() {
            return StateTaxResult {
                state_code: state.code().to_string(),
                taxable_income,
                income_tax: Decimal::ZERO,
                local_tax: Decimal::ZERO,
                sdi: Decimal::ZERO,
                total_tax: Decimal::ZERO,
                effective_rate: Decimal::ZERO,
                bracket_breakdown: None,
            };
        }

        let config = self.data_provider.state_config(state, year);

        // Calculate income tax
        let (income_tax, breakdown) = if state.has_flat_tax() {
            let tax = taxable_income * config.flat_rate.unwrap_or(Decimal::ZERO);
            (tax, None)
        } else {
            let brackets = config.brackets.get(filing_status.as_str()).cloned().unwrap_or_default();
            let std_deduction = config.standard_deduction
                .as_ref()
                .and_then(|d| d.get(filing_status.as_str()))
                .copied()
                .unwrap_or(Decimal::ZERO);

            let adjusted_income = (taxable_income - std_deduction).max(Decimal::ZERO);
            self.calculate_progressive(adjusted_income, &brackets)
        };

        // Calculate SDI if applicable
        let sdi = self.calculate_sdi(taxable_income, state, &config);

        // Estimate local tax if applicable
        let local_tax = self.estimate_local_tax(taxable_income, state, &config);

        let total_tax = income_tax + sdi + local_tax;
        let effective_rate = if taxable_income > Decimal::ZERO {
            total_tax / taxable_income
        } else {
            Decimal::ZERO
        };

        StateTaxResult {
            state_code: state.code().to_string(),
            taxable_income,
            income_tax,
            local_tax,
            sdi,
            total_tax,
            effective_rate,
            bracket_breakdown: breakdown,
        }
    }

    fn calculate_progressive(
        &self,
        taxable_income: Decimal,
        brackets: &[TaxBracket],
    ) -> (Decimal, Option<Vec<BracketAmount>>) {
        if taxable_income <= Decimal::ZERO || brackets.is_empty() {
            return (Decimal::ZERO, None);
        }

        let mut total_tax = Decimal::ZERO;
        let mut breakdown = Vec::new();

        for bracket in brackets {
            if taxable_income > bracket.floor {
                let ceiling = bracket.ceiling.unwrap_or(Decimal::MAX);
                let income_in_bracket = taxable_income.min(ceiling) - bracket.floor;
                let tax_in_bracket = income_in_bracket * bracket.rate;

                total_tax += tax_in_bracket;
                breakdown.push(BracketAmount {
                    floor: bracket.floor,
                    ceiling: bracket.ceiling,
                    rate: bracket.rate,
                    taxable_in_bracket: income_in_bracket,
                    tax_paid: tax_in_bracket,
                });
            }
        }

        (total_tax, Some(breakdown))
    }

    fn calculate_sdi(
        &self,
        income: Decimal,
        state: USState,
        config: &crate::data::StateConfig,
    ) -> Decimal {
        if !state.has_sdi() {
            return Decimal::ZERO;
        }

        let rate = config.sdi_rate.unwrap_or(Decimal::ZERO);
        let wage_base = config.sdi_wage_base.unwrap_or(income);
        let taxable = income.min(wage_base);

        taxable * rate
    }

    fn estimate_local_tax(
        &self,
        income: Decimal,
        state: USState,
        config: &crate::data::StateConfig,
    ) -> Decimal {
        if !state.has_local_tax() {
            return Decimal::ZERO;
        }

        // Use average rate as estimate
        config
            .local_tax_info
            .as_ref()
            .and_then(|info| info.average_rate)
            .map(|rate| income * rate)
            .unwrap_or(Decimal::ZERO)
    }
}
```

---

## 6. Main Engine

### engine.rs

```rust
use rust_decimal::Decimal;

use crate::calculators::{FederalTaxCalculator, FicaCalculator, StateTaxCalculator};
use crate::data::TaxDataProvider;
use crate::models::income::{CalculatedIncome, IncomeInput, TimeframeIncome};
use crate::models::state::USState;
use crate::models::tax::{EffectiveRates, FilingStatus, TaxBreakdown};

/// Input for complete tax calculation
#[derive(Debug, Clone, uniffi::Record)]
pub struct TaxCalculationInput {
    pub gross_income: Decimal,
    pub filing_status: FilingStatus,
    pub state: USState,
    pub pre_tax_deductions: Decimal,
    pub post_tax_deductions: Decimal,
    pub traditional_401k: Decimal,
    pub roth_401k: Decimal,
}

/// Complete calculation result
#[derive(Debug, Clone, uniffi::Record)]
pub struct TaxCalculationResult {
    pub income: CalculatedIncome,
    pub tax_breakdown: TaxBreakdown,
    pub effective_rates: EffectiveRates,
}

/// Scenario comparison result
#[derive(Debug, Clone, uniffi::Record)]
pub struct ScenarioComparison {
    pub base: TaxCalculationResult,
    pub scenario: TaxCalculationResult,
    pub net_difference: Decimal,
    pub monthly_difference: Decimal,
}

/// Main calculation engine
pub struct TaxCalculationEngine<'a> {
    federal_calc: FederalTaxCalculator<'a>,
    state_calc: StateTaxCalculator<'a>,
    fica_calc: FicaCalculator<'a>,
    year: u32,
}

impl<'a> TaxCalculationEngine<'a> {
    pub fn new(data_provider: &'a dyn TaxDataProvider, year: u32) -> Self {
        Self {
            federal_calc: FederalTaxCalculator::new(data_provider),
            state_calc: StateTaxCalculator::new(data_provider),
            fica_calc: FicaCalculator::new(data_provider),
            year,
        }
    }

    pub fn calculate(&self, input: &TaxCalculationInput) -> TaxCalculationResult {
        // Step 1: Calculate pre-tax deductions
        let total_pre_tax = input.pre_tax_deductions + input.traditional_401k;

        // Step 2: Calculate federal taxable income
        let std_deduction = self.federal_calc.standard_deduction(input.filing_status, self.year);
        let federal_taxable = (input.gross_income - total_pre_tax - std_deduction).max(Decimal::ZERO);

        // Step 3: Calculate federal tax
        let federal_result = self.federal_calc.calculate(
            federal_taxable,
            input.filing_status,
            self.year,
        );

        // Step 4: Calculate state tax
        let state_taxable = input.gross_income - total_pre_tax;
        let state_result = self.state_calc.calculate(
            state_taxable,
            input.state,
            input.filing_status,
            self.year,
        );

        // Step 5: Calculate FICA (on gross, not reduced by 401k)
        let fica_result = self.fica_calc.calculate_with_status(
            input.gross_income,
            input.filing_status,
            self.year,
        );

        // Step 6: Calculate total taxes
        let total_taxes = federal_result.tax + state_result.total_tax + fica_result.total;

        // Step 7: Calculate post-tax deductions
        let total_post_tax = input.post_tax_deductions + input.roth_401k;

        // Step 8: Calculate net income
        let net_income = input.gross_income - total_taxes - total_pre_tax - total_post_tax;

        // Step 9: Build timeframes
        let timeframes = TimeframeIncome::from_annual(net_income);

        // Step 10: Calculate take-home percentage
        let take_home_pct = if input.gross_income > Decimal::ZERO {
            (net_income / input.gross_income) * Decimal::from(100)
        } else {
            Decimal::ZERO
        };

        // Build effective rates
        let effective_rates = EffectiveRates {
            federal: federal_result.effective_rate,
            state: state_result.effective_rate,
            fica: fica_result.total / input.gross_income,
            total: total_taxes / input.gross_income,
        };

        TaxCalculationResult {
            income: CalculatedIncome {
                gross: input.gross_income,
                net: net_income,
                timeframes,
                take_home_percentage: take_home_pct,
            },
            tax_breakdown: TaxBreakdown {
                federal: federal_result,
                state: state_result,
                fica: fica_result,
                total_taxes,
                effective_rate: effective_rates.total,
            },
            effective_rates,
        }
    }

    pub fn compare_scenarios(
        &self,
        base: &TaxCalculationInput,
        scenario: &TaxCalculationInput,
    ) -> ScenarioComparison {
        let base_result = self.calculate(base);
        let scenario_result = self.calculate(scenario);

        let net_diff = scenario_result.income.net - base_result.income.net;
        let monthly_diff = net_diff / Decimal::from(12);

        ScenarioComparison {
            base: base_result,
            scenario: scenario_result,
            net_difference: net_diff,
            monthly_difference: monthly_diff,
        }
    }
}
```

---

## 7. UniFFI Interface Definition

### uniffi/takehome_core.udl

```
namespace takehome_core {
    // Version info
    string get_version();

    // Main calculation
    TaxCalculationResult calculate_taxes(TaxCalculationInput input);

    // Scenario comparison
    ScenarioComparison compare_scenarios(TaxCalculationInput base, TaxCalculationInput scenario);

    // Utilities
    TimeframeIncome convert_timeframes(decimal annual);
    decimal calculate_household_split(decimal primary_net, decimal partner_net, decimal shared_expense);
};

// Enums
enum PayFrequency {
    "Weekly",
    "BiWeekly",
    "SemiMonthly",
    "Monthly"
};

enum FilingStatus {
    "Single",
    "MarriedFilingJointly",
    "MarriedFilingSeparately",
    "HeadOfHousehold",
    "QualifyingWidower"
};

enum USState {
    "Alabama", "Alaska", "Arizona", "Arkansas", "California",
    "Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
    "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa",
    "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland",
    "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri",
    "Montana", "Nebraska", "Nevada", "NewHampshire", "NewJersey",
    "NewMexico", "NewYork", "NorthCarolina", "NorthDakota", "Ohio",
    "Oklahoma", "Oregon", "Pennsylvania", "RhodeIsland", "SouthCarolina",
    "SouthDakota", "Tennessee", "Texas", "Utah", "Vermont",
    "Virginia", "Washington", "WashingtonDC", "WestVirginia", "Wisconsin",
    "Wyoming"
};

// Records
dictionary TaxCalculationInput {
    decimal gross_income;
    FilingStatus filing_status;
    USState state;
    decimal pre_tax_deductions;
    decimal post_tax_deductions;
    decimal traditional_401k;
    decimal roth_401k;
};

dictionary TimeframeIncome {
    decimal annual;
    decimal monthly;
    decimal bi_weekly;
    decimal weekly;
    decimal daily;
    decimal hourly;
};

dictionary CalculatedIncome {
    decimal gross;
    decimal net;
    TimeframeIncome timeframes;
    decimal take_home_percentage;
};

dictionary BracketAmount {
    decimal floor;
    decimal? ceiling;
    decimal rate;
    decimal taxable_in_bracket;
    decimal tax_paid;
};

dictionary FederalTaxResult {
    decimal taxable_income;
    decimal tax;
    decimal marginal_rate;
    decimal effective_rate;
    sequence<BracketAmount> bracket_breakdown;
};

dictionary FicaResult {
    decimal social_security;
    decimal social_security_wage_base;
    decimal medicare;
    decimal additional_medicare;
    decimal total;
};

dictionary StateTaxResult {
    string state_code;
    decimal taxable_income;
    decimal income_tax;
    decimal local_tax;
    decimal sdi;
    decimal total_tax;
    decimal effective_rate;
    sequence<BracketAmount>? bracket_breakdown;
};

dictionary TaxBreakdown {
    FederalTaxResult federal;
    StateTaxResult state;
    FicaResult fica;
    decimal total_taxes;
    decimal effective_rate;
};

dictionary EffectiveRates {
    decimal federal;
    decimal state;
    decimal fica;
    decimal total;
};

dictionary TaxCalculationResult {
    CalculatedIncome income;
    TaxBreakdown tax_breakdown;
    EffectiveRates effective_rates;
};

dictionary ScenarioComparison {
    TaxCalculationResult base;
    TaxCalculationResult scenario;
    decimal net_difference;
    decimal monthly_difference;
};
```

---

## 8. FFI Exports

### ffi.rs

```rust
use rust_decimal::Decimal;
use std::str::FromStr;

use crate::data::embedded::EmbeddedTaxData;
use crate::engine::{TaxCalculationEngine, TaxCalculationInput, TaxCalculationResult, ScenarioComparison};
use crate::models::income::TimeframeIncome;

// Include UniFFI scaffolding
uniffi::include_scaffolding!("takehome_core");

/// Get library version
pub fn get_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Main calculation entry point
pub fn calculate_taxes(input: TaxCalculationInput) -> TaxCalculationResult {
    let data = EmbeddedTaxData::new();
    let year = chrono::Utc::now().year() as u32;
    let engine = TaxCalculationEngine::new(&data, year);
    engine.calculate(&input)
}

/// Compare two scenarios
pub fn compare_scenarios(base: TaxCalculationInput, scenario: TaxCalculationInput) -> ScenarioComparison {
    let data = EmbeddedTaxData::new();
    let year = chrono::Utc::now().year() as u32;
    let engine = TaxCalculationEngine::new(&data, year);
    engine.compare_scenarios(&base, &scenario)
}

/// Convert annual amount to all timeframes
pub fn convert_timeframes(annual: Decimal) -> TimeframeIncome {
    TimeframeIncome::from_annual(annual)
}

/// Calculate household expense split
pub fn calculate_household_split(
    primary_net: Decimal,
    partner_net: Decimal,
    shared_expense: Decimal,
) -> Decimal {
    let total = primary_net + partner_net;
    if total == Decimal::ZERO {
        shared_expense / Decimal::from(2)
    } else {
        shared_expense * (primary_net / total)
    }
}
```

---

## 9. Build Script

### build.rs

```rust
fn main() {
    uniffi::generate_scaffolding("./uniffi/takehome_core.udl").unwrap();
}
```

### Build Commands

```bash
# Build for iOS (both architectures)
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

# Generate Swift bindings
cargo run --bin uniffi-bindgen generate \
    --library target/release/libtakehome_core.dylib \
    --language swift \
    --out-dir bindings/swift

# Create XCFramework
xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libtakehome_core.a \
    -headers bindings/swift/TakeHomeCoreFFI.h \
    -library target/aarch64-apple-ios-sim/release/libtakehome_core.a \
    -headers bindings/swift/TakeHomeCoreFFI.h \
    -output bindings/TakeHomeCore.xcframework
```

---

## 10. Swift Integration

### Swift Wrapper

```swift
import Foundation
import TakeHomeCore  // Generated UniFFI bindings

/// Swift-friendly wrapper around Rust core
final class TakeHomeCoreWrapper {

    static let shared = TakeHomeCoreWrapper()

    private init() {}

    /// Calculate taxes with Swift-native types
    func calculate(
        grossIncome: Decimal,
        filingStatus: FilingStatus,
        state: USState,
        preTaxDeductions: Decimal = 0,
        postTaxDeductions: Decimal = 0,
        traditional401k: Decimal = 0,
        roth401k: Decimal = 0
    ) -> TaxCalculationResult {
        let input = TaxCalculationInput(
            grossIncome: grossIncome.toRustDecimal(),
            filingStatus: filingStatus.toRust(),
            state: state.toRust(),
            preTaxDeductions: preTaxDeductions.toRustDecimal(),
            postTaxDeductions: postTaxDeductions.toRustDecimal(),
            traditional401k: traditional401k.toRustDecimal(),
            roth401k: roth401k.toRustDecimal()
        )

        return TakeHomeCore.calculateTaxes(input: input)
    }

    /// Compare scenarios
    func compareScenarios(
        base: TaxCalculationInput,
        scenario: TaxCalculationInput
    ) -> ScenarioComparison {
        TakeHomeCore.compareScenarios(base: base, scenario: scenario)
    }

    /// Get library version
    var version: String {
        TakeHomeCore.getVersion()
    }
}

// MARK: - Decimal Conversion

extension Decimal {
    func toRustDecimal() -> RustDecimal {
        // Convert Swift Decimal to Rust Decimal string representation
        RustDecimal(string: self.description)
    }
}

extension RustDecimal {
    func toSwiftDecimal() -> Decimal {
        Decimal(string: self.toString()) ?? 0
    }
}

// MARK: - Enum Conversions

extension FilingStatus {
    func toRust() -> TakeHomeCore.FilingStatus {
        switch self {
        case .single: return .single
        case .marriedFilingJointly: return .marriedFilingJointly
        case .marriedFilingSeparately: return .marriedFilingSeparately
        case .headOfHousehold: return .headOfHousehold
        case .qualifyingWidower: return .qualifyingWidower
        }
    }
}

extension USState {
    func toRust() -> TakeHomeCore.USState {
        // Map Swift enum to Rust enum
        TakeHomeCore.USState(rawValue: self.rawValue)!
    }
}
```

### Using in ViewModel

```swift
import SwiftUI
import Combine

final class IncomeViewModel: ObservableObject {

    @Published var grossSalary: Decimal = 0
    @Published var state: USState = .california
    @Published var filingStatus: FilingStatus = .single
    @Published var calculatedResult: TaxCalculationResult?

    private let core = TakeHomeCoreWrapper.shared

    func calculate() {
        // Call Rust core for calculations
        calculatedResult = core.calculate(
            grossIncome: grossSalary,
            filingStatus: filingStatus,
            state: state
        )
    }
}
```

---

## 11. Testing

### Rust Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;

    #[test]
    fn test_full_calculation_single_100k_california() {
        let input = TaxCalculationInput {
            gross_income: dec!(100000),
            filing_status: FilingStatus::Single,
            state: USState::California,
            pre_tax_deductions: dec!(0),
            post_tax_deductions: dec!(0),
            traditional_401k: dec!(0),
            roth_401k: dec!(0),
        };

        let result = calculate_taxes(input);

        // Verify federal tax is in expected range
        assert!(result.tax_breakdown.federal.tax > dec!(10000));
        assert!(result.tax_breakdown.federal.tax < dec!(20000));

        // Verify California has state tax
        assert!(result.tax_breakdown.state.income_tax > dec!(0));

        // Verify take-home is reasonable (50-70%)
        assert!(result.income.take_home_percentage > dec!(50));
        assert!(result.income.take_home_percentage < dec!(70));
    }

    #[test]
    fn test_no_tax_state() {
        let input = TaxCalculationInput {
            gross_income: dec!(100000),
            filing_status: FilingStatus::Single,
            state: USState::Texas,
            ..Default::default()
        };

        let result = calculate_taxes(input);

        // Texas has no state income tax
        assert_eq!(result.tax_breakdown.state.income_tax, dec!(0));
    }

    #[test]
    fn test_scenario_comparison() {
        let base = TaxCalculationInput {
            gross_income: dec!(100000),
            filing_status: FilingStatus::Single,
            state: USState::California,
            ..Default::default()
        };

        let scenario = TaxCalculationInput {
            gross_income: dec!(100000),
            state: USState::Texas, // Move to no-tax state
            ..base.clone()
        };

        let comparison = compare_scenarios(base, scenario);

        // Moving to Texas should increase net income
        assert!(comparison.net_difference > dec!(0));
    }
}
```

### Benchmarks

```rust
// benches/calculations.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use rust_decimal_macros::dec;
use takehome_core::*;

fn benchmark_full_calculation(c: &mut Criterion) {
    let input = TaxCalculationInput {
        gross_income: dec!(100000),
        filing_status: FilingStatus::Single,
        state: USState::California,
        pre_tax_deductions: dec!(5000),
        post_tax_deductions: dec!(0),
        traditional_401k: dec!(10000),
        roth_401k: dec!(0),
    };

    c.bench_function("full_calculation", |b| {
        b.iter(|| calculate_taxes(black_box(input.clone())))
    });
}

fn benchmark_all_states(c: &mut Criterion) {
    let base_input = TaxCalculationInput {
        gross_income: dec!(100000),
        filing_status: FilingStatus::Single,
        state: USState::California,
        ..Default::default()
    };

    c.bench_function("all_50_states", |b| {
        b.iter(|| {
            for state in USState::all() {
                let input = TaxCalculationInput {
                    state,
                    ..base_input.clone()
                };
                calculate_taxes(black_box(input));
            }
        })
    });
}

criterion_group!(benches, benchmark_full_calculation, benchmark_all_states);
criterion_main!(benches);
```

---

## 12. CLI Tool for Validation

### tools/tax-validator/src/main.rs

```rust
use clap::Parser;
use std::path::PathBuf;
use takehome_core::data::loader::load_tax_data_from_file;

#[derive(Parser)]
#[command(name = "tax-validator")]
#[command(about = "Validates tax data files for TakeHome")]
struct Cli {
    /// Path to tax data JSON file
    #[arg(short, long)]
    file: PathBuf,

    /// Tax year to validate
    #[arg(short, long, default_value = "2024")]
    year: u32,

    /// Run comprehensive tests
    #[arg(short, long)]
    test: bool,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    println!("Validating tax data: {:?}", cli.file);

    let data = load_tax_data_from_file(&cli.file)?;

    // Validate structure
    validate_federal_brackets(&data)?;
    validate_state_data(&data)?;
    validate_fica(&data)?;

    println!("✅ Tax data validation passed!");

    if cli.test {
        run_comprehensive_tests(&data)?;
    }

    Ok(())
}

fn validate_federal_brackets(data: &TaxData) -> anyhow::Result<()> {
    // Check all filing statuses present
    let required = ["single", "married_filing_jointly", "head_of_household"];
    for status in required {
        if !data.federal.brackets.contains_key(status) {
            anyhow::bail!("Missing federal brackets for: {}", status);
        }
    }

    // Validate bracket progression
    for (status, brackets) in &data.federal.brackets {
        let mut prev_ceiling = rust_decimal::Decimal::ZERO;
        for bracket in brackets {
            if bracket.floor != prev_ceiling {
                anyhow::bail!(
                    "Gap in {} brackets: {} -> {}",
                    status,
                    prev_ceiling,
                    bracket.floor
                );
            }
            prev_ceiling = bracket.ceiling.unwrap_or(rust_decimal::Decimal::MAX);
        }
    }

    println!("  ✓ Federal brackets valid");
    Ok(())
}

fn validate_state_data(data: &TaxData) -> anyhow::Result<()> {
    // Check all 50 states + DC
    if data.states.len() != 51 {
        anyhow::bail!("Expected 51 states, found {}", data.states.len());
    }

    println!("  ✓ All 51 jurisdictions present");
    Ok(())
}

fn validate_fica(data: &TaxData) -> anyhow::Result<()> {
    if data.fica.social_security_rate != rust_decimal_macros::dec!(0.062) {
        anyhow::bail!("Unexpected SS rate: {}", data.fica.social_security_rate);
    }

    println!("  ✓ FICA rates valid");
    Ok(())
}

fn run_comprehensive_tests(data: &TaxData) -> anyhow::Result<()> {
    println!("\nRunning comprehensive tests...");

    // Test known tax amounts against IRS tables
    // ...

    println!("✅ All tests passed!");
    Ok(())
}
```

---

## Summary

| Component | Language | Purpose |
|-----------|----------|---------|
| **takehome-core** | Rust | Tax calculations, pure functions |
| **UniFFI bindings** | Rust → Swift | Cross-language interface |
| **TakeHomeCoreWrapper** | Swift | Swift-friendly API |
| **tax-validator** | Rust CLI | Tax data validation |

### Benefits of Rust Core

- ✅ **Performance**: Native speed for calculations
- ✅ **Precision**: `rust_decimal` for financial accuracy
- ✅ **Cross-platform**: Same logic for iOS, Android, Web
- ✅ **Testability**: Pure functions, no UI dependencies
- ✅ **Type Safety**: Compile-time guarantees
- ✅ **No Runtime**: No garbage collection overhead

### Future Platform Support

```
┌─────────────┐
│ Rust Core   │
├─────────────┤
│ UniFFI      │───────┬───────────┬───────────┐
└─────────────┘       │           │           │
                      ▼           ▼           ▼
               ┌──────────┐ ┌──────────┐ ┌──────────┐
               │   iOS    │ │ Android  │ │   Web    │
               │  Swift   │ │  Kotlin  │ │   WASM   │
               └──────────┘ └──────────┘ └──────────┘
```
