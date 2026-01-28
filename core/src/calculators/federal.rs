//! Federal tax calculator

use rust_decimal::Decimal;
use rust_decimal_macros::dec;

use crate::data::TaxDataProvider;
use crate::models::tax::{BracketAmount, FederalTaxResult, FilingStatus, TaxBracket};

/// Federal tax calculator
pub struct FederalTaxCalculator<'a> {
    data_provider: &'a dyn TaxDataProvider,
}

impl<'a> FederalTaxCalculator<'a> {
    pub fn new(data_provider: &'a dyn TaxDataProvider) -> Self {
        Self { data_provider }
    }

    /// Calculate federal income tax
    pub fn calculate(
        &self,
        taxable_income: Decimal,
        filing_status: FilingStatus,
        year: u32,
    ) -> FederalTaxResult {
        let brackets = self.data_provider.federal_brackets(filing_status, year);

        if taxable_income <= Decimal::ZERO || brackets.is_empty() {
            return FederalTaxResult {
                taxable_income: Decimal::ZERO,
                tax: Decimal::ZERO,
                marginal_rate: brackets.first().map(|b| b.rate).unwrap_or(dec!(0.10)),
                effective_rate: Decimal::ZERO,
                bracket_breakdown: vec![],
            };
        }

        // Build breakdown and find marginal rate
        let mut breakdown = Vec::new();
        let mut marginal_rate = dec!(0.10);

        for bracket in &brackets {
            if taxable_income > bracket.floor {
                marginal_rate = bracket.rate;

                let ceiling = bracket.ceiling.unwrap_or(Decimal::MAX);
                let income_in_bracket = taxable_income.min(ceiling) - bracket.floor;

                if income_in_bracket > Decimal::ZERO {
                    let tax_in_bracket = income_in_bracket * bracket.rate;
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

        // Calculate total using efficient base tax formula
        let tax = self.calculate_with_base_tax(taxable_income, &brackets);
        let effective_rate = tax / taxable_income;

        FederalTaxResult {
            taxable_income,
            tax,
            marginal_rate,
            effective_rate,
            bracket_breakdown: breakdown,
        }
    }

    /// Efficient calculation using base tax formula
    /// Tax = BaseTax + (Income - BracketFloor) × Rate
    fn calculate_with_base_tax(&self, taxable_income: Decimal, brackets: &[TaxBracket]) -> Decimal {
        // Find the applicable bracket (last one where income >= floor)
        let bracket = brackets
            .iter()
            .rev()
            .find(|b| taxable_income >= b.floor)
            .unwrap_or(&brackets[0]);

        bracket.base_tax + (taxable_income - bracket.floor) * bracket.rate
    }

    /// Get standard deduction for filing status
    pub fn standard_deduction(&self, filing_status: FilingStatus, year: u32) -> Decimal {
        self.data_provider.standard_deduction(filing_status, year)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::embedded::EmbeddedTaxData;

    fn setup() -> EmbeddedTaxData {
        EmbeddedTaxData::new()
    }

    #[test]
    fn test_single_50k() {
        let data = setup();
        let calc = FederalTaxCalculator::new(&data);

        let result = calc.calculate(dec!(50000), FilingStatus::Single, 2024);

        // $50,000 is in 22% bracket for single
        // Tax = $5,426 + ($50,000 - $47,150) × 0.22 = $6,053
        assert!(result.tax > dec!(6000) && result.tax < dec!(6100));
        assert_eq!(result.marginal_rate, dec!(0.22));
    }

    #[test]
    fn test_single_100k() {
        let data = setup();
        let calc = FederalTaxCalculator::new(&data);

        let result = calc.calculate(dec!(100000), FilingStatus::Single, 2024);

        // $100,000 is in 22% bracket for single
        // Tax = $5,426 + ($100,000 - $47,150) × 0.22 = $17,053
        assert!(result.tax > dec!(17000) && result.tax < dec!(17100));
        assert_eq!(result.marginal_rate, dec!(0.22));
    }

    #[test]
    fn test_mfj_200k() {
        let data = setup();
        let calc = FederalTaxCalculator::new(&data);

        let result = calc.calculate(dec!(200000), FilingStatus::MarriedFilingJointly, 2024);

        // $200,000 is in 22% bracket for MFJ ($94,300 - $201,050)
        assert_eq!(result.marginal_rate, dec!(0.22));
        // Effective rate should be lower than marginal
        assert!(result.effective_rate < result.marginal_rate);
    }

    #[test]
    fn test_zero_income() {
        let data = setup();
        let calc = FederalTaxCalculator::new(&data);

        let result = calc.calculate(dec!(0), FilingStatus::Single, 2024);

        assert_eq!(result.tax, dec!(0));
        assert!(result.bracket_breakdown.is_empty());
    }

    #[test]
    fn test_standard_deduction() {
        let data = setup();
        let calc = FederalTaxCalculator::new(&data);

        let single = calc.standard_deduction(FilingStatus::Single, 2024);
        let mfj = calc.standard_deduction(FilingStatus::MarriedFilingJointly, 2024);

        assert_eq!(single, dec!(14600));
        assert_eq!(mfj, dec!(29200));
    }

    #[test]
    fn test_bracket_breakdown_adds_up() {
        let data = setup();
        let calc = FederalTaxCalculator::new(&data);

        let result = calc.calculate(dec!(100000), FilingStatus::Single, 2024);

        let breakdown_total: Decimal = result.bracket_breakdown.iter().map(|b| b.tax_paid).sum();

        // Allow small rounding difference
        let diff = (result.tax - breakdown_total).abs();
        assert!(diff < dec!(0.01));
    }
}
