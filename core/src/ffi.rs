//! FFI exports for cross-platform bindings

// FFI functions often need many parameters for cross-language compatibility
#![allow(clippy::too_many_arguments)]

use rust_decimal::Decimal;

use crate::data::embedded::get_embedded_data;
use crate::engine::{
    ScenarioComparison, TaxCalculationEngine, TaxCalculationInput, TaxCalculationResult,
};
use crate::models::household::{calculate_split, HouseholdSplit, SplitMethod};
use crate::models::income::TimeframeIncome;
use crate::models::state::USState;
use crate::models::tax::FilingStatus;

// ============================================================================
// Error Type
// ============================================================================

#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum TaxCalcError {
    #[error("Invalid decimal value: {message}")]
    InvalidDecimal { message: String },
    #[error("Invalid filing status: {message}")]
    InvalidFilingStatus { message: String },
    #[error("Invalid state code: {message}")]
    InvalidState { message: String },
    #[error("Calculation error: {message}")]
    CalculationError { message: String },
}

// ============================================================================
// Public FFI Functions
// ============================================================================

/// Get library version
#[uniffi::export]
pub fn get_version() -> String {
    crate::VERSION.to_string()
}

/// Get current tax year
#[uniffi::export]
pub fn get_tax_year() -> u32 {
    2024
}

/// Calculate taxes with full breakdown
#[uniffi::export]
pub fn calculate_taxes(
    gross_income: String,
    filing_status: String,
    state_code: String,
    pre_tax_deductions: String,
    post_tax_deductions: String,
    traditional_401k: String,
    roth_401k: String,
) -> Result<TaxResultFFI, TaxCalcError> {
    let input = parse_input(
        &gross_income,
        &filing_status,
        &state_code,
        &pre_tax_deductions,
        &post_tax_deductions,
        &traditional_401k,
        &roth_401k,
    )?;

    let data = get_embedded_data();
    let engine = TaxCalculationEngine::new(data, 2024);
    let result = engine.calculate(&input);

    Ok(TaxResultFFI::from(result))
}

/// Compare two scenarios
#[uniffi::export]
pub fn compare_scenarios(
    // Base scenario
    base_gross: String,
    base_filing_status: String,
    base_state: String,
    base_pre_tax: String,
    base_post_tax: String,
    base_traditional_401k: String,
    base_roth_401k: String,
    // Comparison scenario
    scenario_gross: String,
    scenario_filing_status: String,
    scenario_state: String,
    scenario_pre_tax: String,
    scenario_post_tax: String,
    scenario_traditional_401k: String,
    scenario_roth_401k: String,
) -> Result<ScenarioComparisonFFI, TaxCalcError> {
    let base = parse_input(
        &base_gross,
        &base_filing_status,
        &base_state,
        &base_pre_tax,
        &base_post_tax,
        &base_traditional_401k,
        &base_roth_401k,
    )?;

    let scenario = parse_input(
        &scenario_gross,
        &scenario_filing_status,
        &scenario_state,
        &scenario_pre_tax,
        &scenario_post_tax,
        &scenario_traditional_401k,
        &scenario_roth_401k,
    )?;

    let data = get_embedded_data();
    let engine = TaxCalculationEngine::new(data, 2024);
    let comparison = engine.compare_scenarios(&base, &scenario);

    Ok(ScenarioComparisonFFI::from(comparison))
}

/// Convert annual amount to all timeframes
#[uniffi::export]
pub fn convert_timeframes(annual: String) -> Result<TimeframeFFI, TaxCalcError> {
    let amount = parse_decimal(&annual)?;
    let timeframes = TimeframeIncome::from_annual(amount);
    Ok(TimeframeFFI::from(timeframes))
}

/// Calculate household expense split
#[uniffi::export]
pub fn calculate_household_split(
    primary_net: String,
    partner_net: String,
    shared_expense: String,
    split_method: String,
) -> Result<HouseholdSplitFFI, TaxCalcError> {
    let primary = parse_decimal(&primary_net)?;
    let partner = parse_decimal(&partner_net)?;
    let expense = parse_decimal(&shared_expense)?;

    let method = match split_method.as_str() {
        "proportional" => SplitMethod::Proportional,
        "equal" => SplitMethod::Equal,
        s if s.starts_with("custom:") => {
            let pct = parse_decimal(&s[7..])?;
            SplitMethod::Custom(pct)
        },
        _ => SplitMethod::Proportional,
    };

    let split = calculate_split(primary, partner, expense, method);
    Ok(HouseholdSplitFFI::from(split))
}

