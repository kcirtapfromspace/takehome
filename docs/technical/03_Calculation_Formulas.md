# TakeHome Technical Architecture: Calculation Formulas

## Overview

This document provides comprehensive calculation formulas for all tax computations in TakeHome, including federal taxes, FICA, all 50 state taxes, retirement contributions, and timeframe conversions.

**Important Disclaimer**: Tax laws change annually. These formulas are based on 2024 tax year data and must be updated each year. Always include a disclaimer in the app: *"Estimates only. Consult a tax professional for advice."*

---

## 1. Federal Income Tax (2024)

### Formula

```
Federal Tax = Base Tax + (Taxable Income - Bracket Floor) × Marginal Rate
```

### Tax Brackets by Filing Status

#### Single Filers (2024)

| Bracket | Income Range | Marginal Rate | Base Tax |
|---------|--------------|---------------|----------|
| 1 | $0 - $11,600 | 10% | $0 |
| 2 | $11,600 - $47,150 | 12% | $1,160 |
| 3 | $47,150 - $100,525 | 22% | $5,426 |
| 4 | $100,525 - $191,950 | 24% | $17,168.50 |
| 5 | $191,950 - $243,725 | 32% | $39,110.50 |
| 6 | $243,725 - $609,350 | 35% | $55,678.50 |
| 7 | $609,350+ | 37% | $183,647.25 |

#### Married Filing Jointly (2024)

| Bracket | Income Range | Marginal Rate | Base Tax |
|---------|--------------|---------------|----------|
| 1 | $0 - $23,200 | 10% | $0 |
| 2 | $23,200 - $94,300 | 12% | $2,320 |
| 3 | $94,300 - $201,050 | 22% | $10,852 |
| 4 | $201,050 - $383,900 | 24% | $34,337 |
| 5 | $383,900 - $487,450 | 32% | $78,221 |
| 6 | $487,450 - $731,200 | 35% | $111,357 |
| 7 | $731,200+ | 37% | $196,669.50 |

#### Married Filing Separately (2024)

| Bracket | Income Range | Marginal Rate | Base Tax |
|---------|--------------|---------------|----------|
| 1 | $0 - $11,600 | 10% | $0 |
| 2 | $11,600 - $47,150 | 12% | $1,160 |
| 3 | $47,150 - $100,525 | 22% | $5,426 |
| 4 | $100,525 - $191,950 | 24% | $17,168.50 |
| 5 | $191,950 - $243,725 | 32% | $39,110.50 |
| 6 | $243,725 - $365,600 | 35% | $55,678.50 |
| 7 | $365,600+ | 37% | $98,334.75 |

#### Head of Household (2024)

| Bracket | Income Range | Marginal Rate | Base Tax |
|---------|--------------|---------------|----------|
| 1 | $0 - $16,550 | 10% | $0 |
| 2 | $16,550 - $63,100 | 12% | $1,655 |
| 3 | $63,100 - $100,500 | 22% | $7,241 |
| 4 | $100,500 - $191,950 | 24% | $15,469 |
| 5 | $191,950 - $243,700 | 32% | $37,417 |
| 6 | $243,700 - $609,350 | 35% | $53,977 |
| 7 | $609,350+ | 37% | $181,954.50 |

### Standard Deductions (2024)

| Filing Status | Standard Deduction |
|--------------|-------------------|
| Single | $14,600 |
| Married Filing Jointly | $29,200 |
| Married Filing Separately | $14,600 |
| Head of Household | $21,900 |
| Qualifying Widow(er) | $29,200 |

### Swift Implementation

```swift
import Foundation

struct FederalTaxCalculator: FederalTaxCalculatorProtocol {

    private let taxDataProvider: TaxDataProviderProtocol

    init(taxDataProvider: TaxDataProviderProtocol) {
        self.taxDataProvider = taxDataProvider
    }

    func calculate(
        taxableIncome: Decimal,
        filingStatus: FilingStatus,
        year: Int
    ) -> FederalTaxResult {
        let brackets = taxDataProvider.federalBrackets(for: filingStatus, year: year)

        guard taxableIncome > 0 else {
            return FederalTaxResult(
                taxableIncome: 0,
                tax: 0,
                marginalBracket: brackets[0],
                effectiveRate: 0,
                bracketBreakdown: []
            )
        }

        var totalTax: Decimal = 0
        var bracketBreakdown: [BracketAmount] = []
        var currentBracket = brackets[0]

        for bracket in brackets {
            let bracketFloor = bracket.floor
            let bracketCeiling = bracket.ceiling ?? Decimal.greatestFiniteMagnitude

            if taxableIncome > bracketFloor {
                currentBracket = bracket
                let incomeInBracket = min(taxableIncome, bracketCeiling) - bracketFloor
                let taxInBracket = incomeInBracket * bracket.rate

                totalTax += taxInBracket
                bracketBreakdown.append(BracketAmount(
                    bracket: bracket,
                    taxableInBracket: incomeInBracket,
                    taxPaid: taxInBracket
                ))
            }
        }

        // Alternative formula using base tax (more efficient)
        let efficientTax = calculateWithBaseTax(
            taxableIncome: taxableIncome,
            brackets: brackets
        )

        return FederalTaxResult(
            taxableIncome: taxableIncome,
            tax: efficientTax,
            marginalBracket: currentBracket,
            effectiveRate: efficientTax / taxableIncome,
            bracketBreakdown: bracketBreakdown
        )
    }

    private func calculateWithBaseTax(
        taxableIncome: Decimal,
        brackets: [TaxBracket]
    ) -> Decimal {
        // Find the applicable bracket
        let bracket = brackets.last { taxableIncome >= $0.floor } ?? brackets[0]

        // Tax = BaseTax + (Income - BracketFloor) × Rate
        return bracket.baseTax + (taxableIncome - bracket.floor) * bracket.rate
    }
}
```

