//! Timeframe conversion calculator

use rust_decimal::Decimal;

use crate::models::income::TimeframeIncome;

/// Timeframe identifiers
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Timeframe {
    Annual,
    Monthly,
    BiWeekly,
    SemiMonthly,
    Weekly,
    Daily,
    Hourly,
}

impl Timeframe {
    /// Divisor to convert from annual
    pub fn divisor(&self) -> Decimal {
        match self {
            Timeframe::Annual => Decimal::ONE,
            Timeframe::Monthly => Decimal::from(12),
            Timeframe::BiWeekly => Decimal::from(26),
            Timeframe::SemiMonthly => Decimal::from(24),
            Timeframe::Weekly => Decimal::from(52),
            Timeframe::Daily => Decimal::from(260),
            Timeframe::Hourly => Decimal::from(2080),
        }
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            Timeframe::Annual => "Annual",
            Timeframe::Monthly => "Monthly",
            Timeframe::BiWeekly => "Bi-Weekly",
            Timeframe::SemiMonthly => "Semi-Monthly",
            Timeframe::Weekly => "Weekly",
            Timeframe::Daily => "Daily",
            Timeframe::Hourly => "Hourly",
        }
    }
}

/// Timeframe calculator
pub struct TimeframeCalculator;

impl TimeframeCalculator {
    /// Convert annual amount to all timeframes
    pub fn from_annual(annual: Decimal) -> TimeframeIncome {
        TimeframeIncome::from_annual(annual)
    }

    /// Convert annual with custom hours/days per week
    pub fn from_annual_custom(
        annual: Decimal,
        hours_per_week: Decimal,
        days_per_week: Decimal,
    ) -> TimeframeIncome {
        TimeframeIncome::from_annual_custom(annual, hours_per_week, days_per_week)
    }

    /// Convert from any timeframe to annual
    pub fn to_annual(amount: Decimal, from: Timeframe) -> Decimal {
        amount * from.divisor()
    }

    /// Convert between any two timeframes
    pub fn convert(amount: Decimal, from: Timeframe, to: Timeframe) -> Decimal {
        let annual = Self::to_annual(amount, from);
        annual / to.divisor()
    }

    /// Calculate work hours needed to earn an amount
    /// Given hourly rate, how many hours to earn target amount
    pub fn hours_to_earn(hourly_rate: Decimal, target_amount: Decimal) -> Decimal {
        if hourly_rate <= Decimal::ZERO {
            return Decimal::ZERO;
        }
        target_amount / hourly_rate
    }

    /// Calculate work days needed to earn an amount
    /// Given daily rate, how many days to earn target amount
    pub fn days_to_earn(daily_rate: Decimal, target_amount: Decimal) -> Decimal {
        if daily_rate <= Decimal::ZERO {
            return Decimal::ZERO;
        }
        target_amount / daily_rate
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;

    #[test]
    fn test_from_annual() {
        let income = TimeframeCalculator::from_annual(dec!(104000));

        assert_eq!(income.annual, dec!(104000));
        assert_eq!(income.monthly, dec!(104000) / dec!(12));
        assert_eq!(income.bi_weekly, dec!(4000));
        assert_eq!(income.weekly, dec!(2000));
        assert_eq!(income.daily, dec!(400));
        assert_eq!(income.hourly, dec!(50));
    }

    #[test]
    fn test_to_annual() {
        assert_eq!(
            TimeframeCalculator::to_annual(dec!(8666.67), Timeframe::Monthly),
            dec!(8666.67) * dec!(12)
        );

        assert_eq!(
            TimeframeCalculator::to_annual(dec!(50), Timeframe::Hourly),
            dec!(104000)
        );

        assert_eq!(
            TimeframeCalculator::to_annual(dec!(4000), Timeframe::BiWeekly),
            dec!(104000)
        );
    }

    #[test]
    fn test_convert() {
        // $50/hour to monthly
        let monthly = TimeframeCalculator::convert(dec!(50), Timeframe::Hourly, Timeframe::Monthly);
        // 50 * 2080 / 12 = 8666.67
        assert!(monthly > dec!(8666) && monthly < dec!(8667));

        // $4000 bi-weekly to monthly
        let monthly =
            TimeframeCalculator::convert(dec!(4000), Timeframe::BiWeekly, Timeframe::Monthly);
        // 4000 * 26 / 12 = 8666.67
        assert!(monthly > dec!(8666) && monthly < dec!(8667));
    }

    #[test]
    fn test_hours_to_earn() {
        // At $50/hour, how many hours to earn $500?
        let hours = TimeframeCalculator::hours_to_earn(dec!(50), dec!(500));
        assert_eq!(hours, dec!(10));

        // Edge case: zero hourly rate
        let hours = TimeframeCalculator::hours_to_earn(dec!(0), dec!(500));
        assert_eq!(hours, dec!(0));
    }

    #[test]
    fn test_days_to_earn() {
        // At $400/day, how many days to earn $2000?
        let days = TimeframeCalculator::days_to_earn(dec!(400), dec!(2000));
        assert_eq!(days, dec!(5));
    }

    #[test]
    fn test_custom_hours() {
        // Part-time: 20 hours/week, 4 days/week
        let income = TimeframeCalculator::from_annual_custom(dec!(52000), dec!(20), dec!(4));

        // Hourly: 52000 / (52 * 20) = 50
        assert_eq!(income.hourly, dec!(50));

        // Daily: 52000 / (52 * 4) = 250
        assert_eq!(income.daily, dec!(250));
    }
}
