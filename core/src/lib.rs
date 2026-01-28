//! TakeHome Core - Financial Calculation Engine
//!
//! A cross-platform Rust library for tax and income calculations.
//! Provides precise calculations for federal taxes, state taxes, FICA,
//! and multi-timeframe income conversions.

// Allow the function pointer comparison warning from UniFFI macro
#![allow(unpredictable_function_pointer_comparisons)]

pub mod calculators;
pub mod data;
pub mod engine;
pub mod models;

mod ffi;

// UniFFI setup - creates UniFfiTag type needed for FFI bindings
uniffi::setup_scaffolding!();

pub use engine::{
    ScenarioComparison, TaxCalculationEngine, TaxCalculationInput, TaxCalculationResult,
};
pub use ffi::TaxCalcError;
pub use models::income::{CalculatedIncome, IncomeInput, PayFrequency, TimeframeIncome};
pub use models::state::USState;
pub use models::tax::{FederalTaxResult, FicaResult, FilingStatus, StateTaxResult, TaxBreakdown};

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