/// Get list of all state codes
#[uniffi::export]
pub fn get_all_state_codes() -> Vec<String> {
    USState::all()
        .iter()
        .map(|s| s.code().to_string())
        .collect()
}

/// Get list of all filing statuses
#[uniffi::export]
pub fn get_all_filing_statuses() -> Vec<String> {
    vec![
        "single".to_string(),
        "married_filing_jointly".to_string(),
        "married_filing_separately".to_string(),
        "head_of_household".to_string(),
        "qualifying_widower".to_string(),
    ]
}

/// Check if state has no income tax
#[uniffi::export]
pub fn state_has_no_income_tax(state_code: String) -> bool {
    USState::from_code(&state_code)
        .map(|s| s.has_no_income_tax())
        .unwrap_or(false)
}

// ============================================================================
// FFI Data Types (String-based for cross-platform compatibility)
// ============================================================================

/// Tax calculation result for FFI
#[derive(Debug, Clone, uniffi::Record)]
pub struct TaxResultFFI {
    // Income
    pub gross_annual: String,
    pub net_annual: String,
    pub net_monthly: String,
    pub net_biweekly: String,
    pub net_weekly: String,
    pub net_daily: String,
    pub net_hourly: String,
    pub take_home_percentage: String,

    // Federal
    pub federal_tax: String,
    pub federal_effective_rate: String,
    pub federal_marginal_rate: String,

    // State
    pub state_code: String,
    pub state_income_tax: String,
    pub state_local_tax: String,
    pub state_sdi: String,
    pub state_total_tax: String,

    // FICA
    pub social_security: String,
    pub medicare: String,
    pub additional_medicare: String,
    pub fica_total: String,

    // Totals
    pub total_taxes: String,
    pub total_effective_rate: String,
}

impl From<TaxCalculationResult> for TaxResultFFI {
    fn from(r: TaxCalculationResult) -> Self {
        Self {
            gross_annual: r.income.gross.to_string(),
            net_annual: r.income.net.to_string(),
            net_monthly: r.income.timeframes.monthly.to_string(),
            net_biweekly: r.income.timeframes.bi_weekly.to_string(),
            net_weekly: r.income.timeframes.weekly.to_string(),
            net_daily: r.income.timeframes.daily.to_string(),
            net_hourly: r.income.timeframes.hourly.to_string(),
            take_home_percentage: r.income.take_home_percentage.to_string(),

            federal_tax: r.tax_breakdown.federal.tax.to_string(),
            federal_effective_rate: r.tax_breakdown.federal.effective_rate.to_string(),
            federal_marginal_rate: r.tax_breakdown.federal.marginal_rate.to_string(),

            state_code: r.tax_breakdown.state.state_code,
            state_income_tax: r.tax_breakdown.state.income_tax.to_string(),
            state_local_tax: r.tax_breakdown.state.local_tax.to_string(),
            state_sdi: r.tax_breakdown.state.sdi.to_string(),
            state_total_tax: r.tax_breakdown.state.total_tax.to_string(),

            social_security: r.tax_breakdown.fica.social_security.to_string(),
            medicare: r.tax_breakdown.fica.medicare.to_string(),
            additional_medicare: r.tax_breakdown.fica.additional_medicare.to_string(),
            fica_total: r.tax_breakdown.fica.total.to_string(),

            total_taxes: r.tax_breakdown.total_taxes.to_string(),
            total_effective_rate: r.effective_rates.total.to_string(),
        }
    }
}

/// Scenario comparison for FFI
#[derive(Debug, Clone, uniffi::Record)]
pub struct ScenarioComparisonFFI {
    pub base: TaxResultFFI,
    pub scenario: TaxResultFFI,
    pub net_difference: String,
    pub monthly_difference: String,
    pub is_positive: bool,
}

impl From<ScenarioComparison> for ScenarioComparisonFFI {
    fn from(c: ScenarioComparison) -> Self {
        let is_positive = c.is_positive();
        Self {
            base: TaxResultFFI::from(c.base),
            scenario: TaxResultFFI::from(c.scenario),
            net_difference: c.net_difference.to_string(),
            monthly_difference: c.monthly_difference.to_string(),
            is_positive,
        }
    }
}

/// Timeframe income for FFI
#[derive(Debug, Clone, uniffi::Record)]
pub struct TimeframeFFI {
    pub annual: String,
    pub monthly: String,
    pub bi_weekly: String,
    pub weekly: String,
    pub daily: String,
    pub hourly: String,
}

