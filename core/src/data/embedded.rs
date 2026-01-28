//! Embedded tax data for 2024

use once_cell::sync::Lazy;
use rust_decimal::Decimal;
use rust_decimal_macros::dec;
use std::collections::HashMap;

use super::{FicaConfig, LocalTaxInfo, StateConfig, StateTaxType, TaxDataProvider};
use crate::models::state::USState;
use crate::models::tax::{FilingStatus, TaxBracket};

/// Embedded tax data provider with 2024 rates
pub struct EmbeddedTaxData {
    federal_brackets: HashMap<FilingStatus, Vec<TaxBracket>>,
    standard_deductions: HashMap<FilingStatus, Decimal>,
    fica_config: FicaConfig,
    state_configs: HashMap<USState, StateConfig>,
}

impl EmbeddedTaxData {
    pub fn new() -> Self {
        Self {
            federal_brackets: build_federal_brackets_2024(),
            standard_deductions: build_standard_deductions_2024(),
            fica_config: build_fica_config_2024(),
            state_configs: build_state_configs_2024(),
        }
    }
}

impl Default for EmbeddedTaxData {
    fn default() -> Self {
        Self::new()
    }
}

impl TaxDataProvider for EmbeddedTaxData {
    fn federal_brackets(&self, filing_status: FilingStatus, _year: u32) -> Vec<TaxBracket> {
        self.federal_brackets
            .get(&filing_status)
            .cloned()
            .unwrap_or_default()
    }

    fn standard_deduction(&self, filing_status: FilingStatus, _year: u32) -> Decimal {
        self.standard_deductions
            .get(&filing_status)
            .copied()
            .unwrap_or(dec!(14600))
    }

    fn fica_config(&self, _year: u32) -> FicaConfig {
        self.fica_config.clone()
    }

    fn state_config(&self, state: USState, _year: u32) -> StateConfig {
        self.state_configs
            .get(&state)
            .cloned()
            .unwrap_or_else(|| StateConfig {
                state_code: state.code().to_string(),
                tax_type: StateTaxType::NoTax,
                ..Default::default()
            })
    }
}

// Static instance for global access
static EMBEDDED_DATA: Lazy<EmbeddedTaxData> = Lazy::new(EmbeddedTaxData::new);

/// Get the global embedded tax data instance
pub fn get_embedded_data() -> &'static EmbeddedTaxData {
    &EMBEDDED_DATA
}

// ============================================================================
// 2024 Federal Tax Brackets
// ============================================================================

