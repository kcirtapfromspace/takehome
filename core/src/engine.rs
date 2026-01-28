//! Main calculation engine

use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

use crate::calculators::{FederalTaxCalculator, FicaCalculator, StateTaxCalculator};
use crate::data::TaxDataProvider;
use crate::models::income::{CalculatedIncome, TimeframeIncome};
use crate::models::state::USState;
use crate::models::tax::{EffectiveRates, FilingStatus, TaxBreakdown};

/// Input for complete tax calculation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaxCalculationInput {
    pub gross_income: Decimal,
    pub filing_status: FilingStatus,
    pub state: USState,
    pub pre_tax_deductions: Decimal,
    pub post_tax_deductions: Decimal,
    pub traditional_401k: Decimal,
    pub roth_401k: Decimal,
}

impl Default for TaxCalculationInput {
    fn default() -> Self {
        Self {
            gross_income: Decimal::ZERO,
            filing_status: FilingStatus::Single,
            state: USState::California,
            pre_tax_deductions: Decimal::ZERO,
            post_tax_deductions: Decimal::ZERO,
            traditional_401k: Decimal::ZERO,
            roth_401k: Decimal::ZERO,
        }
    }
}

/// Complete calculation result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaxCalculationResult {
    pub income: CalculatedIncome,
    pub tax_breakdown: TaxBreakdown,
    pub effective_rates: EffectiveRates,
}

/// Scenario comparison result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScenarioComparison {
    pub base: TaxCalculationResult,
    pub scenario: TaxCalculationResult,
    pub net_difference: Decimal,
    pub monthly_difference: Decimal,
}

impl ScenarioComparison {
    pub fn is_positive(&self) -> bool {
        self.net_difference > Decimal::ZERO
    }

    pub fn net_difference_percent(&self) -> Decimal {
        if self.base.income.net > Decimal::ZERO {
            (self.net_difference / self.base.income.net) * Decimal::from(100)
        } else {
            Decimal::ZERO
        }
    }
}

/// Main calculation engine
pub struct TaxCalculationEngine<'a> {
    federal_calc: FederalTaxCalculator<'a>,
    state_calc: StateTaxCalculator<'a>,
    fica_calc: FicaCalculator<'a>,
    year: u32,
}

impl<'a> TaxCalculationEngine<'a> {
    /// Create a new calculation engine
    pub fn new(data_provider: &'a dyn TaxDataProvider, year: u32) -> Self {
        Self {
            federal_calc: FederalTaxCalculator::new(data_provider),
            state_calc: StateTaxCalculator::new(data_provider),
            fica_calc: FicaCalculator::new(data_provider),
            year,
        }
    }

