//! Household and expense splitting models

use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

/// How to split shared expenses
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub enum SplitMethod {
    /// Based on income ratio
    #[default]
    Proportional,
    /// 50/50
    Equal,
    /// Custom percentage for primary
    Custom(Decimal),
}

/// Partner's profile (simplified)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PartnerProfile {
    pub name: String,
    pub gross_income: Decimal,
    pub net_income: Decimal,
}

impl PartnerProfile {
    pub fn new(name: String, gross_income: Decimal, net_income: Decimal) -> Self {
        Self {
            name,
            gross_income,
            net_income,
        }
    }
}

/// Household configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Household {
    pub partner: PartnerProfile,
    pub split_method: SplitMethod,
    pub shared_expenses_monthly: Decimal,
}

impl Household {
    pub fn new(partner: PartnerProfile, split_method: SplitMethod) -> Self {
        Self {
            partner,
            split_method,
            shared_expenses_monthly: Decimal::ZERO,
        }
    }
}

/// Result of household split calculation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HouseholdSplit {
    pub primary_ratio: Decimal,
    pub partner_ratio: Decimal,
    pub primary_monthly_amount: Decimal,
    pub partner_monthly_amount: Decimal,
}

impl HouseholdSplit {
    pub fn primary_percent(&self) -> Decimal {
        self.primary_ratio * Decimal::from(100)
    }

    pub fn partner_percent(&self) -> Decimal {
        self.partner_ratio * Decimal::from(100)
    }
}

/// Calculate household expense split
pub fn calculate_split(
    primary_net: Decimal,
    partner_net: Decimal,
    shared_expense: Decimal,
    method: SplitMethod,
) -> HouseholdSplit {
    let total_net = primary_net + partner_net;

    let (primary_ratio, partner_ratio) = match method {
        SplitMethod::Proportional => {
            if total_net > Decimal::ZERO {
                let primary = primary_net / total_net;
                (primary, Decimal::ONE - primary)
            } else {
                (Decimal::new(5, 1), Decimal::new(5, 1)) // 0.5, 0.5
            }
        },
        SplitMethod::Equal => {
            (Decimal::new(5, 1), Decimal::new(5, 1)) // 0.5, 0.5
        },
        SplitMethod::Custom(primary_pct) => (primary_pct, Decimal::ONE - primary_pct),
    };

    HouseholdSplit {
        primary_ratio,
        partner_ratio,
        primary_monthly_amount: shared_expense * primary_ratio,
        partner_monthly_amount: shared_expense * partner_ratio,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;

    #[test]
    fn test_proportional_split() {
        // Primary: $8,000 net, Partner: $2,000 net
        // Total: $10,000, Primary ratio: 80%
        let split = calculate_split(
            dec!(8000),
            dec!(2000),
            dec!(1000), // $1,000 shared expense
            SplitMethod::Proportional,
        );

        assert_eq!(split.primary_ratio, dec!(0.8));
        assert_eq!(split.partner_ratio, dec!(0.2));
        assert_eq!(split.primary_monthly_amount, dec!(800));
        assert_eq!(split.partner_monthly_amount, dec!(200));
    }

    #[test]
    fn test_equal_split() {
        let split = calculate_split(dec!(8000), dec!(2000), dec!(1000), SplitMethod::Equal);

        assert_eq!(split.primary_ratio, dec!(0.5));
        assert_eq!(split.primary_monthly_amount, dec!(500));
        assert_eq!(split.partner_monthly_amount, dec!(500));
    }

    #[test]
    fn test_custom_split() {
        let split = calculate_split(
            dec!(8000),
            dec!(2000),
            dec!(1000),
            SplitMethod::Custom(dec!(0.7)), // 70% primary
        );

        assert_eq!(split.primary_ratio, dec!(0.7));
        assert_eq!(split.primary_monthly_amount, dec!(700));
        assert_eq!(split.partner_monthly_amount, dec!(300));
    }
}