fn build_federal_brackets_2024() -> HashMap<FilingStatus, Vec<TaxBracket>> {
    let mut brackets = HashMap::new();

    // Single
    brackets.insert(
        FilingStatus::Single,
        vec![
            TaxBracket::new(dec!(0), Some(dec!(11600)), dec!(0.10), dec!(0)),
            TaxBracket::new(dec!(11600), Some(dec!(47150)), dec!(0.12), dec!(1160)),
            TaxBracket::new(dec!(47150), Some(dec!(100525)), dec!(0.22), dec!(5426)),
            TaxBracket::new(dec!(100525), Some(dec!(191950)), dec!(0.24), dec!(17168.50)),
            TaxBracket::new(dec!(191950), Some(dec!(243725)), dec!(0.32), dec!(39110.50)),
            TaxBracket::new(dec!(243725), Some(dec!(609350)), dec!(0.35), dec!(55678.50)),
            TaxBracket::new(dec!(609350), None, dec!(0.37), dec!(183647.25)),
        ],
    );

    // Married Filing Jointly
    brackets.insert(
        FilingStatus::MarriedFilingJointly,
        vec![
            TaxBracket::new(dec!(0), Some(dec!(23200)), dec!(0.10), dec!(0)),
            TaxBracket::new(dec!(23200), Some(dec!(94300)), dec!(0.12), dec!(2320)),
            TaxBracket::new(dec!(94300), Some(dec!(201050)), dec!(0.22), dec!(10852)),
            TaxBracket::new(dec!(201050), Some(dec!(383900)), dec!(0.24), dec!(34337)),
            TaxBracket::new(dec!(383900), Some(dec!(487450)), dec!(0.32), dec!(78221)),
            TaxBracket::new(dec!(487450), Some(dec!(731200)), dec!(0.35), dec!(111357)),
            TaxBracket::new(dec!(731200), None, dec!(0.37), dec!(196669.50)),
        ],
    );

    // Married Filing Separately
    brackets.insert(
        FilingStatus::MarriedFilingSeparately,
        vec![
            TaxBracket::new(dec!(0), Some(dec!(11600)), dec!(0.10), dec!(0)),
            TaxBracket::new(dec!(11600), Some(dec!(47150)), dec!(0.12), dec!(1160)),
            TaxBracket::new(dec!(47150), Some(dec!(100525)), dec!(0.22), dec!(5426)),
            TaxBracket::new(dec!(100525), Some(dec!(191950)), dec!(0.24), dec!(17168.50)),
            TaxBracket::new(dec!(191950), Some(dec!(243725)), dec!(0.32), dec!(39110.50)),
            TaxBracket::new(dec!(243725), Some(dec!(365600)), dec!(0.35), dec!(55678.50)),
            TaxBracket::new(dec!(365600), None, dec!(0.37), dec!(98334.75)),
        ],
    );

    // Head of Household
    brackets.insert(
        FilingStatus::HeadOfHousehold,
        vec![
            TaxBracket::new(dec!(0), Some(dec!(16550)), dec!(0.10), dec!(0)),
            TaxBracket::new(dec!(16550), Some(dec!(63100)), dec!(0.12), dec!(1655)),
            TaxBracket::new(dec!(63100), Some(dec!(100500)), dec!(0.22), dec!(7241)),
            TaxBracket::new(dec!(100500), Some(dec!(191950)), dec!(0.24), dec!(15469)),
            TaxBracket::new(dec!(191950), Some(dec!(243700)), dec!(0.32), dec!(37417)),
            TaxBracket::new(dec!(243700), Some(dec!(609350)), dec!(0.35), dec!(53977)),
            TaxBracket::new(dec!(609350), None, dec!(0.37), dec!(181954.50)),
        ],
    );

    // Qualifying Widower (same as MFJ)
    brackets.insert(
        FilingStatus::QualifyingWidower,
        brackets
            .get(&FilingStatus::MarriedFilingJointly)
            .unwrap()
            .clone(),
    );

    brackets
}

fn build_standard_deductions_2024() -> HashMap<FilingStatus, Decimal> {
    let mut deductions = HashMap::new();
    deductions.insert(FilingStatus::Single, dec!(14600));
    deductions.insert(FilingStatus::MarriedFilingJointly, dec!(29200));
    deductions.insert(FilingStatus::MarriedFilingSeparately, dec!(14600));
    deductions.insert(FilingStatus::HeadOfHousehold, dec!(21900));
    deductions.insert(FilingStatus::QualifyingWidower, dec!(29200));
    deductions
}

fn build_fica_config_2024() -> FicaConfig {
    FicaConfig {
        social_security_rate: dec!(0.062),
        wage_base: dec!(168600),
        medicare_rate: dec!(0.0145),
        additional_medicare_rate: dec!(0.009),
    }
}

// ============================================================================
// 2024 State Tax Configurations
// ============================================================================

fn build_state_configs_2024() -> HashMap<USState, StateConfig> {
    let mut configs = HashMap::new();

    // No income tax states
    for state in [
        USState::Alaska,
        USState::Florida,
        USState::Nevada,
        USState::NewHampshire,
        USState::SouthDakota,
        USState::Tennessee,
        USState::Texas,
        USState::Washington,
        USState::Wyoming,
    ] {
        configs.insert(
            state,
            StateConfig {
                state_code: state.code().to_string(),
                tax_type: StateTaxType::NoTax,
                ..Default::default()
            },
        );
    }

    // Flat tax states
    configs.insert(USState::Colorado, flat_tax_config("CO", dec!(0.044)));
    configs.insert(USState::Illinois, flat_tax_config("IL", dec!(0.0495)));
    configs.insert(USState::Indiana, flat_tax_config("IN", dec!(0.0305)));
    configs.insert(USState::Kentucky, flat_tax_config("KY", dec!(0.04)));
    configs.insert(USState::Massachusetts, flat_tax_config("MA", dec!(0.05)));
    configs.insert(USState::Michigan, flat_tax_config("MI", dec!(0.0425)));
    configs.insert(USState::NorthCarolina, flat_tax_config("NC", dec!(0.0525)));
    configs.insert(USState::Pennsylvania, flat_tax_config("PA", dec!(0.0307)));
    configs.insert(USState::Utah, flat_tax_config("UT", dec!(0.0465)));

    // California - progressive with SDI
    configs.insert(USState::California, california_config());

    // New York - progressive with potential local tax
    configs.insert(USState::NewYork, new_york_config());

    // Add other progressive states...
    configs.insert(USState::Arizona, arizona_config());
    configs.insert(USState::Georgia, georgia_config());
    configs.insert(USState::Minnesota, minnesota_config());
    configs.insert(USState::NewJersey, new_jersey_config());
    configs.insert(USState::Oregon, oregon_config());
    configs.insert(USState::Virginia, virginia_config());

    // Default config for remaining states (simplified)
    for state in USState::all() {
        if !configs.contains_key(state) {
            configs.insert(
                *state,
                StateConfig {
                    state_code: state.code().to_string(),
                    tax_type: StateTaxType::Progressive,
                    brackets: default_brackets(state),
                    ..Default::default()
                },
            );
        }
    }

    configs
}