---

## 2. FICA Taxes (2024)

### Social Security

```
If Gross Income ≤ Wage Base ($168,600):
    Social Security Tax = Gross Income × 6.2%
Else:
    Social Security Tax = $168,600 × 6.2% = $10,453.20
```

### Medicare

```
Medicare Tax = Gross Income × 1.45%

Additional Medicare (0.9%) applies above threshold:
- Single/HoH: $200,000
- MFJ: $250,000
- MFS: $125,000

If Gross Income > Threshold:
    Additional Medicare = (Gross Income - Threshold) × 0.9%
```

### Swift Implementation

```swift
import Foundation

struct FICACalculator: FICACalculatorProtocol {

    private let taxDataProvider: TaxDataProviderProtocol

    func calculate(grossIncome: Decimal, year: Int) -> FICAResult {
        let config = taxDataProvider.ficaConfig(year: year)

        // Social Security (capped at wage base)
        let ssWageBase = config.socialSecurityWageBase
        let ssTaxableIncome = min(grossIncome, ssWageBase)
        let socialSecurity = ssTaxableIncome * config.socialSecurityRate

        // Medicare (no cap)
        let medicare = grossIncome * config.medicareRate

        // Additional Medicare (above threshold - using Single threshold as default)
        let additionalMedicareThreshold = config.additionalMedicareThreshold
        var additionalMedicare: Decimal = 0
        if grossIncome > additionalMedicareThreshold {
            additionalMedicare = (grossIncome - additionalMedicareThreshold) * config.additionalMedicareRate
        }

        return FICAResult(
            socialSecurity: socialSecurity,
            socialSecurityWageBase: ssWageBase,
            medicare: medicare,
            additionalMedicare: additionalMedicare,
            totalFICA: socialSecurity + medicare + additionalMedicare
        )
    }

    func calculate(
        grossIncome: Decimal,
        filingStatus: FilingStatus,
        year: Int
    ) -> FICAResult {
        let config = taxDataProvider.ficaConfig(year: year)

        let ssWageBase = config.socialSecurityWageBase
        let ssTaxableIncome = min(grossIncome, ssWageBase)
        let socialSecurity = ssTaxableIncome * config.socialSecurityRate

        let medicare = grossIncome * config.medicareRate

        // Additional Medicare threshold varies by filing status
        let threshold: Decimal
        switch filingStatus {
        case .single, .headOfHousehold, .qualifyingWidower:
            threshold = 200_000
        case .marriedFilingJointly:
            threshold = 250_000
        case .marriedFilingSeparately:
            threshold = 125_000
        }

        var additionalMedicare: Decimal = 0
        if grossIncome > threshold {
            additionalMedicare = (grossIncome - threshold) * 0.009
        }

        return FICAResult(
            socialSecurity: socialSecurity,
            socialSecurityWageBase: ssWageBase,
            medicare: medicare,
            additionalMedicare: additionalMedicare,
            totalFICA: socialSecurity + medicare + additionalMedicare
        )
    }
}
```

---

## 3. State Income Taxes (All 50 States + DC)

### States with NO Income Tax

| State | Notes |
|-------|-------|
| **Alaska** | No state income tax |
| **Florida** | No state income tax |
| **Nevada** | No state income tax |
| **South Dakota** | No state income tax |
| **Texas** | No state income tax |
| **Washington** | No state income tax (has capital gains tax) |
| **Wyoming** | No state income tax |
| **Tennessee** | No wage income tax (dividends/interest only until 2021) |
| **New Hampshire** | No wage income tax (dividends/interest only - phasing out) |

### States with FLAT Tax Rate

| State | Rate | Notes |
|-------|------|-------|
| **Colorado** | 4.40% | Flat rate |
| **Illinois** | 4.95% | Flat rate |
| **Indiana** | 3.05% | Flat rate (2024), plus local |
| **Kentucky** | 4.00% | Flat rate (was progressive before 2023) |
| **Massachusetts** | 5.00% | Flat rate (4% surtax on income > $1M) |
| **Michigan** | 4.25% | Flat rate, plus local in some cities |
| **New Hampshire** | 3.00% | Interest/dividends only (phasing out) |
| **North Carolina** | 5.25% | Flat rate |
| **Pennsylvania** | 3.07% | Flat rate, plus local |
| **Utah** | 4.65% | Flat rate |

