//! Deduction models

use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

/// Types of deductions
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeductionType {
    HealthInsurance,
    DentalInsurance,
    VisionInsurance,
    Hsa,
    Fsa,
    Commuter,
    LifeInsurance,
    DisabilityInsurance,
    UnionDues,
    Traditional401k,
    Roth401k,
    Other,
}

impl DeductionType {
    pub fn display_name(&self) -> &'static str {
        match self {
            DeductionType::HealthInsurance => "Health Insurance",
            DeductionType::DentalInsurance => "Dental Insurance",
            DeductionType::VisionInsurance => "Vision Insurance",
            DeductionType::Hsa => "HSA Contribution",
            DeductionType::Fsa => "FSA Contribution",
            DeductionType::Commuter => "Commuter Benefits",
            DeductionType::LifeInsurance => "Life Insurance",
            DeductionType::DisabilityInsurance => "Disability Insurance",
            DeductionType::UnionDues => "Union Dues",
            DeductionType::Traditional401k => "Traditional 401(k)",
            DeductionType::Roth401k => "Roth 401(k)",
            DeductionType::Other => "Other",
        }
    }

    /// Whether this deduction is pre-tax by default
    pub fn is_pre_tax(&self) -> bool {
        matches!(
            self,
            DeductionType::HealthInsurance
                | DeductionType::DentalInsurance
                | DeductionType::VisionInsurance
                | DeductionType::Hsa
                | DeductionType::Fsa
                | DeductionType::Commuter
                | DeductionType::Traditional401k
        )
    }
}

/// Deduction frequency
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeductionFrequency {
    PerPaycheck,
    Monthly,
    Annual,
}

/// Individual deduction
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Deduction {
    pub deduction_type: DeductionType,
    pub name: String,
    pub amount: Decimal,
    pub frequency: DeductionFrequency,
    pub periods_per_year: u32,
    pub is_pre_tax: bool,
}

impl Deduction {
    pub fn new(
        deduction_type: DeductionType,
        amount: Decimal,
        frequency: DeductionFrequency,
        periods_per_year: u32,
    ) -> Self {
        Self {
            deduction_type,
            name: deduction_type.display_name().to_string(),
            amount,
            frequency,
            periods_per_year,
            is_pre_tax: deduction_type.is_pre_tax(),
        }
    }

    /// Calculate annual amount
    pub fn annual_amount(&self) -> Decimal {
        match self.frequency {
            DeductionFrequency::PerPaycheck => self.amount * Decimal::from(self.periods_per_year),
            DeductionFrequency::Monthly => self.amount * Decimal::from(12),
            DeductionFrequency::Annual => self.amount,
        }
    }
}

/// Retirement contributions
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RetirementContributions {
    pub traditional_401k: Decimal,
    pub roth_401k: Decimal,
    pub employer_match: Decimal,
    pub match_percentage: Decimal,
    pub vesting_percentage: Decimal,
}

impl RetirementContributions {
    pub fn new() -> Self {
        Self {
            traditional_401k: Decimal::ZERO,
            roth_401k: Decimal::ZERO,
            employer_match: Decimal::ZERO,
            match_percentage: Decimal::ZERO,
            vesting_percentage: Decimal::ONE,
        }
    }

    pub fn total_employee_contributions(&self) -> Decimal {
        self.traditional_401k + self.roth_401k
    }

    pub fn total_with_match(&self) -> Decimal {
        self.total_employee_contributions() + self.vested_employer_match()
    }

    pub fn vested_employer_match(&self) -> Decimal {
        self.employer_match * self.vesting_percentage
    }
}

/// Deductions summary
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DeductionsSummary {
    pub pre_tax_total: Decimal,
    pub post_tax_total: Decimal,
    pub retirement: RetirementContributions,
}

impl DeductionsSummary {
    pub fn total(&self) -> Decimal {
        self.pre_tax_total + self.post_tax_total + self.retirement.total_employee_contributions()
    }
}
