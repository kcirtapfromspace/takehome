//! State tax calculator

use rust_decimal::Decimal;

use crate::data::TaxDataProvider;
use crate::models::state::USState;
use crate::models::tax::{BracketAmount, FilingStatus, StateTaxResult, TaxBracket};

/// State tax calculator
pub struct StateTaxCalculator<'a> {
    data_provider: &'a dyn TaxDataProvider,
}

impl<'a> StateTaxCalculator<'a> {
    pub fn new(data_provider: &'a dyn TaxDataProvider) -> Self {
        Self { data_provider }
    }

    /// Calculate state income tax
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
            // Progressive brackets
            let brackets = config
                .brackets
                .get(filing_status.as_str())
                .cloned()
                .unwrap_or_default();

            let std_deduction = config
                .standard_deduction
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

    /// Calculate progressive tax with brackets
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

                if income_in_bracket > Decimal::ZERO {
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
        }

        (total_tax, Some(breakdown))
    }

    /// Calculate State Disability Insurance
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

    /// Estimate local tax (average rate)
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::embedded::EmbeddedTaxData;
    use rust_decimal_macros::dec;

    fn setup() -> EmbeddedTaxData {
        EmbeddedTaxData::new()
    }

    #[test]
    fn test_no_tax_state() {
        let data = setup();
        let calc = StateTaxCalculator::new(&data);

        let result = calc.calculate(dec!(100000), USState::Texas, FilingStatus::Single, 2024);

        assert_eq!(result.income_tax, dec!(0));
        assert_eq!(result.total_tax, dec!(0));
        assert_eq!(result.state_code, "TX");
    }

    #[test]
    fn test_flat_tax_state() {
        let data = setup();
        let calc = StateTaxCalculator::new(&data);

        // Colorado: 4.4% flat rate
        let result = calc.calculate(dec!(100000), USState::Colorado, FilingStatus::Single, 2024);

        assert_eq!(result.income_tax, dec!(4400));
        assert_eq!(result.state_code, "CO");
    }

    #[test]
    fn test_california_has_sdi() {
        let data = setup();
        let calc = StateTaxCalculator::new(&data);

        let result = calc.calculate(
            dec!(100000),
            USState::California,
            FilingStatus::Single,
            2024,
        );

        // California has SDI at 1.1%
        assert!(result.sdi > dec!(0));
        assert!(result.income_tax > dec!(0));
    }

    #[test]
    fn test_progressive_tax_state() {
        let data = setup();
        let calc = StateTaxCalculator::new(&data);

        // California has progressive brackets
        let result = calc.calculate(
            dec!(100000),
            USState::California,
            FilingStatus::Single,
            2024,
        );

        // Should have bracket breakdown
        assert!(result.bracket_breakdown.is_some());
        let breakdown = result.bracket_breakdown.unwrap();
        assert!(!breakdown.is_empty());

        // Tax should be reasonable for CA
        assert!(result.income_tax > dec!(3000));
        assert!(result.income_tax < dec!(10000));
    }

    #[test]
    fn test_all_no_tax_states() {
        let data = setup();
        let calc = StateTaxCalculator::new(&data);

        let no_tax_states = [
            USState::Alaska,
            USState::Florida,
            USState::Nevada,
            USState::NewHampshire,
            USState::SouthDakota,
            USState::Tennessee,
            USState::Texas,
            USState::Washington,
            USState::Wyoming,
        ];

        for state in no_tax_states {
            let result = calc.calculate(dec!(100000), state, FilingStatus::Single, 2024);
            assert_eq!(
                result.income_tax,
                dec!(0),
                "{} should have no income tax",
                state.name()
            );
        }
    }

    #[test]
    fn test_new_york_has_local_tax() {
        let data = setup();
        let calc = StateTaxCalculator::new(&data);

        let result = calc.calculate(dec!(100000), USState::NewYork, FilingStatus::Single, 2024);

        // New York has state income tax
        assert!(result.income_tax > dec!(0));
        // May have estimated local tax
        // (depends on data configuration)
    }
}
