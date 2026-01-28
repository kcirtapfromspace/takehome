//! US State definitions and properties

use serde::{Deserialize, Serialize};

/// All US states and territories
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
pub enum USState {
    Alabama,
    Alaska,
    Arizona,
    Arkansas,
    #[default]
    California,
    Colorado,
    Connecticut,
    Delaware,
    Florida,
    Georgia,
    Hawaii,
    Idaho,
    Illinois,
    Indiana,
    Iowa,
    Kansas,
    Kentucky,
    Louisiana,
    Maine,
    Maryland,
    Massachusetts,
    Michigan,
    Minnesota,
    Mississippi,
    Missouri,
    Montana,
    Nebraska,
    Nevada,
    NewHampshire,
    NewJersey,
    NewMexico,
    NewYork,
    NorthCarolina,
    NorthDakota,
    Ohio,
    Oklahoma,
    Oregon,
    Pennsylvania,
    RhodeIsland,
    SouthCarolina,
    SouthDakota,
    Tennessee,
    Texas,
    Utah,
    Vermont,
    Virginia,
    Washington,
    WashingtonDC,
    WestVirginia,
    Wisconsin,
    Wyoming,
}

impl USState {
    /// Two-letter state code
    pub fn code(&self) -> &'static str {
        match self {
            USState::Alabama => "AL",
            USState::Alaska => "AK",
            USState::Arizona => "AZ",
            USState::Arkansas => "AR",
            USState::California => "CA",
            USState::Colorado => "CO",
            USState::Connecticut => "CT",
            USState::Delaware => "DE",
            USState::Florida => "FL",
            USState::Georgia => "GA",
            USState::Hawaii => "HI",
            USState::Idaho => "ID",
            USState::Illinois => "IL",
            USState::Indiana => "IN",
            USState::Iowa => "IA",
            USState::Kansas => "KS",
            USState::Kentucky => "KY",
            USState::Louisiana => "LA",
            USState::Maine => "ME",
            USState::Maryland => "MD",
            USState::Massachusetts => "MA",
            USState::Michigan => "MI",
            USState::Minnesota => "MN",
            USState::Mississippi => "MS",
            USState::Missouri => "MO",
            USState::Montana => "MT",
            USState::Nebraska => "NE",
            USState::Nevada => "NV",
            USState::NewHampshire => "NH",
            USState::NewJersey => "NJ",
            USState::NewMexico => "NM",
            USState::NewYork => "NY",
            USState::NorthCarolina => "NC",
            USState::NorthDakota => "ND",
            USState::Ohio => "OH",
            USState::Oklahoma => "OK",
            USState::Oregon => "OR",
            USState::Pennsylvania => "PA",
            USState::RhodeIsland => "RI",
            USState::SouthCarolina => "SC",
            USState::SouthDakota => "SD",
            USState::Tennessee => "TN",
            USState::Texas => "TX",
            USState::Utah => "UT",
            USState::Vermont => "VT",
            USState::Virginia => "VA",
            USState::Washington => "WA",
            USState::WashingtonDC => "DC",
            USState::WestVirginia => "WV",
            USState::Wisconsin => "WI",
            USState::Wyoming => "WY",
        }
    }

    /// Full state name
    pub fn name(&self) -> &'static str {
        match self {
            USState::Alabama => "Alabama",
            USState::Alaska => "Alaska",
            USState::Arizona => "Arizona",
            USState::Arkansas => "Arkansas",
            USState::California => "California",
            USState::Colorado => "Colorado",
            USState::Connecticut => "Connecticut",
            USState::Delaware => "Delaware",
            USState::Florida => "Florida",
            USState::Georgia => "Georgia",
            USState::Hawaii => "Hawaii",
            USState::Idaho => "Idaho",
            USState::Illinois => "Illinois",
            USState::Indiana => "Indiana",
            USState::Iowa => "Iowa",
            USState::Kansas => "Kansas",
            USState::Kentucky => "Kentucky",
            USState::Louisiana => "Louisiana",
            USState::Maine => "Maine",
            USState::Maryland => "Maryland",
            USState::Massachusetts => "Massachusetts",
            USState::Michigan => "Michigan",
            USState::Minnesota => "Minnesota",
            USState::Mississippi => "Mississippi",
            USState::Missouri => "Missouri",
            USState::Montana => "Montana",
            USState::Nebraska => "Nebraska",
            USState::Nevada => "Nevada",
            USState::NewHampshire => "New Hampshire",
            USState::NewJersey => "New Jersey",
            USState::NewMexico => "New Mexico",
            USState::NewYork => "New York",
            USState::NorthCarolina => "North Carolina",
            USState::NorthDakota => "North Dakota",
            USState::Ohio => "Ohio",
            USState::Oklahoma => "Oklahoma",
            USState::Oregon => "Oregon",
            USState::Pennsylvania => "Pennsylvania",
            USState::RhodeIsland => "Rhode Island",
            USState::SouthCarolina => "South Carolina",
            USState::SouthDakota => "South Dakota",
            USState::Tennessee => "Tennessee",
            USState::Texas => "Texas",
            USState::Utah => "Utah",
            USState::Vermont => "Vermont",
            USState::Virginia => "Virginia",
            USState::Washington => "Washington",
            USState::WashingtonDC => "Washington D.C.",
            USState::WestVirginia => "West Virginia",
            USState::Wisconsin => "Wisconsin",
            USState::Wyoming => "Wyoming",
        }
    }

    /// States with no income tax
    pub fn has_no_income_tax(&self) -> bool {
        matches!(
            self,
            USState::Alaska
                | USState::Florida
                | USState::Nevada
                | USState::NewHampshire
                | USState::SouthDakota
                | USState::Tennessee
                | USState::Texas
                | USState::Washington
                | USState::Wyoming
        )
    }

    /// States with flat tax rate
    pub fn has_flat_tax(&self) -> bool {
        matches!(
            self,
            USState::Colorado
                | USState::Illinois
                | USState::Indiana
                | USState::Kentucky
                | USState::Massachusetts
                | USState::Michigan
                | USState::NorthCarolina
                | USState::Pennsylvania
                | USState::Utah
        )
    }

    /// States with State Disability Insurance (SDI)
    pub fn has_sdi(&self) -> bool {
        matches!(
            self,
            USState::California
                | USState::Hawaii
                | USState::NewJersey
                | USState::NewYork
                | USState::RhodeIsland
        )
    }

    /// States with local income taxes
    pub fn has_local_tax(&self) -> bool {
        matches!(
            self,
            USState::Alabama
                | USState::Colorado
                | USState::Delaware
                | USState::Indiana
                | USState::Iowa
                | USState::Kentucky
                | USState::Maryland
                | USState::Michigan
                | USState::Missouri
                | USState::NewJersey
                | USState::NewYork
                | USState::Ohio
                | USState::Oregon
                | USState::Pennsylvania
                | USState::WestVirginia
        )
    }

    /// Get all states
    pub fn all() -> &'static [USState] {
        &[
            USState::Alabama,
            USState::Alaska,
            USState::Arizona,
            USState::Arkansas,
            USState::California,
            USState::Colorado,
            USState::Connecticut,
            USState::Delaware,
            USState::Florida,
            USState::Georgia,
            USState::Hawaii,
            USState::Idaho,
            USState::Illinois,
            USState::Indiana,
            USState::Iowa,
            USState::Kansas,
            USState::Kentucky,
            USState::Louisiana,
            USState::Maine,
            USState::Maryland,
            USState::Massachusetts,
            USState::Michigan,
            USState::Minnesota,
            USState::Mississippi,
            USState::Missouri,
            USState::Montana,
            USState::Nebraska,
            USState::Nevada,
            USState::NewHampshire,
            USState::NewJersey,
            USState::NewMexico,
            USState::NewYork,
            USState::NorthCarolina,
            USState::NorthDakota,
            USState::Ohio,
            USState::Oklahoma,
            USState::Oregon,
            USState::Pennsylvania,
            USState::RhodeIsland,
            USState::SouthCarolina,
            USState::SouthDakota,
            USState::Tennessee,
            USState::Texas,
            USState::Utah,
            USState::Vermont,
            USState::Virginia,
            USState::Washington,
            USState::WashingtonDC,
            USState::WestVirginia,
            USState::Wisconsin,
            USState::Wyoming,
        ]
    }

    /// Parse from state code
    pub fn from_code(code: &str) -> Option<USState> {
        match code.to_uppercase().as_str() {
            "AL" => Some(USState::Alabama),
            "AK" => Some(USState::Alaska),
            "AZ" => Some(USState::Arizona),
            "AR" => Some(USState::Arkansas),
            "CA" => Some(USState::California),
            "CO" => Some(USState::Colorado),
            "CT" => Some(USState::Connecticut),
            "DE" => Some(USState::Delaware),
            "FL" => Some(USState::Florida),
            "GA" => Some(USState::Georgia),
            "HI" => Some(USState::Hawaii),
            "ID" => Some(USState::Idaho),
            "IL" => Some(USState::Illinois),
            "IN" => Some(USState::Indiana),
            "IA" => Some(USState::Iowa),
            "KS" => Some(USState::Kansas),
            "KY" => Some(USState::Kentucky),
            "LA" => Some(USState::Louisiana),
            "ME" => Some(USState::Maine),
            "MD" => Some(USState::Maryland),
            "MA" => Some(USState::Massachusetts),
            "MI" => Some(USState::Michigan),
            "MN" => Some(USState::Minnesota),
            "MS" => Some(USState::Mississippi),
            "MO" => Some(USState::Missouri),
            "MT" => Some(USState::Montana),
            "NE" => Some(USState::Nebraska),
            "NV" => Some(USState::Nevada),
            "NH" => Some(USState::NewHampshire),
            "NJ" => Some(USState::NewJersey),
            "NM" => Some(USState::NewMexico),
            "NY" => Some(USState::NewYork),
            "NC" => Some(USState::NorthCarolina),
            "ND" => Some(USState::NorthDakota),
            "OH" => Some(USState::Ohio),
            "OK" => Some(USState::Oklahoma),
            "OR" => Some(USState::Oregon),
            "PA" => Some(USState::Pennsylvania),
            "RI" => Some(USState::RhodeIsland),
            "SC" => Some(USState::SouthCarolina),
            "SD" => Some(USState::SouthDakota),
            "TN" => Some(USState::Tennessee),
            "TX" => Some(USState::Texas),
            "UT" => Some(USState::Utah),
            "VT" => Some(USState::Vermont),
            "VA" => Some(USState::Virginia),
            "WA" => Some(USState::Washington),
            "DC" => Some(USState::WashingtonDC),
            "WV" => Some(USState::WestVirginia),
            "WI" => Some(USState::Wisconsin),
            "WY" => Some(USState::Wyoming),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_income_tax_states() {
        assert!(USState::Texas.has_no_income_tax());
        assert!(USState::Florida.has_no_income_tax());
        assert!(USState::Nevada.has_no_income_tax());
        assert!(!USState::California.has_no_income_tax());
        assert!(!USState::NewYork.has_no_income_tax());
    }

    #[test]
    fn test_flat_tax_states() {
        assert!(USState::Colorado.has_flat_tax());
        assert!(USState::Illinois.has_flat_tax());
        assert!(!USState::California.has_flat_tax());
    }

    #[test]
    fn test_sdi_states() {
        assert!(USState::California.has_sdi());
        assert!(USState::NewYork.has_sdi());
        assert!(!USState::Texas.has_sdi());
    }

    #[test]
    fn test_from_code() {
        assert_eq!(USState::from_code("CA"), Some(USState::California));
        assert_eq!(USState::from_code("ca"), Some(USState::California));
        assert_eq!(USState::from_code("TX"), Some(USState::Texas));
        assert_eq!(USState::from_code("XX"), None);
    }

    #[test]
    fn test_all_states_count() {
        assert_eq!(USState::all().len(), 51); // 50 states + DC
    }
}
