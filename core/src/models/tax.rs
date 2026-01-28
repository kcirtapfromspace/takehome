//! Tax-related models

use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

/// IRS filing status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
pub enum FilingStatus {
    #[default]
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

    pub fn display_name(&self) -> &'static str {
        match self {
            FilingStatus::Single => "Single",
            FilingStatus::MarriedFilingJointly => "Married Filing Jointly",
            FilingStatus::MarriedFilingSeparately => "Married Filing Separately",
            FilingStatus::HeadOfHousehold => "Head of Household",
            FilingStatus::QualifyingWidower => "Qualifying Widow(er)",
        }
    }

    pub fn short_name(&self) -> &'static str {
        match self {
            FilingStatus::Single => "Single",
            FilingStatus::MarriedFilingJointly => "MFJ",
            FilingStatus::MarriedFilingSeparately => "MFS",
            FilingStatus::HeadOfHousehold => "HoH",
            FilingStatus::QualifyingWidower => "QW",
        }
    }
}

/// Tax bracket definition
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TaxBracket {
    pub floor: Decimal,
    pub ceiling: Option<Decimal>,
    pub rate: Decimal,
    pub base_tax: Decimal,
}

impl TaxBracket {
    pub fn new(floor: Decimal, ceiling: Option<Decimal>, rate: Decimal, base_tax: Decimal) -> Self {
        Self {
            floor,
            ceiling,
            rate,
            base_tax,
        }
    }

    /// Calculate tax using the base tax formula
    /// Tax = BaseTax + (Income - Floor) × Rate
    pub fn calculate(&self, taxable_income: Decimal) -> Decimal {
        if taxable_income <= self.floor {
            return Decimal::ZERO;
        }

        self.base_tax + (taxable_income - self.floor) * self.rate
    }

    /// Check if income falls within this bracket
    pub fn contains(&self, income: Decimal) -> bool {
        income >= self.floor && self.ceiling.is_none_or(|c| income < c)
    }
}

/// Amount paid in a specific bracket (for breakdown display)
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BracketAmount {
    pub floor: Decimal,
    pub ceiling: Option<Decimal>,
    pub rate: Decimal,
    pub taxable_in_bracket: Decimal,
    pub tax_paid: Decimal,
}

/// Federal tax calculation result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FederalTaxResult {
    pub taxable_income: Decimal,
    pub tax: Decimal,
    pub marginal_rate: Decimal,
    pub effective_rate: Decimal,
    pub bracket_breakdown: Vec<BracketAmount>,
}

impl Default for FederalTaxResult {
    fn default() -> Self {
        Self {
            taxable_income: Decimal::ZERO,
            tax: Decimal::ZERO,
            marginal_rate: Decimal::ZERO,
            effective_rate: Decimal::ZERO,
            bracket_breakdown: vec![],
        }
    }
}

/// FICA calculation result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FicaResult {
    pub social_security: Decimal,
    pub social_security_wage_base: Decimal,
    pub medicare: Decimal,
    pub additional_medicare: Decimal,
    pub total: Decimal,
}

impl Default for FicaResult {
    fn default() -> Self {
        Self {
            social_security: Decimal::ZERO,
            social_security_wage_base: Decimal::ZERO,
            medicare: Decimal::ZERO,
            additional_medicare: Decimal::ZERO,
            total: Decimal::ZERO,
        }
    }
}

/// State tax calculation result
#[derive(Debug, Clone, Serialize, Deserialize)]
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

impl Default for StateTaxResult {
    fn default() -> Self {
        Self {
            state_code: String::new(),
            taxable_income: Decimal::ZERO,
            income_tax: Decimal::ZERO,
            local_tax: Decimal::ZERO,
            sdi: Decimal::ZERO,
            total_tax: Decimal::ZERO,
            effective_rate: Decimal::ZERO,
            bracket_breakdown: None,
        }
    }
}

/// Complete tax breakdown
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaxBreakdown {
    pub federal: FederalTaxResult,
    pub state: StateTaxResult,
    pub fica: FicaResult,
    pub total_taxes: Decimal,
    pub effective_rate: Decimal,
}

impl Default for TaxBreakdown {
    fn default() -> Self {
        Self {
            federal: FederalTaxResult::default(),
            state: StateTaxResult::default(),
            fica: FicaResult::default(),
            total_taxes: Decimal::ZERO,
            effective_rate: Decimal::ZERO,
        }
    }
}

/// Effective rates summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EffectiveRates {
    pub federal: Decimal,
    pub state: Decimal,
    pub fica: Decimal,
    pub total: Decimal,
}

impl EffectiveRates {
    pub fn federal_percent(&self) -> Decimal {
        self.federal * Decimal::from(100)
    }

    pub fn state_percent(&self) -> Decimal {
        self.state * Decimal::from(100)
    }

    pub fn fica_percent(&self) -> Decimal {
        self.fica * Decimal::from(100)
    }

    pub fn total_percent(&self) -> Decimal {
        self.total * Decimal::from(100)
    }
}

impl Default for EffectiveRates {
    fn default() -> Self {
        Self {
            federal: Decimal::ZERO,
            state: Decimal::ZERO,
            fica: Decimal::ZERO,
            total: Decimal::ZERO,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;

    #[test]
    fn test_bracket_calculate() {
        // 22% bracket: $47,150 - $100,525, base tax $5,426
        let bracket = TaxBracket::new(dec!(47150), Some(dec!(100525)), dec!(0.22), dec!(5426));

        // Income of $80,000
        let tax = bracket.calculate(dec!(80000));
        // Expected: $5,426 + ($80,000 - $47,150) × 0.22 = $12,653
        assert_eq!(tax, dec!(5426) + (dec!(80000) - dec!(47150)) * dec!(0.22));
    }

    #[test]
    fn test_bracket_contains() {
        let bracket = TaxBracket::new(dec!(47150), Some(dec!(100525)), dec!(0.22), dec!(5426));

        assert!(!bracket.contains(dec!(40000))); // Below floor
        assert!(bracket.contains(dec!(50000))); // In bracket
        assert!(bracket.contains(dec!(100000))); // In bracket
        assert!(!bracket.contains(dec!(110000))); // Above ceiling
    }
}