### States with PROGRESSIVE Tax Brackets

---

#### Alabama (AL)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $500 | $0 - $1,000 | 2% |
| 2 | $500 - $3,000 | $1,000 - $6,000 | 4% |
| 3 | $3,000+ | $6,000+ | 5% |

**Standard Deduction**: $2,500 (S), $7,500 (MFJ)
**Notes**: Has local income taxes in some cities

---

#### Arizona (AZ)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $28,653 | $0 - $57,305 | 2.55% |
| 2 | $28,653+ | $57,305+ | 2.98% |

**Standard Deduction**: $13,850 (S), $27,700 (MFJ)

---

#### Arkansas (AR)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $4,400 | 2.0% |
| 2 | $4,400 - $8,800 | 4.0% |
| 3 | $8,800+ | 4.4% |

**Standard Deduction**: $2,340 (S), $4,680 (MFJ)

---

#### California (CA)

| Bracket | Single | Rate |
|---------|--------|------|
| 1 | $0 - $10,412 | 1.00% |
| 2 | $10,412 - $24,684 | 2.00% |
| 3 | $24,684 - $38,959 | 4.00% |
| 4 | $38,959 - $54,081 | 6.00% |
| 5 | $54,081 - $68,350 | 8.00% |
| 6 | $68,350 - $349,137 | 9.30% |
| 7 | $349,137 - $418,961 | 10.30% |
| 8 | $418,961 - $698,271 | 11.30% |
| 9 | $698,271 - $1,000,000 | 12.30% |
| 10 | $1,000,000+ | 13.30% |

**MFJ**: Double the Single brackets
**Standard Deduction**: $5,363 (S), $10,726 (MFJ)
**SDI Rate**: 1.1% (wage base: $153,164)
**Notes**: Highest state income tax rate in the US (13.3%)

---

#### Connecticut (CT)

| Bracket | Single | Rate |
|---------|--------|------|
| 1 | $0 - $10,000 | 3.00% |
| 2 | $10,000 - $50,000 | 5.00% |
| 3 | $50,000 - $100,000 | 5.50% |
| 4 | $100,000 - $200,000 | 6.00% |
| 5 | $200,000 - $250,000 | 6.50% |
| 6 | $250,000 - $500,000 | 6.90% |
| 7 | $500,000+ | 6.99% |

**Notes**: Complex credit system, no standard deduction

---

#### Delaware (DE)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $2,000 | 0% |
| 2 | $2,000 - $5,000 | 2.2% |
| 3 | $5,000 - $10,000 | 3.9% |
| 4 | $10,000 - $20,000 | 4.8% |
| 5 | $20,000 - $25,000 | 5.2% |
| 6 | $25,000 - $60,000 | 5.55% |
| 7 | $60,000+ | 6.60% |

**Standard Deduction**: $3,250 (S), $6,500 (MFJ)
**Notes**: Has local income tax in Wilmington

---

#### Georgia (GA)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $750 | $0 - $1,000 | 1% |
| 2 | $750 - $2,250 | $1,000 - $3,000 | 2% |
| 3 | $2,250 - $3,750 | $3,000 - $5,000 | 3% |
| 4 | $3,750 - $5,250 | $5,000 - $7,000 | 4% |
| 5 | $5,250 - $7,000 | $7,000 - $10,000 | 5% |
| 6 | $7,000+ | $10,000+ | 5.49% |

**Standard Deduction**: $12,000 (S), $24,000 (MFJ)
**Notes**: Transitioning to flat tax by 2029

---

#### Hawaii (HI)

| Bracket | Single | Rate |
|---------|--------|------|
| 1 | $0 - $2,400 | 1.40% |
| 2 | $2,400 - $4,800 | 3.20% |
| 3 | $4,800 - $9,600 | 5.50% |
| 4 | $9,600 - $14,400 | 6.40% |
| 5 | $14,400 - $19,200 | 6.80% |
| 6 | $19,200 - $24,000 | 7.20% |
| 7 | $24,000 - $36,000 | 7.60% |
| 8 | $36,000 - $48,000 | 7.90% |
| 9 | $48,000 - $150,000 | 8.25% |
| 10 | $150,000 - $175,000 | 9.00% |
| 11 | $175,000 - $200,000 | 10.00% |
| 12 | $200,000+ | 11.00% |

**SDI Rate**: 0.5% (temporary disability insurance)
**Notes**: 12 tax brackets, one of highest state rates

---

#### Idaho (ID)

| Bracket | All Filers | Rate |
|---------|------------|------|
| Flat | All income | 5.80% |

**Standard Deduction**: Federal amount
**Notes**: Recently moved to flat tax

---

#### Iowa (IA)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $6,210 | 4.40% |
| 2 | $6,210 - $31,050 | 4.82% |
| 3 | $31,050+ | 5.70% |

**Standard Deduction**: $2,210 (S), $5,450 (MFJ)
**Notes**: Phasing down to 3.9% flat by 2026

