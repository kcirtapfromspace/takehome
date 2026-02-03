import Foundation

// MARK: - Decimal Parsing
extension Decimal {
    /// Initialize from a string, with validation
    init?(parsing string: String) {
        guard let decimal = Decimal(string: string) else {
            return nil
        }
        self = decimal
    }

    /// Safe parsing that returns a result
    static func parse(_ string: String) throws -> Decimal {
        guard let decimal = Decimal(string: string) else {
            throw AppError.invalidDecimal(string)
        }
        return decimal
    }
}

// MARK: - FFI Conversions
extension TaxCalculationResult {
    init(from ffi: TaxResultFfi) throws {
        self.grossAnnual = try Decimal.parse(ffi.grossAnnual)
        self.netAnnual = try Decimal.parse(ffi.netAnnual)
        self.timeframes = try TimeframeIncome(
            annual: Decimal.parse(ffi.netAnnual),
            monthly: Decimal.parse(ffi.netMonthly),
            biWeekly: Decimal.parse(ffi.netBiweekly),
            weekly: Decimal.parse(ffi.netWeekly),
            daily: Decimal.parse(ffi.netDaily),
            hourly: Decimal.parse(ffi.netHourly)
        )
        self.takeHomePercentage = try Decimal.parse(ffi.takeHomePercentage)

        self.federalTax = try Decimal.parse(ffi.federalTax)
        self.federalEffectiveRate = try Decimal.parse(ffi.federalEffectiveRate)
        self.federalMarginalRate = try Decimal.parse(ffi.federalMarginalRate)

        self.stateCode = ffi.stateCode
        self.stateIncomeTax = try Decimal.parse(ffi.stateIncomeTax)
        self.stateLocalTax = try Decimal.parse(ffi.stateLocalTax)
        self.stateSDI = try Decimal.parse(ffi.stateSdi)
        self.stateTotalTax = try Decimal.parse(ffi.stateTotalTax)

        self.socialSecurity = try Decimal.parse(ffi.socialSecurity)
        self.medicare = try Decimal.parse(ffi.medicare)
        self.additionalMedicare = try Decimal.parse(ffi.additionalMedicare)
        self.ficaTotal = try Decimal.parse(ffi.ficaTotal)

        self.totalTaxes = try Decimal.parse(ffi.totalTaxes)
        self.totalEffectiveRate = try Decimal.parse(ffi.totalEffectiveRate)
    }
}

extension ScenarioComparison {
    init(from ffi: ScenarioComparisonFfi) throws {
        self.base = try TaxCalculationResult(from: ffi.base)
        self.scenario = try TaxCalculationResult(from: ffi.scenario)
        self.netDifference = try Decimal.parse(ffi.netDifference)
        self.monthlyDifference = try Decimal.parse(ffi.monthlyDifference)
        self.isPositive = ffi.isPositive
    }
}

extension TimeframeIncome {
    init(from ffi: TimeframeFfi) throws {
        self.annual = try Decimal.parse(ffi.annual)
        self.monthly = try Decimal.parse(ffi.monthly)
        self.biWeekly = try Decimal.parse(ffi.biWeekly)
        self.weekly = try Decimal.parse(ffi.weekly)
        self.daily = try Decimal.parse(ffi.daily)
        self.hourly = try Decimal.parse(ffi.hourly)
    }
}

extension HouseholdSplit {
    init(from ffi: HouseholdSplitFfi) throws {
        self.primaryRatio = try Decimal.parse(ffi.primaryRatio)
        self.partnerRatio = try Decimal.parse(ffi.partnerRatio)
        self.primaryAmount = try Decimal.parse(ffi.primaryAmount)
        self.partnerAmount = try Decimal.parse(ffi.partnerAmount)
    }
}