impl From<TimeframeIncome> for TimeframeFFI {
    fn from(t: TimeframeIncome) -> Self {
        Self {
            annual: t.annual.to_string(),
            monthly: t.monthly.to_string(),
            bi_weekly: t.bi_weekly.to_string(),
            weekly: t.weekly.to_string(),
            daily: t.daily.to_string(),
            hourly: t.hourly.to_string(),
        }
    }
}

/// Household split for FFI
#[derive(Debug, Clone, uniffi::Record)]
pub struct HouseholdSplitFFI {
    pub primary_ratio: String,
    pub partner_ratio: String,
    pub primary_amount: String,
    pub partner_amount: String,
}

impl From<HouseholdSplit> for HouseholdSplitFFI {
    fn from(h: HouseholdSplit) -> Self {
        Self {
            primary_ratio: h.primary_ratio.to_string(),
            partner_ratio: h.partner_ratio.to_string(),
            primary_amount: h.primary_monthly_amount.to_string(),
            partner_amount: h.partner_monthly_amount.to_string(),
        }
    }
}

// ============================================================================
// Helper Functions
// ============================================================================

fn parse_decimal(s: &str) -> Result<Decimal, TaxCalcError> {
    s.parse::<Decimal>()
        .map_err(|_| TaxCalcError::InvalidDecimal {
            message: s.to_string(),
        })
}

fn parse_filing_status(s: &str) -> Result<FilingStatus, TaxCalcError> {
    match s {
        "single" => Ok(FilingStatus::Single),
        "married_filing_jointly" => Ok(FilingStatus::MarriedFilingJointly),
        "married_filing_separately" => Ok(FilingStatus::MarriedFilingSeparately),
        "head_of_household" => Ok(FilingStatus::HeadOfHousehold),
        "qualifying_widower" => Ok(FilingStatus::QualifyingWidower),
        _ => Err(TaxCalcError::InvalidFilingStatus {
            message: s.to_string(),
        }),
    }
}

fn parse_input(
    gross: &str,
    filing_status: &str,
    state: &str,
    pre_tax: &str,
    post_tax: &str,
    traditional: &str,
    roth: &str,
) -> Result<TaxCalculationInput, TaxCalcError> {
    Ok(TaxCalculationInput {
        gross_income: parse_decimal(gross)?,
        filing_status: parse_filing_status(filing_status)?,
        state: USState::from_code(state).ok_or_else(|| TaxCalcError::InvalidState {
            message: state.to_string(),
        })?,
        pre_tax_deductions: parse_decimal(pre_tax)?,
        post_tax_deductions: parse_decimal(post_tax)?,
        traditional_401k: parse_decimal(traditional)?,
        roth_401k: parse_decimal(roth)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_taxes_ffi() {
        let result = calculate_taxes(
            "100000".to_string(),
            "single".to_string(),
            "CA".to_string(),
            "0".to_string(),
            "0".to_string(),
            "0".to_string(),
            "0".to_string(),
        );

        assert!(result.is_ok());
        let r = result.unwrap();
        assert_eq!(r.gross_annual, "100000");
        assert!(!r.net_annual.is_empty());
    }

    #[test]
    fn test_convert_timeframes_ffi() {
        let result = convert_timeframes("104000".to_string());
        assert!(result.is_ok());

        let t = result.unwrap();
        assert_eq!(t.annual, "104000");
        assert_eq!(t.bi_weekly, "4000");
        assert_eq!(t.hourly, "50");
    }

    #[test]
    fn test_household_split_ffi() {
        let result = calculate_household_split(
            "8000".to_string(),
            "2000".to_string(),
            "1000".to_string(),
            "proportional".to_string(),
        );

        assert!(result.is_ok());
        let s = result.unwrap();
        // Decimal may format as "0.8" or "0.80" depending on representation
        assert!(s.primary_ratio == "0.8" || s.primary_ratio == "0.80");
        assert!(s.primary_amount == "800" || s.primary_amount == "800.00");
    }

    #[test]
    fn test_state_codes() {
        let codes = get_all_state_codes();
        assert_eq!(codes.len(), 51);
        assert!(codes.contains(&"CA".to_string()));
        assert!(codes.contains(&"TX".to_string()));
    }

    #[test]
    fn test_no_income_tax_check() {
        assert!(state_has_no_income_tax("TX".to_string()));
        assert!(state_has_no_income_tax("FL".to_string()));
        assert!(!state_has_no_income_tax("CA".to_string()));
        assert!(!state_has_no_income_tax("NY".to_string()));
    }
}
