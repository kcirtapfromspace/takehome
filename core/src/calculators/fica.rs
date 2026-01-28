//! FICA (Social Security + Medicare) calculator

use rust_decimal::Decimal;
use rust_decimal_macros::dec;

use crate::data::TaxDataProvider;
use crate::models::tax::{FicaResult, FilingStatus};

/// FICA tax calculator
pub struct FicaCalculator<'a> {
    data_provider: &'a dyn TaxDataProvider,
}

impl<'a> FicaCalculator<'a> {
    pub fn new(data_provider: &'a dyn TaxDataProvider) -> Self {
        Self { data_provider }
    }

    /// Calculate FICA taxes (using Single thresholds for additional Medicare)
    pub fn calculate(&self, gross_income: Decimal, year: u32) -> FicaResult {
        self.calculate_with_status(gross_income, FilingStatus::Single, year)
    }

    /// Calculate FICA taxes with filing status for additional Medicare threshold
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

        // Additional Medicare (0.9% above threshold)
        // Threshold varies by filing status
        let threshold = match filing_status {
            FilingStatus::Single
            | FilingStatus::HeadOfHousehold
            | FilingStatus::QualifyingWidower => dec!(200000),
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

    fn setup() -> EmbeddedTaxData {
        EmbeddedTaxData::new()
    }

    #[test]
    fn test_fica_under_ss_cap() {
        let data = setup();
        let calc = FicaCalculator::new(&data);

        let result = calc.calculate(dec!(100000), 2024);

        // Social Security: $100,000 × 6.2% = $6,200
        assert_eq!(result.social_security, dec!(6200));

        // Medicare: $100,000 × 1.45% = $1,450
        assert_eq!(result.medicare, dec!(1450));

        // No additional Medicare (under $200K)
        assert_eq!(result.additional_medicare, dec!(0));

        // Total: $7,650
        assert_eq!(result.total, dec!(7650));
    }

    #[test]
    fn test_fica_above_ss_cap() {
        let data = setup();
        let calc = FicaCalculator::new(&data);

        // 2024 SS wage base is $168,600
        let result = calc.calculate(dec!(200000), 2024);

        // Social Security capped: $168,600 × 6.2% = $10,453.20
        assert_eq!(result.social_security, dec!(10453.20));

        // Medicare: $200,000 × 1.45% = $2,900
        assert_eq!(result.medicare, dec!(2900));

        // No additional Medicare (at exactly $200K for single)
        assert_eq!(result.additional_medicare, dec!(0));
    }

    #[test]
    fn test_additional_medicare_single() {
        let data = setup();
        let calc = FicaCalculator::new(&data);

        let result = calc.calculate_with_status(dec!(250000), FilingStatus::Single, 2024);

        // Additional Medicare: ($250,000 - $200,000) × 0.9% = $450
        assert_eq!(result.additional_medicare, dec!(450));
    }

    #[test]
    fn test_additional_medicare_mfj() {
        let data = setup();
        let calc = FicaCalculator::new(&data);

        let result =
            calc.calculate_with_status(dec!(300000), FilingStatus::MarriedFilingJointly, 2024);

        // MFJ threshold is $250,000
        // Additional Medicare: ($300,000 - $250,000) × 0.9% = $450
        assert_eq!(result.additional_medicare, dec!(450));
    }

    #[test]
    fn test_additional_medicare_mfs() {
        let data = setup();
        let calc = FicaCalculator::new(&data);

        let result =
            calc.calculate_with_status(dec!(150000), FilingStatus::MarriedFilingSeparately, 2024);

        // MFS threshold is $125,000
        // Additional Medicare: ($150,000 - $125,000) × 0.9% = $225
        assert_eq!(result.additional_medicare, dec!(225));
    }

    #[test]
    fn test_fica_rates() {
        let data = setup();
        let calc = FicaCalculator::new(&data);

        let result = calc.calculate(dec!(50000), 2024);

        // Verify rates
        let ss_rate = result.social_security / dec!(50000);
        let medicare_rate = result.medicare / dec!(50000);

        assert_eq!(ss_rate, dec!(0.062));
        assert_eq!(medicare_rate, dec!(0.0145));
    }
}