---

#### Kansas (KS)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $15,000 | $0 - $30,000 | 3.1% |
| 2 | $15,000 - $30,000 | $30,000 - $60,000 | 5.25% |
| 3 | $30,000+ | $60,000+ | 5.7% |

**Standard Deduction**: $3,500 (S), $8,000 (MFJ)

---

#### Louisiana (LA)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $12,500 | 1.85% |
| 2 | $12,500 - $50,000 | 3.5% |
| 3 | $50,000+ | 4.25% |

**Standard Deduction**: Federal amount

---

#### Maine (ME)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $24,500 | $0 - $49,050 | 5.8% |
| 2 | $24,500 - $58,050 | $49,050 - $116,100 | 6.75% |
| 3 | $58,050+ | $116,100+ | 7.15% |

**Standard Deduction**: $14,600 (S), $29,200 (MFJ)

---

#### Maryland (MD)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $1,000 | 2.00% |
| 2 | $1,000 - $2,000 | 3.00% |
| 3 | $2,000 - $3,000 | 4.00% |
| 4 | $3,000 - $100,000 | 4.75% |
| 5 | $100,000 - $125,000 | 5.00% |
| 6 | $125,000 - $150,000 | 5.25% |
| 7 | $150,000 - $250,000 | 5.50% |
| 8 | $250,000+ | 5.75% |

**Local Tax**: 2.25% - 3.20% (varies by county)
**Standard Deduction**: 15% of AGI (min $1,800, max $2,550)

---

#### Minnesota (MN)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $30,070 | $0 - $43,950 | 5.35% |
| 2 | $30,070 - $98,760 | $43,950 - $174,610 | 6.80% |
| 3 | $98,760 - $183,340 | $174,610 - $304,970 | 7.85% |
| 4 | $183,340+ | $304,970+ | 9.85% |

**Standard Deduction**: $14,575 (S), $29,150 (MFJ)

---

#### Mississippi (MS)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $10,000 | 0% |
| 2 | $10,000+ | 4.70% |

**Standard Deduction**: $2,300 (S), $4,600 (MFJ)
**Notes**: Phasing to 4% by 2026

---

#### Missouri (MO)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $1,207 | 0% |
| 2 | $1,207 - $2,414 | 2.0% |
| 3 | $2,414 - $3,621 | 2.5% |
| 4 | $3,621 - $4,828 | 3.0% |
| 5 | $4,828 - $6,035 | 3.5% |
| 6 | $6,035 - $7,242 | 4.0% |
| 7 | $7,242 - $8,449 | 4.5% |
| 8 | $8,449+ | 4.80% |

**Standard Deduction**: Federal amount
**Notes**: Has some local income taxes

---

#### Montana (MT)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $20,500 | 4.7% |
| 2 | $20,500+ | 5.9% |

**Standard Deduction**: 20% of AGI (max $5,540 S, $11,080 MFJ)

---

#### Nebraska (NE)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $3,700 | $0 - $7,390 | 2.46% |
| 2 | $3,700 - $22,170 | $7,390 - $44,350 | 3.51% |
| 3 | $22,170 - $35,730 | $44,350 - $71,460 | 5.01% |
| 4 | $35,730+ | $71,460+ | 5.84% |

**Standard Deduction**: Federal amount

---

#### New Jersey (NJ)

| Bracket | Single | Rate |
|---------|--------|------|
| 1 | $0 - $20,000 | 1.4% |
| 2 | $20,000 - $35,000 | 1.75% |
| 3 | $35,000 - $40,000 | 3.5% |
| 4 | $40,000 - $75,000 | 5.525% |
| 5 | $75,000 - $500,000 | 6.37% |
| 6 | $500,000 - $1,000,000 | 8.97% |
| 7 | $1,000,000+ | 10.75% |

**SDI Rate**: 0.14% employee (2024)
**Notes**: No standard deduction, some local taxes

---

#### New Mexico (NM)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $5,500 | $0 - $8,000 | 1.7% |
| 2 | $5,500 - $11,000 | $8,000 - $16,000 | 3.2% |
| 3 | $11,000 - $16,000 | $16,000 - $24,000 | 4.7% |
| 4 | $16,000 - $210,000 | $24,000 - $315,000 | 4.9% |
| 5 | $210,000+ | $315,000+ | 5.9% |

**Standard Deduction**: Federal amount

---

#### New York (NY)

| Bracket | Single | Rate |
|---------|--------|------|
| 1 | $0 - $8,500 | 4.00% |
| 2 | $8,500 - $11,700 | 4.50% |
| 3 | $11,700 - $13,900 | 5.25% |
| 4 | $13,900 - $80,650 | 5.50% |
| 5 | $80,650 - $215,400 | 6.00% |
| 6 | $215,400 - $1,077,550 | 6.85% |
| 7 | $1,077,550 - $5,000,000 | 9.65% |
| 8 | $5,000,000 - $25,000,000 | 10.30% |
| 9 | $25,000,000+ | 10.90% |

