//! Tax data handling

pub mod embedded;

use rust_decimal::Decimal;
use std::collections::HashMap;

use crate::models::state::USState;
use crate::models::tax::{FilingStatus, TaxBracket};

/// Tax data provider trait
pub trait TaxDataProvider: Send + Sync {
    /// Get federal tax brackets for filing status
    fn federal_brackets(&self, filing_status: FilingStatus, year: u32) -> Vec<TaxBracket>;

    /// Get standard deduction for filing status
    fn standard_deduction(&self, filing_status: FilingStatus, year: u32) -> Decimal;

    /// Get FICA configuration
    fn fica_config(&self, year: u32) -> FicaConfig;

    /// Get state tax configuration
    fn state_config(&self, state: USState, year: u32) -> StateConfig;
}

/// FICA configuration
#[derive(Debug, Clone)]
pub struct FicaConfig {
    pub social_security_rate: Decimal,
    pub wage_base: Decimal,
    pub medicare_rate: Decimal,
    pub additional_medicare_rate: Decimal,
}

/// State tax configuration
#[derive(Debug, Clone, Default)]
pub struct StateConfig {
    pub state_code: String,
    pub tax_type: StateTaxType,
    pub flat_rate: Option<Decimal>,
    pub brackets: HashMap<String, Vec<TaxBracket>>,
    pub standard_deduction: Option<HashMap<String, Decimal>>,
    pub sdi_rate: Option<Decimal>,
    pub sdi_wage_base: Option<Decimal>,
    pub local_tax_info: Option<LocalTaxInfo>,
}

/// State tax type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum StateTaxType {
    #[default]
    NoTax,
    FlatRate,
    Progressive,
}

/// Local tax information
#[derive(Debug, Clone, Default)]
pub struct LocalTaxInfo {
    pub has_local_tax: bool,
    pub average_rate: Option<Decimal>,
}