    /// Perform complete tax calculation
    pub fn calculate(&self, input: &TaxCalculationInput) -> TaxCalculationResult {
        // Step 1: Calculate total pre-tax deductions
        let total_pre_tax = input.pre_tax_deductions + input.traditional_401k;

        // Step 2: Calculate federal taxable income
        let std_deduction = self
            .federal_calc
            .standard_deduction(input.filing_status, self.year);
        let federal_taxable =
            (input.gross_income - total_pre_tax - std_deduction).max(Decimal::ZERO);

        // Step 3: Calculate federal tax
        let federal_result =
            self.federal_calc
                .calculate(federal_taxable, input.filing_status, self.year);

        // Step 4: Calculate state tax (state may have different deductions)
        let state_taxable = input.gross_income - total_pre_tax;
        let state_result =
            self.state_calc
                .calculate(state_taxable, input.state, input.filing_status, self.year);

        // Step 5: Calculate FICA (on gross income, not reduced by 401k for SS)
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
        let effective_rates = if input.gross_income > Decimal::ZERO {
            EffectiveRates {
                federal: federal_result.tax / input.gross_income,
                state: state_result.total_tax / input.gross_income,
                fica: fica_result.total / input.gross_income,
                total: total_taxes / input.gross_income,
            }
        } else {
            EffectiveRates::default()
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

    /// Compare two scenarios
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::embedded::EmbeddedTaxData;
    use rust_decimal_macros::dec;

    fn setup() -> EmbeddedTaxData {
        EmbeddedTaxData::new()
    }

    #[test]
    fn test_full_calculation() {
        let data = setup();
        let engine = TaxCalculationEngine::new(&data, 2024);

        let input = TaxCalculationInput {
            gross_income: dec!(100000),
            filing_status: FilingStatus::Single,
            state: USState::California,
            pre_tax_deductions: dec!(0),
            post_tax_deductions: dec!(0),
            traditional_401k: dec!(0),
            roth_401k: dec!(0),
        };

        let result = engine.calculate(&input);

        // Verify gross income preserved
        assert_eq!(result.income.gross, dec!(100000));

        // Verify net is less than gross
        assert!(result.income.net < result.income.gross);

        // Verify net is reasonable (50-75% for $100K in CA)
        assert!(result.income.net > dec!(50000));
        assert!(result.income.net < dec!(75000));

        // Verify take-home percentage matches
        let expected_pct = (result.income.net / result.income.gross) * dec!(100);
        assert_eq!(result.income.take_home_percentage, expected_pct);

        // Verify timeframes are calculated
        assert_eq!(result.income.timeframes.annual, result.income.net);
        assert!(result.income.timeframes.monthly > dec!(0));
    }

    #[test]
    fn test_401k_reduces_taxes() {
        let data = setup();
        let engine = TaxCalculationEngine::new(&data, 2024);

        let without_401k = TaxCalculationInput {
            gross_income: dec!(100000),
            filing_status: FilingStatus::Single,
            state: USState::California,
            traditional_401k: dec!(0),
            ..Default::default()
        };

        let with_401k = TaxCalculationInput {
            traditional_401k: dec!(20000),
            ..without_401k.clone()
        };

        let result_without = engine.calculate(&without_401k);
        let result_with = engine.calculate(&with_401k);

        // Federal tax should be lower with 401k
        assert!(result_with.tax_breakdown.federal.tax < result_without.tax_breakdown.federal.tax);

        // But total out-of-pocket (taxes + 401k) means less liquid cash
        // Net income is lower because 401k is deducted from take-home
        assert!(result_with.income.net < result_without.income.net);
    }

    #[test]
    fn test_scenario_comparison_state_move() {
        let data = setup();
        let engine = TaxCalculationEngine::new(&data, 2024);

        let ca_input = TaxCalculationInput {
            gross_income: dec!(150000),
            filing_status: FilingStatus::Single,
            state: USState::California,
            ..Default::default()
        };

        let tx_input = TaxCalculationInput {
            state: USState::Texas, // No state income tax
            ..ca_input.clone()
        };

        let comparison = engine.compare_scenarios(&ca_input, &tx_input);

        // Moving to Texas should increase net income
        assert!(comparison.is_positive());
        assert!(comparison.net_difference > dec!(0));
        assert!(comparison.monthly_difference > dec!(0));

        // Texas result should have zero state tax
        assert_eq!(comparison.scenario.tax_breakdown.state.income_tax, dec!(0));
    }

    #[test]
    fn test_scenario_comparison_raise() {
        let data = setup();
        let engine = TaxCalculationEngine::new(&data, 2024);

        let current = TaxCalculationInput {
            gross_income: dec!(100000),
            filing_status: FilingStatus::Single,
            state: USState::California,
            ..Default::default()
        };

        let raise = TaxCalculationInput {
            gross_income: dec!(120000), // $20K raise
            ..current.clone()
        };

        let comparison = engine.compare_scenarios(&current, &raise);

        // Net should increase
        assert!(comparison.is_positive());

        // But due to taxes, net increase should be less than $20K
        assert!(comparison.net_difference > dec!(0));
        assert!(comparison.net_difference < dec!(20000));
    }

    #[test]
    fn test_effective_rates() {
        let data = setup();
        let engine = TaxCalculationEngine::new(&data, 2024);

        let input = TaxCalculationInput {
            gross_income: dec!(100000),
            filing_status: FilingStatus::Single,
            state: USState::California,
            ..Default::default()
        };

        let result = engine.calculate(&input);

        // Total effective rate should be sum of components
        let sum = result.effective_rates.federal
            + result.effective_rates.state
            + result.effective_rates.fica;

        let diff = (result.effective_rates.total - sum).abs();
        assert!(diff < dec!(0.001));

        // Effective rate should be less than 50%
        assert!(result.effective_rates.total < dec!(0.5));
    }

    #[test]
    fn test_zero_income() {
        let data = setup();
        let engine = TaxCalculationEngine::new(&data, 2024);

        let input = TaxCalculationInput {
            gross_income: dec!(0),
            ..Default::default()
        };

        let result = engine.calculate(&input);

        assert_eq!(result.income.gross, dec!(0));
        assert_eq!(result.income.net, dec!(0));
        assert_eq!(result.tax_breakdown.total_taxes, dec!(0));
    }
}