**NYC Residents**: Additional 3.078% - 3.876%
**SDI Rate**: 0.5% (max $0.60/week)
**Standard Deduction**: $8,000 (S), $16,050 (MFJ)

---

#### North Dakota (ND)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $44,725 | $0 - $74,750 | 1.10% |
| 2 | $44,725 - $225,975 | $74,750 - $275,100 | 2.04% |
| 3 | $225,975+ | $275,100+ | 2.50% |

**Standard Deduction**: Federal amount

---

#### Ohio (OH)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $26,050 | 0% |
| 2 | $26,050 - $100,000 | 2.75% |
| 3 | $100,000+ | 3.50% |

**Notes**: Has significant local income taxes (most cities 1-3%)

---

#### Oklahoma (OK)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $1,000 | $0 - $2,000 | 0.25% |
| 2 | $1,000 - $2,500 | $2,000 - $5,000 | 0.75% |
| 3 | $2,500 - $3,750 | $5,000 - $7,500 | 1.75% |
| 4 | $3,750 - $4,900 | $7,500 - $9,800 | 2.75% |
| 5 | $4,900 - $7,200 | $9,800 - $12,200 | 3.75% |
| 6 | $7,200+ | $12,200+ | 4.75% |

**Standard Deduction**: $6,350 (S), $12,700 (MFJ)

---

#### Oregon (OR)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $4,050 | $0 - $8,100 | 4.75% |
| 2 | $4,050 - $10,200 | $8,100 - $20,400 | 6.75% |
| 3 | $10,200 - $125,000 | $20,400 - $250,000 | 8.75% |
| 4 | $125,000+ | $250,000+ | 9.90% |

**Standard Deduction**: $2,605 (S), $5,210 (MFJ)
**Notes**: Some local taxes (Portland metro)

---

#### Rhode Island (RI)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $73,450 | 3.75% |
| 2 | $73,450 - $166,950 | 4.75% |
| 3 | $166,950+ | 5.99% |

**SDI Rate**: 1.1% (temporary disability)
**Standard Deduction**: Federal amount

---

#### South Carolina (SC)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $3,200 | 0% |
| 2 | $3,200 - $16,040 | 3.0% |
| 3 | $16,040+ | 6.2% |

**Standard Deduction**: Federal amount
**Notes**: Phasing down to 6.0% by 2027

---

#### Vermont (VT)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $45,400 | $0 - $75,750 | 3.35% |
| 2 | $45,400 - $110,050 | $75,750 - $183,450 | 6.60% |
| 3 | $110,050 - $229,550 | $183,450 - $279,400 | 7.60% |
| 4 | $229,550+ | $279,400+ | 8.75% |

**Standard Deduction**: Federal amount

---

#### Virginia (VA)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $3,000 | 2% |
| 2 | $3,000 - $5,000 | 3% |
| 3 | $5,000 - $17,000 | 5% |
| 4 | $17,000+ | 5.75% |

**Standard Deduction**: $8,500 (S), $17,000 (MFJ)

---

#### Washington D.C.

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $10,000 | 4.0% |
| 2 | $10,000 - $40,000 | 6.0% |
| 3 | $40,000 - $60,000 | 6.5% |
| 4 | $60,000 - $250,000 | 8.5% |
| 5 | $250,000 - $500,000 | 9.25% |
| 6 | $500,000 - $1,000,000 | 9.75% |
| 7 | $1,000,000+ | 10.75% |

**Standard Deduction**: Federal amount

---

#### West Virginia (WV)

| Bracket | All Filers | Rate |
|---------|------------|------|
| 1 | $0 - $10,000 | 2.36% |
| 2 | $10,000 - $25,000 | 3.15% |
| 3 | $25,000 - $40,000 | 3.54% |
| 4 | $40,000 - $60,000 | 4.72% |
| 5 | $60,000+ | 5.12% |

**Notes**: Phasing down rates through 2027

---

#### Wisconsin (WI)

| Bracket | Single | MFJ | Rate |
|---------|--------|-----|------|
| 1 | $0 - $14,320 | $0 - $19,090 | 3.50% |
| 2 | $14,320 - $28,640 | $19,090 - $38,190 | 4.40% |
| 3 | $28,640 - $315,310 | $38,190 - $420,420 | 5.30% |
| 4 | $315,310+ | $420,420+ | 7.65% |

**Standard Deduction**: Sliding scale based on income

---

### State Tax Calculator Implementation