fn flat_tax_config(code: &str, rate: Decimal) -> StateConfig {
    StateConfig {
        state_code: code.to_string(),
        tax_type: StateTaxType::FlatRate,
        flat_rate: Some(rate),
        ..Default::default()
    }
}

fn california_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(10412)), dec!(0.01), dec!(0)),
            TaxBracket::new(dec!(10412), Some(dec!(24684)), dec!(0.02), dec!(104.12)),
            TaxBracket::new(dec!(24684), Some(dec!(38959)), dec!(0.04), dec!(389.56)),
            TaxBracket::new(dec!(38959), Some(dec!(54081)), dec!(0.06), dec!(960.56)),
            TaxBracket::new(dec!(54081), Some(dec!(68350)), dec!(0.08), dec!(1867.88)),
            TaxBracket::new(dec!(68350), Some(dec!(349137)), dec!(0.093), dec!(3009.40)),
            TaxBracket::new(
                dec!(349137),
                Some(dec!(418961)),
                dec!(0.103),
                dec!(29122.59),
            ),
            TaxBracket::new(
                dec!(418961),
                Some(dec!(698271)),
                dec!(0.113),
                dec!(36314.46),
            ),
            TaxBracket::new(
                dec!(698271),
                Some(dec!(1000000)),
                dec!(0.123),
                dec!(67876.49),
            ),
            TaxBracket::new(dec!(1000000), None, dec!(0.133), dec!(104989.12)),
        ],
    );

    // MFJ brackets (doubled)
    brackets.insert(
        "married_filing_jointly".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(20824)), dec!(0.01), dec!(0)),
            TaxBracket::new(dec!(20824), Some(dec!(49368)), dec!(0.02), dec!(208.24)),
            TaxBracket::new(dec!(49368), Some(dec!(77918)), dec!(0.04), dec!(779.12)),
            TaxBracket::new(dec!(77918), Some(dec!(108162)), dec!(0.06), dec!(1921.12)),
            TaxBracket::new(dec!(108162), Some(dec!(136700)), dec!(0.08), dec!(3735.76)),
            TaxBracket::new(dec!(136700), Some(dec!(698274)), dec!(0.093), dec!(6018.80)),
            TaxBracket::new(
                dec!(698274),
                Some(dec!(837922)),
                dec!(0.103),
                dec!(58245.18),
            ),
            TaxBracket::new(
                dec!(837922),
                Some(dec!(1396542)),
                dec!(0.113),
                dec!(72628.92),
            ),
            TaxBracket::new(
                dec!(1396542),
                Some(dec!(2000000)),
                dec!(0.123),
                dec!(135752.98),
            ),
            TaxBracket::new(dec!(2000000), None, dec!(0.133), dec!(209978.24)),
        ],
    );

    let mut std_ded = HashMap::new();
    std_ded.insert("single".to_string(), dec!(5363));
    std_ded.insert("married_filing_jointly".to_string(), dec!(10726));

    StateConfig {
        state_code: "CA".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        standard_deduction: Some(std_ded),
        sdi_rate: Some(dec!(0.011)),
        sdi_wage_base: Some(dec!(153164)),
        ..Default::default()
    }
}

