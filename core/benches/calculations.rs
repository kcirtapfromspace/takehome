//! Benchmarks for tax calculations

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use rust_decimal_macros::dec;

use takehome_core::data::embedded::EmbeddedTaxData;
use takehome_core::engine::{TaxCalculationEngine, TaxCalculationInput};
use takehome_core::models::state::USState;
use takehome_core::models::tax::FilingStatus;

fn benchmark_full_calculation(c: &mut Criterion) {
    let data = EmbeddedTaxData::new();
    let engine = TaxCalculationEngine::new(&data, 2024);

    let input = TaxCalculationInput {
        gross_income: dec!(100000),
        filing_status: FilingStatus::Single,
        state: USState::California,
        pre_tax_deductions: dec!(5000),
        post_tax_deductions: dec!(0),
        traditional_401k: dec!(10000),
        roth_401k: dec!(0),
    };

    c.bench_function("full_calculation_ca_100k", |b| {
        b.iter(|| engine.calculate(black_box(&input)))
    });
}

fn benchmark_all_states(c: &mut Criterion) {
    let data = EmbeddedTaxData::new();
    let engine = TaxCalculationEngine::new(&data, 2024);

    let base_input = TaxCalculationInput {
        gross_income: dec!(100000),
        filing_status: FilingStatus::Single,
        state: USState::California,
        ..Default::default()
    };

    c.bench_function("all_51_jurisdictions", |b| {
        b.iter(|| {
            for state in USState::all() {
                let input = TaxCalculationInput {
                    state: *state,
                    ..base_input.clone()
                };
                engine.calculate(black_box(&input));
            }
        })
    });
}

fn benchmark_scenario_comparison(c: &mut Criterion) {
    let data = EmbeddedTaxData::new();
    let engine = TaxCalculationEngine::new(&data, 2024);

    let base = TaxCalculationInput {
        gross_income: dec!(100000),
        filing_status: FilingStatus::Single,
        state: USState::California,
        ..Default::default()
    };

    let scenario = TaxCalculationInput {
        gross_income: dec!(120000),
        state: USState::Texas,
        ..base.clone()
    };

    c.bench_function("scenario_comparison", |b| {
        b.iter(|| engine.compare_scenarios(black_box(&base), black_box(&scenario)))
    });
}

fn benchmark_timeframe_conversion(c: &mut Criterion) {
    use takehome_core::models::income::TimeframeIncome;

    c.bench_function("timeframe_conversion", |b| {
        b.iter(|| TimeframeIncome::from_annual(black_box(dec!(100000))))
    });
}

criterion_group!(
    benches,
    benchmark_full_calculation,
    benchmark_all_states,
    benchmark_scenario_comparison,
    benchmark_timeframe_conversion,
);

criterion_main!(benches);