```swift
import Foundation

struct StateTaxCalculator: StateTaxCalculatorProtocol {

    private let taxDataProvider: TaxDataProviderProtocol

    func calculate(
        taxableIncome: Decimal,
        state: USState,
        filingStatus: FilingStatus,
        year: Int
    ) -> StateTaxResult {

        // No income tax states
        if state.hasNoIncomeTax {
            return StateTaxResult(
                state: state,
                taxableIncome: taxableIncome,
                incomeTax: 0,
                localTax: 0,
                sdi: 0,
                otherTaxes: 0,
                totalTax: 0,
                effectiveRate: 0,
                bracketBreakdown: nil
            )
        }

        let config = taxDataProvider.stateConfig(for: state, year: year)

        // Calculate state income tax
        let incomeTax: Decimal
        var bracketBreakdown: [BracketAmount]? = nil

        switch config.taxType {
        case .flatRate:
            incomeTax = taxableIncome * (config.flatRate ?? 0)

        case .progressive:
            let result = calculateProgressive(
                taxableIncome: taxableIncome,
                brackets: config.brackets?[filingStatus.rawValue] ?? [],
                standardDeduction: config.standardDeduction?[filingStatus.rawValue] ?? 0
            )
            incomeTax = result.tax
            bracketBreakdown = result.breakdown

        case .noTax:
            incomeTax = 0
        }

        // Calculate SDI if applicable
        let sdi = calculateSDI(income: taxableIncome, state: state, config: config)

        // Estimate local tax if applicable
        let localTax = calculateLocalTax(income: taxableIncome, state: state, config: config)

        let totalTax = incomeTax + sdi + localTax

        return StateTaxResult(
            state: state,
            taxableIncome: taxableIncome,
            incomeTax: incomeTax,
            localTax: localTax,
            sdi: sdi,
            otherTaxes: 0,
            totalTax: totalTax,
            effectiveRate: taxableIncome > 0 ? totalTax / taxableIncome : 0,
            bracketBreakdown: bracketBreakdown
        )
    }

    private func calculateProgressive(
        taxableIncome: Decimal,
        brackets: [TaxBracketConfig],
        standardDeduction: Decimal
    ) -> (tax: Decimal, breakdown: [BracketAmount]) {

        let adjustedIncome = max(0, taxableIncome - standardDeduction)

        guard adjustedIncome > 0, !brackets.isEmpty else {
            return (0, [])
        }

        var totalTax: Decimal = 0
        var breakdown: [BracketAmount] = []

        for bracket in brackets {
            let floor = bracket.floor
            let ceiling = bracket.ceiling ?? Decimal.greatestFiniteMagnitude

            if adjustedIncome > floor {
                let incomeInBracket = min(adjustedIncome, ceiling) - floor
                let taxInBracket = incomeInBracket * bracket.rate

                totalTax += taxInBracket
                breakdown.append(BracketAmount(
                    bracket: TaxBracket(
                        floor: floor,
                        ceiling: bracket.ceiling,
                        rate: bracket.rate,
                        baseTax: bracket.baseTax
                    ),
                    taxableInBracket: incomeInBracket,
                    taxPaid: taxInBracket
                ))
            }
        }

        return (totalTax, breakdown)
    }

    private func calculateSDI(
        income: Decimal,
        state: USState,
        config: StateTaxConfig
    ) -> Decimal {
        guard state.hasSDI,
              let sdiRate = config.sdiRate else {
            return 0
        }

        let wageBase = config.sdiWageBase ?? income
        let taxableWages = min(income, wageBase)

        return taxableWages * sdiRate
    }

    private func calculateLocalTax(
        income: Decimal,
        state: USState,
        config: StateTaxConfig
    ) -> Decimal {
        guard state.hasLocalTax,
              let localInfo = config.localTaxInfo,
              let avgRate = localInfo.averageRate else {
            return 0
        }

        // Use average rate as estimate
        // User can override with specific city in settings
        return income * avgRate
    }
}
```

---

## 4. Retirement Contribution Limits (2024)

| Account Type | Standard Limit | Catch-Up (50+) | Total (50+) |
|-------------|----------------|----------------|-------------|
| 401(k) | $23,000 | $7,500 | $30,500 |
| 403(b) | $23,000 | $7,500 | $30,500 |
| 457(b) | $23,000 | $7,500 | $30,500 |
| Traditional IRA | $7,000 | $1,000 | $8,000 |
| Roth IRA | $7,000 | $1,000 | $8,000 |
| SIMPLE IRA | $16,000 | $3,500 | $19,500 |
| SEP IRA | Lesser of 25% of comp or $69,000 | N/A | $69,000 |

### Employer Match Calculation

```
Employer Match = min(Employee Contribution, Salary × Match Percentage × Match Limit)

Example:
- Salary: $100,000
- Employee Contribution: $10,000
- Employer Match: 50% up to 6%
- Match = min($10,000, $100,000 × 0.50 × 0.06) = min($10,000, $3,000) = $3,000
```

### Swift Implementation