fn new_york_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(8500)), dec!(0.04), dec!(0)),
            TaxBracket::new(dec!(8500), Some(dec!(11700)), dec!(0.045), dec!(340)),
            TaxBracket::new(dec!(11700), Some(dec!(13900)), dec!(0.0525), dec!(484)),
            TaxBracket::new(dec!(13900), Some(dec!(80650)), dec!(0.055), dec!(599.50)),
            TaxBracket::new(dec!(80650), Some(dec!(215400)), dec!(0.06), dec!(4270.75)),
            TaxBracket::new(
                dec!(215400),
                Some(dec!(1077550)),
                dec!(0.0685),
                dec!(12355.75),
            ),
            TaxBracket::new(
                dec!(1077550),
                Some(dec!(5000000)),
                dec!(0.0965),
                dec!(71413.03),
            ),
            TaxBracket::new(
                dec!(5000000),
                Some(dec!(25000000)),
                dec!(0.103),
                dec!(449929.28),
            ),
            TaxBracket::new(dec!(25000000), None, dec!(0.109), dec!(2509929.28)),
        ],
    );

    let mut std_ded = HashMap::new();
    std_ded.insert("single".to_string(), dec!(8000));
    std_ded.insert("married_filing_jointly".to_string(), dec!(16050));

    StateConfig {
        state_code: "NY".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        standard_deduction: Some(std_ded),
        local_tax_info: Some(LocalTaxInfo {
            has_local_tax: true,
            average_rate: Some(dec!(0.035)), // Estimate for NYC
        }),
        ..Default::default()
    }
}

fn arizona_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(28653)), dec!(0.0255), dec!(0)),
            TaxBracket::new(dec!(28653), None, dec!(0.0298), dec!(730.65)),
        ],
    );

    StateConfig {
        state_code: "AZ".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        ..Default::default()
    }
}

fn georgia_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(750)), dec!(0.01), dec!(0)),
            TaxBracket::new(dec!(750), Some(dec!(2250)), dec!(0.02), dec!(7.50)),
            TaxBracket::new(dec!(2250), Some(dec!(3750)), dec!(0.03), dec!(37.50)),
            TaxBracket::new(dec!(3750), Some(dec!(5250)), dec!(0.04), dec!(82.50)),
            TaxBracket::new(dec!(5250), Some(dec!(7000)), dec!(0.05), dec!(142.50)),
            TaxBracket::new(dec!(7000), None, dec!(0.0549), dec!(230)),
        ],
    );

    let mut std_ded = HashMap::new();
    std_ded.insert("single".to_string(), dec!(12000));
    std_ded.insert("married_filing_jointly".to_string(), dec!(24000));

    StateConfig {
        state_code: "GA".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        standard_deduction: Some(std_ded),
        ..Default::default()
    }
}

fn minnesota_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(30070)), dec!(0.0535), dec!(0)),
            TaxBracket::new(dec!(30070), Some(dec!(98760)), dec!(0.068), dec!(1608.75)),
            TaxBracket::new(dec!(98760), Some(dec!(183340)), dec!(0.0785), dec!(6279.67)),
            TaxBracket::new(dec!(183340), None, dec!(0.0985), dec!(12919.20)),
        ],
    );

    let mut std_ded = HashMap::new();
    std_ded.insert("single".to_string(), dec!(14575));
    std_ded.insert("married_filing_jointly".to_string(), dec!(29150));

    StateConfig {
        state_code: "MN".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        standard_deduction: Some(std_ded),
        ..Default::default()
    }
}

fn new_jersey_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(20000)), dec!(0.014), dec!(0)),
            TaxBracket::new(dec!(20000), Some(dec!(35000)), dec!(0.0175), dec!(280)),
            TaxBracket::new(dec!(35000), Some(dec!(40000)), dec!(0.035), dec!(542.50)),
            TaxBracket::new(dec!(40000), Some(dec!(75000)), dec!(0.05525), dec!(717.50)),
            TaxBracket::new(dec!(75000), Some(dec!(500000)), dec!(0.0637), dec!(2651.25)),
            TaxBracket::new(
                dec!(500000),
                Some(dec!(1000000)),
                dec!(0.0897),
                dec!(29724.00),
            ),
            TaxBracket::new(dec!(1000000), None, dec!(0.1075), dec!(74574.00)),
        ],
    );

    StateConfig {
        state_code: "NJ".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        sdi_rate: Some(dec!(0.0014)),
        ..Default::default()
    }
}

