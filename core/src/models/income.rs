//! Income-related models

use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

/// Pay frequency options
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
pub enum PayFrequency {
    Weekly,
    #[default]
    BiWeekly,
    SemiMonthly,
    Monthly,
}

impl PayFrequency {
    /// Number of pay periods per year
    pub fn periods_per_year(&self) -> u32 {
        match self {
            PayFrequency::Weekly => 52,
            PayFrequency::BiWeekly => 26,
            PayFrequency::SemiMonthly => 24,
            PayFrequency::Monthly => 12,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            PayFrequency::Weekly => "weekly",
            PayFrequency::BiWeekly => "bi_weekly",
            PayFrequency::SemiMonthly => "semi_monthly",
            PayFrequency::Monthly => "monthly",
        }
    }
}

/// Income input for calculations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeInput {
    pub gross_annual_salary: Decimal,
    pub bonuses: Decimal,
    pub other_income: Decimal,
    pub pay_frequency: PayFrequency,
}

impl IncomeInput {
    pub fn new(gross_annual_salary: Decimal) -> Self {
        Self {
            gross_annual_salary,
            bonuses: Decimal::ZERO,
            other_income: Decimal::ZERO,
            pay_frequency: PayFrequency::BiWeekly,
        }
    }

    pub fn total_gross(&self) -> Decimal {
        self.gross_annual_salary + self.bonuses + self.other_income
    }
}

impl Default for IncomeInput {
    fn default() -> Self {
        Self {
            gross_annual_salary: Decimal::ZERO,
            bonuses: Decimal::ZERO,
            other_income: Decimal::ZERO,
            pay_frequency: PayFrequency::BiWeekly,
        }
    }
}

/// Income broken down by timeframe
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TimeframeIncome {
    pub annual: Decimal,
    pub monthly: Decimal,
    pub bi_weekly: Decimal,
    pub weekly: Decimal,
    pub daily: Decimal,
    pub hourly: Decimal,
}

impl TimeframeIncome {
    /// Create timeframe breakdown from annual amount
    /// Uses standard 40 hours/week, 5 days/week
    pub fn from_annual(annual: Decimal) -> Self {
        Self {
            annual,
            monthly: annual / Decimal::from(12),
            bi_weekly: annual / Decimal::from(26),
            weekly: annual / Decimal::from(52),
            daily: annual / Decimal::from(260), // 52 weeks × 5 days
            hourly: annual / Decimal::from(2080), // 52 weeks × 40 hours
        }
    }

    /// Create with custom working schedule
    pub fn from_annual_custom(
        annual: Decimal,
        hours_per_week: Decimal,
        days_per_week: Decimal,
    ) -> Self {
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

impl Default for TimeframeIncome {
    fn default() -> Self {
        Self::from_annual(Decimal::ZERO)
    }
}

/// Complete calculated income result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalculatedIncome {
    pub gross: Decimal,
    pub net: Decimal,
    pub timeframes: TimeframeIncome,
    pub take_home_percentage: Decimal,
}

impl CalculatedIncome {
    pub fn new(gross: Decimal, net: Decimal) -> Self {
        let take_home_percentage = if gross > Decimal::ZERO {
            (net / gross) * Decimal::from(100)
        } else {
            Decimal::ZERO
        };

        Self {
            gross,
            net,
            timeframes: TimeframeIncome::from_annual(net),
            take_home_percentage,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;

    #[test]
    fn test_timeframe_from_annual() {
        let income = TimeframeIncome::from_annual(dec!(104000));

        assert_eq!(income.annual, dec!(104000));
        assert_eq!(income.monthly, dec!(104000) / dec!(12));
        assert_eq!(income.bi_weekly, dec!(4000)); // 104000 / 26
        assert_eq!(income.weekly, dec!(2000)); // 104000 / 52
        assert_eq!(income.daily, dec!(400)); // 104000 / 260
        assert_eq!(income.hourly, dec!(50)); // 104000 / 2080
    }

    #[test]
    fn test_pay_frequency_periods() {
        assert_eq!(PayFrequency::Weekly.periods_per_year(), 52);
        assert_eq!(PayFrequency::BiWeekly.periods_per_year(), 26);
        assert_eq!(PayFrequency::SemiMonthly.periods_per_year(), 24);
        assert_eq!(PayFrequency::Monthly.periods_per_year(), 12);
    }
}