```swift
import Foundation

struct RetirementCalculator {

    func calculateMaxContribution(
        age: Int,
        accountType: RetirementAccountType,
        year: Int
    ) -> Decimal {
        let limits = RetirementLimits.defaults2024  // Should be from taxDataProvider

        let baseLimit: Decimal
        let catchUp: Decimal

        switch accountType {
        case .traditional401k, .roth401k, .a403b, .a457b:
            baseLimit = limits.limit401k
            catchUp = limits.catchUp401k
        case .traditionalIRA, .rothIRA:
            baseLimit = limits.limitIRA
            catchUp = limits.catchUpIRA
        case .simpleIRA:
            baseLimit = 16000
            catchUp = 3500
        case .sepIRA:
            baseLimit = 69000
            catchUp = 0
        }

        let isCatchUpEligible = age >= limits.catchUpAge
        return isCatchUpEligible ? baseLimit + catchUp : baseLimit
    }

    func calculateEmployerMatch(
        employeeContribution: Decimal,
        salary: Decimal,
        matchPercentage: Decimal,    // e.g., 0.50 for 50%
        matchLimit: Decimal          // e.g., 0.06 for 6%
    ) -> Decimal {
        let maxMatchableContribution = salary * matchLimit
        let contributionToMatch = min(employeeContribution, maxMatchableContribution)
        return contributionToMatch * matchPercentage
    }

    func calculate401kTaxSavings(
        traditionalContribution: Decimal,
        marginalRate: Decimal
    ) -> Decimal {
        return traditionalContribution * marginalRate
    }
}

enum RetirementAccountType: String, Codable {
    case traditional401k
    case roth401k
    case a403b = "403b"
    case a457b = "457b"
    case traditionalIRA
    case rothIRA
    case simpleIRA
    case sepIRA
}
```

---

## 5. Timeframe Conversions

### Standard Divisors

| Timeframe | Annual Divisor | Notes |
|-----------|----------------|-------|
| Annual | 1 | Base |
| Monthly | 12 | Calendar months |
| Bi-Weekly | 26 | Standard pay periods |
| Semi-Monthly | 24 | 1st and 15th |
| Weekly | 52 | Calendar weeks |
| Daily | 260 | Working days (52 × 5) |
| Hourly | 2,080 | Standard work hours (52 × 40) |

### Formula

```
Annual = Base
Monthly = Annual ÷ 12
Bi-Weekly = Annual ÷ 26
Semi-Monthly = Annual ÷ 24
Weekly = Annual ÷ 52
Daily = Annual ÷ 260
Hourly = Annual ÷ 2080
```

### Custom Working Hours

```
Daily = Annual ÷ (52 × Days Per Week)
Hourly = Annual ÷ (52 × Hours Per Week)
```

### Swift Implementation

```swift
import Foundation

struct TimeframeCalculator: TimeframeCalculatorProtocol {

    /// Standard conversion (40 hours/week, 5 days/week)
    func convert(annual: Decimal) -> TimeframeIncome {
        TimeframeIncome(annual: annual)
    }

    /// Custom working schedule
    func convert(
        annual: Decimal,
        hoursPerWeek: Decimal,
        daysPerWeek: Decimal
    ) -> TimeframeIncome {
        TimeframeIncome(
            annual: annual,
            hoursPerWeek: hoursPerWeek,
            daysPerWeek: daysPerWeek
        )
    }

    /// Convert from any timeframe to annual
    func toAnnual(amount: Decimal, from: Timeframe) -> Decimal {
        switch from {
        case .annual:
            return amount
        case .monthly:
            return amount * 12
        case .biWeekly:
            return amount * 26
        case .semiMonthly:
            return amount * 24
        case .weekly:
            return amount * 52
        case .daily:
            return amount * 260
        case .hourly:
            return amount * 2080
        }
    }

    /// Convert between any two timeframes
    func convert(
        amount: Decimal,
        from: Timeframe,
        to: Timeframe
    ) -> Decimal {
        let annual = toAnnual(amount: amount, from: from)
        let income = TimeframeIncome(annual: annual)

        switch to {
        case .annual: return income.annual
        case .monthly: return income.monthly
        case .biWeekly: return income.biWeekly
        case .semiMonthly: return annual / 24
        case .weekly: return income.weekly
        case .daily: return income.daily
        case .hourly: return income.hourly
        }
    }
}

enum Timeframe: String, Codable, CaseIterable {
    case annual
    case monthly
    case biWeekly
    case semiMonthly
    case weekly
    case daily
    case hourly

    var divisor: Decimal {
        switch self {
        case .annual: return 1
        case .monthly: return 12
        case .biWeekly: return 26
        case .semiMonthly: return 24
        case .weekly: return 52
        case .daily: return 260
        case .hourly: return 2080
        }
    }
}
```

---

## 6. Household Proportional Split

### Formula

```
Partner A's Share% = Partner A's Net Income ÷ Total Household Net Income
Partner A's Expense = Shared Expense × Partner A's Share%

Example:
- Patrick Net: $103,247/year
- Jensina Net: $22,000/year
- Total Household: $125,247
- Patrick's Share: 103,247 ÷ 125,247 = 82.4%
- Shared Rent: $3,272/month
- Patrick Pays: $3,272 × 0.824 = $2,696/month
- Jensina Pays: $3,272 × 0.176 = $576/month
```

### Swift Implementation