fn oregon_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(4050)), dec!(0.0475), dec!(0)),
            TaxBracket::new(dec!(4050), Some(dec!(10200)), dec!(0.0675), dec!(192.38)),
            TaxBracket::new(dec!(10200), Some(dec!(125000)), dec!(0.0875), dec!(607.50)),
            TaxBracket::new(dec!(125000), None, dec!(0.099), dec!(10652.50)),
        ],
    );

    let mut std_ded = HashMap::new();
    std_ded.insert("single".to_string(), dec!(2605));
    std_ded.insert("married_filing_jointly".to_string(), dec!(5210));

    StateConfig {
        state_code: "OR".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        standard_deduction: Some(std_ded),
        ..Default::default()
    }
}

fn virginia_config() -> StateConfig {
    let mut brackets = HashMap::new();

    brackets.insert(
        "single".to_string(),
        vec![
            TaxBracket::new(dec!(0), Some(dec!(3000)), dec!(0.02), dec!(0)),
            TaxBracket::new(dec!(3000), Some(dec!(5000)), dec!(0.03), dec!(60)),
            TaxBracket::new(dec!(5000), Some(dec!(17000)), dec!(0.05), dec!(120)),
            TaxBracket::new(dec!(17000), None, dec!(0.0575), dec!(720)),
        ],
    );

    let mut std_ded = HashMap::new();
    std_ded.insert("single".to_string(), dec!(8500));
    std_ded.insert("married_filing_jointly".to_string(), dec!(17000));

    StateConfig {
        state_code: "VA".to_string(),
        tax_type: StateTaxType::Progressive,
        brackets,
        standard_deduction: Some(std_ded),
        ..Default::default()
    }
}

fn default_brackets(_state: &USState) -> HashMap<String, Vec<TaxBracket>> {
    // Simple default: 5% flat equivalent as progressive
    let mut brackets = HashMap::new();
    brackets.insert(
        "single".to_string(),
        vec![TaxBracket::new(dec!(0), None, dec!(0.05), dec!(0))],
    );
    brackets
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_embedded_data_creation() {
        let data = EmbeddedTaxData::new();

        // Check federal brackets exist
        let single_brackets = data.federal_brackets(FilingStatus::Single, 2024);
        assert_eq!(single_brackets.len(), 7);

        // Check first bracket
        assert_eq!(single_brackets[0].floor, dec!(0));
        assert_eq!(single_brackets[0].rate, dec!(0.10));
    }

    #[test]
    fn test_standard_deductions() {
        let data = EmbeddedTaxData::new();

        assert_eq!(
            data.standard_deduction(FilingStatus::Single, 2024),
            dec!(14600)
        );
        assert_eq!(
            data.standard_deduction(FilingStatus::MarriedFilingJointly, 2024),
            dec!(29200)
        );
    }

    #[test]
    fn test_fica_config() {
        let data = EmbeddedTaxData::new();
        let fica = data.fica_config(2024);

        assert_eq!(fica.social_security_rate, dec!(0.062));
        assert_eq!(fica.wage_base, dec!(168600));
        assert_eq!(fica.medicare_rate, dec!(0.0145));
    }

    #[test]
    fn test_california_config() {
        let data = EmbeddedTaxData::new();
        let ca = data.state_config(USState::California, 2024);

        assert_eq!(ca.tax_type, StateTaxType::Progressive);
        assert!(ca.sdi_rate.is_some());
        assert_eq!(ca.sdi_rate.unwrap(), dec!(0.011));
    }

    #[test]
    fn test_no_tax_states() {
        let data = EmbeddedTaxData::new();

        let tx = data.state_config(USState::Texas, 2024);
        assert_eq!(tx.tax_type, StateTaxType::NoTax);

        let fl = data.state_config(USState::Florida, 2024);
        assert_eq!(fl.tax_type, StateTaxType::NoTax);
    }

    #[test]
    fn test_flat_tax_states() {
        let data = EmbeddedTaxData::new();

        let co = data.state_config(USState::Colorado, 2024);
        assert_eq!(co.tax_type, StateTaxType::FlatRate);
        assert_eq!(co.flat_rate, Some(dec!(0.044)));

        let il = data.state_config(USState::Illinois, 2024);
        assert_eq!(il.tax_type, StateTaxType::FlatRate);
        assert_eq!(il.flat_rate, Some(dec!(0.0495)));
    }
}
