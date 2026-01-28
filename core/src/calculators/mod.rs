//! Tax and income calculators

pub mod federal;
pub mod fica;
pub mod state;
pub mod timeframe;

pub use federal::FederalTaxCalculator;
pub use fica::FicaCalculator;
pub use state::StateTaxCalculator;
pub use timeframe::TimeframeCalculator;