```swift
import Foundation

struct HouseholdCalculator {

    func calculateSplit(
        primaryNet: Decimal,
        partnerNet: Decimal,
        sharedExpenses: [Expense],
        method: SplitMethod
    ) -> HouseholdSplitResult {

        let totalNet = primaryNet + partnerNet

        let primaryRatio: Decimal
        let partnerRatio: Decimal

        switch method {
        case .proportional:
            primaryRatio = totalNet > 0 ? primaryNet / totalNet : 0.5
            partnerRatio = 1 - primaryRatio

        case .equal:
            primaryRatio = 0.5
            partnerRatio = 0.5

        case .custom(let customPrimaryRatio):
            primaryRatio = customPrimaryRatio
            partnerRatio = 1 - customPrimaryRatio
        }

        var expenseSplits: [ExpenseSplit] = []
        var primaryTotal: Decimal = 0
        var partnerTotal: Decimal = 0

        for expense in sharedExpenses {
            let monthly = expense.monthlyAmount
            let primaryAmount = monthly * primaryRatio
            let partnerAmount = monthly * partnerRatio

            expenseSplits.append(ExpenseSplit(
                expense: expense,
                primaryAmount: primaryAmount,
                partnerAmount: partnerAmount
            ))

            primaryTotal += primaryAmount
            partnerTotal += partnerAmount
        }

        return HouseholdSplitResult(
            primaryRatio: primaryRatio,
            partnerRatio: partnerRatio,
            primaryMonthlyTotal: primaryTotal,
            partnerMonthlyTotal: partnerTotal,
            expenseSplits: expenseSplits
        )
    }
}

struct HouseholdSplitResult {
    let primaryRatio: Decimal
    let partnerRatio: Decimal
    let primaryMonthlyTotal: Decimal
    let partnerMonthlyTotal: Decimal
    let expenseSplits: [ExpenseSplit]

    var primaryPercent: String {
        "\(NSDecimalNumber(decimal: primaryRatio * 100).doubleValue.formatted(.number.precision(.fractionLength(1))))%"
    }
}

struct ExpenseSplit {
    let expense: Expense
    let primaryAmount: Decimal
    let partnerAmount: Decimal
}
```

---

## 7. Complete Calculation Flow

```swift
import Foundation

/// Complete take-home calculation
func calculateTakeHome(input: TaxCalculationInput) -> TaxCalculationResult {

    // 1. Calculate pre-tax deductions
    let preTaxTotal = input.preTaxDeductions.reduce(0) { $0 + $1.annualAmount }
    let traditional401k = input.retirementContributions?.traditional401k ?? 0
    let totalPreTax = preTaxTotal + traditional401k

    // 2. Calculate federal taxable income
    let standardDeduction = getStandardDeduction(input.filingStatus)
    let federalTaxableIncome = max(0, input.grossIncome - totalPreTax - standardDeduction)

    // 3. Calculate federal tax
    let federalTax = calculateFederalTax(federalTaxableIncome, input.filingStatus)

    // 4. Calculate state tax (uses its own deductions)
    let stateTax = calculateStateTax(
        input.grossIncome - totalPreTax,
        input.state,
        input.filingStatus
    )

    // 5. Calculate FICA (on gross income, not reduced by 401k for Social Security)
    let fica = calculateFICA(input.grossIncome, input.filingStatus)

    // 6. Calculate post-tax deductions
    let postTaxTotal = input.postTaxDeductions.reduce(0) { $0 + $1.annualAmount }
    let roth401k = input.retirementContributions?.roth401k ?? 0
    let totalPostTax = postTaxTotal + roth401k

    // 7. Calculate net income
    let totalTaxes = federalTax + stateTax.totalTax + fica.totalFICA
    let netIncome = input.grossIncome - totalTaxes - totalPreTax - totalPostTax

    // 8. Convert to all timeframes
    let timeframes = TimeframeIncome(annual: netIncome)

    return TaxCalculationResult(
        income: CalculatedIncome(
            gross: input.grossIncome,
            net: netIncome,
            timeframes: timeframes
        ),
        taxBreakdown: TaxBreakdown(
            federal: federalTax,
            state: stateTax,
            fica: fica,
            totalTaxes: totalTaxes
        ),
        deductionsSummary: DeductionsSummary(
            preTax: totalPreTax,
            postTax: totalPostTax,
            retirement: input.retirementContributions
        ),
        effectiveRates: EffectiveRates(
            federal: federalTax.tax / input.grossIncome,
            state: stateTax.totalTax / input.grossIncome,
            fica: fica.totalFICA / input.grossIncome,
            total: totalTaxes / input.grossIncome
        )
    )
}
```

---

## Summary

| Calculation | Formula | Key Variables |
|-------------|---------|---------------|
| **Federal Tax** | BaseTax + (Income - Floor) × Rate | 7 brackets, 4 filing statuses |
| **Social Security** | min(Income, $168,600) × 6.2% | Wage base cap |
| **Medicare** | Income × 1.45% + Additional | 0.9% above threshold |
| **State Tax** | Varies by state | 50 states + DC |
| **Timeframe** | Annual ÷ Divisor | 6 standard timeframes |
| **Household Split** | NetA ÷ TotalNet | Proportional or custom |

All calculations use `Decimal` for precision. Tax data should be updated annually via remote configuration.
