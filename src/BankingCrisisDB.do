********************************************************************************
*                                                                              *
* Title    Laeven and Valencia (2018) Banking Crises Database Acquisition      *
* @author  Alessandro Pizzigolotto (NHH)                                       *
* @project BankingCrisisDB                                                     *
*                                                                              *
* Description: This script is able to download the original Laeven and         *
*   Valencia Systemic Banking Crises Database from the IMF Original Article,   *
*   and re-elaborate the Excel File information such that it creates a spell   *
*   dataset (in .dta format) for which each country has a systemic banking     *
*   crisis entry, the number of the crisis, the main effects of the crises and *
*   flags for whether there are multiple crises other than the considered one. *
*   To uniquely identify countries, we are using the ISO 1366-1 Numeric Code   *
*   format, in a way that it is possible to link the dataset to other sources, *
*   especially in Stata through the community-written command 'kountry'.       *
*                                                                              *
*   Small Update: We complement the Laeven and Valencia Systemic Banking       *
*   Database with the Behavioral Finance and Financial Stability Project       *
*   Banking and Systemic Crises Database building on the original Reinhart and *
*   Rogoff 'This Time is Different' Database. This gives us a more extended    *
*   spell data series (we drop it below 1950) and other countries, and it      *
*   allows us to add other countries.                                          *
*                                                                              *
* P.S.: It does not work locally, you should be able to connect to the web.    *
*                                                                              *
********************************************************************************

********************************************************************************
* Preliminary Commands                                                         *
********************************************************************************
clear all
capture log close
set more off

* for older version of Stata
set matsize 11000

* for Stata in my poor Linux
set max_memory 6g

********************************************************************************
* Dependencies                                                                 *
********************************************************************************

* User-Written Command 'kountry', (c) to Raciborski (2008).
* for more info, https://journals.sagepub.com/doi/pdf/10.1177/1536867X0800800305
capture ssc install kountry

********************************************************************************
* Environment Variables Definition                                             *
* Rule-of-Thumb: PATHNAME do not finish with 'slash'                           *
********************************************************************************

* change here the absolute PATHNAME of your workspace
* this script is supposed to be located into ~/src, but does not really matter
gl BASE_PATH = "~/Documents/Projects/LaevenValenciaBankingCrises"

* directories and pointers definition
local stubs  = "temp data log"
local gnames = "DATA OUT LOG"
local n: word count `gnames'
tokenize "`gnames'"
forvalues i = 1/`n' {
    gl ``i''_PATH = "${BASE_PATH}/`: word `i' of `stubs''"
    * make directory
    capture mkdir "${``i''_PATH}", pub
}

********************************************************************************
* Log Opening and Settings                                                     *
********************************************************************************

* generate pseudo timestamp
gl T_STRING = subinstr("`c(current_date)'"+"_"+"`c(current_time)'", ":", "_", .)
gl T_STRING = subinstr("${T_STRING}", " ", "_", .)

* open log file
capture log using "${LOG_PATH}/BankingCrisisDB_${T_STRING}", text replace

********************************************************************************
* Copy and Unzip Excel File from IMF Source                                    *
********************************************************************************

* download from IMF Economic Review Website
copy ///
    "https://static-content.springer.com/esm/art%3A10.1057%2Fs41308-020-00107-3/MediaObjects/41308_2020_107_MOESM1_ESM.xlsx" ///
    "${DATA_PATH}/source.xlsx"

* just because I feel safe in the workspace
cd "${BASE_PATH}"

********************************************************************************
* Data Importing from Excel Dataset (a bit redundant but it works).            *
********************************************************************************

* Crisis Years Sheet, saved in a tempfile
import excel using "${DATA_PATH}/source.xlsx", ///
    sh("Crisis Years") cellra("A3:E167") clear
* rename the column headers
rename (A B C D E) (cnames sysbank_c curr_c sovdebt_c sovdebtres_res)

foreach var of varlist *_c sovdebtres_res {
    replace `var' = subinstr(`var', ", ", ",", .)
    replace `var' = "" if `var' == "n.a."
    if strpos("`var'", "_res") {
        local name = subinstr("`var'", "_res", "", .)
    }
    else {
        local name = subinstr("`var'", "_c", "", .)
    }
    
    split `var', g(`name') p (",") destring
    drop `var'
}

* string trimming
replace cnames = strtrim(cnames)

* fix names that are not identified by kountry
replace cnames = "Serbia"                if strpos(cnames, "Serbia")
replace cnames = "Hong Kong"             if strpos(cnames, "Hong Kong")
replace cnames = "China"                 if strpos(cnames, "China")
replace cnames = "Ivory Coast"           if strpos(cnames, "Ivoire")
replace cnames = "Sao Tome and Principe" if strpos(cnames, "Principe")
replace cnames = "Iran"                  if strpos(cnames, "Iran")
replace cnames = "Laos"                  if strpos(cnames, "Lao People")
replace cnames = "Ex-Yugoslavia"         if strpos(cnames, "Yugoslavia")
replace cnames = "Gambia"                if strpos(cnames, "Gambia")
replace cnames = "Slovak Republic"       if strpos(cnames, "Slovak")
replace cnames = "Kyrgyzstan"            if strpos(cnames, "Kyrgyz")
replace cnames = "Macedonia"             if strpos(cnames, "Macedonia")

replace cnames = "Central African Republic" ///
    if strpos(cnames, "Central African")

* split the two Congoes
replace cnames = "Congo, Democratic Republic of the" ///
    if strpos(cnames, "Congo, Dem. Rep. of")
replace cnames = "Congo, Republic of the" ///
    if strpos(cnames, "Congo, Rep. of")

* create the ISO 3166-1 Numeric Country Codes
kountry cnames, from(other) st 

* we would like to keep Ex-Yugoslavia, so we split it from Serbia
replace _ISO3N_ = 688 if cnames == "Serbia"
replace _ISO3N_ = 890 if cnames == "Ex-Yugoslavia"
* rename the kountry generated variable
rename _ISO3N_ isocodes

preserve
* save the country names
keep cnames isocodes
rename cnames cnames1
tempfile names
save `names'
restore
drop cnames

tempfile cyears
save `cyears'

* Crisis Spell Data and Outcomes, saved in a tempfile
import excel using "${DATA_PATH}/source.xlsx", ///
    sh("Crisis Resolution and Outcomes") cellra("A2:K152") clear
rename (A B C D E F G J K) ///
    (cnames startyear endyear yloss fcost_v1 fcost_v2 fcost_v3 maxnpl gsdebt)
drop H I

* remove cdots from the string to be replaced by missing values
foreach var of varlist yloss fcost_* maxnpl gsdebt {
    replace `var' = "" if `var' == "..."
    replace `var' = "" if `var' == "…"
    destring `var', replace
}

* remove tags, see documentation in the original working paper
local tags = "4/ 6/ 7/ 8/"
foreach var of varlist cnames endyear {
    foreach l in `tags' {
        replace `var' = subinstr(`var', " `l'", "", .)
    }
}

* set ongoing crisis to missing by convention
replace endyear = "" if endyear == "ongoing"
destring endyear, replace

* string trimming
replace cnames = strtrim(cnames)

* fix names that are not identified by kountry
replace cnames = "Serbia"                if  strpos(cnames, "Serbia")
replace cnames = "Hong Kong"             if  strpos(cnames, "Hong Kong")
replace cnames = "China"                 if  strpos(cnames, "China")
replace cnames = "Ivory Coast"           if  strpos(cnames, "Ivoire")
replace cnames = "Sao Tome and Principe" if ustrpos(cnames, "Príncipe")
replace cnames = "Iran"                  if  strpos(cnames, "Iran")
replace cnames = "Laos"                  if  strpos(cnames, "Lao People")
replace cnames = "Ex-Yugoslavia"         if  strpos(cnames, "Yugoslavia")
replace cnames = "Gambia"                if  strpos(cnames, "Gambia")
replace cnames = "Slovak Republic"       if  strpos(cnames, "Slovak")
replace cnames = "Kyrgyzstan"            if  strpos(cnames, "Kyrgyz")
replace cnames = "Macedonia"             if  strpos(cnames, "Macedonia")

replace cnames = "Central African Republic" ///
    if strpos(cnames, "Central African")

* split the two Congoes
replace cnames = "Congo, Democratic Republic of the" ///
    if strpos(cnames, "Congo, Dem Rep")
replace cnames = "Congo, Republic of the" ///
    if strpos(cnames, "Congo, Rep")

* create the ISO 3166 Numeric Country Codes
kountry cnames, from(other) st

* we would like to keep Ex-Yugoslavia, so we split it from Serbia
replace _ISO3N_ = 688 if cnames == "Serbia"
replace _ISO3N_ = 890 if cnames == "Ex-Yugoslavia"
* rename the kountry generated variable
rename _ISO3N_ isocodes
drop cnames

tempfile ceffect
save `ceffect'

********************************************************************************
* Generation of the Dataset on Systemic Banking Crises and Consequences.       *
*   We create a flag for the presence of multiple (correlated crises).         *
********************************************************************************

* initialize crises years dataset
u `cyears', clear

preserve
keep isocodes sysbank?
reshape long sysbank, i(isocodes) j(fsysbank)
drop if missing(sysbank) & fsysbank > 1
rename sysbank startyear
replace fsysbank = 0 if missing(startyear)
* merge crises years with spell and outcomes
merge 1:1 isocodes startyear using `ceffect', nogen
tempfile aggregate
save `aggregate'
restore

* generate other crises flags
local listcrises = "curr sovdebt sovdebtres"

foreach crisis in `listcrises' {
    preserve
    keep isocodes `crisis'?
    reshape long `crisis', i(isocodes) j(f`crisis')
    drop if missing(`crisis')
    rename `crisis' startyear
    merge 1:1 isocodes startyear using `aggregate'
    g has`crisis' = (_m == 3)
    keep if _m != 1
    drop _m f`crisis'
    tempfile aggregate
    save `aggregate'
    restore
}

********************************************************************************
* Data Importing directly from the Behavioral Finance and Financial Stability  *
*   Project Website and Spell Dataset Generation.                              *
********************************************************************************

* Harvard Kennedy School Direct Link
import excel using ///
    "https://www.hbs.edu/behavioral-finance-and-financial-stability/Documents/ChartData/MapCharts/20160923_global_crisis_data.xlsx", ///
    clear

* drop Excel header
drop in 1/2
keep C D E G Z AA
rename (C D E G Z AA) (cnames year bcrisis scrisis ccrisis icrisis)
foreach var of varlist * {
    * missing values cleaning
    replace `var' = "" if `var' == "n/a"
}

destring year, replace 
destring *crisis, replace

* Ivory Coast name correction
replace cnames = "Ivory Coast" if cnames == "CoteD'Ivoire"

* generate a dummy when simultaneous banking and systemic crisis
g sysbank_c = (bcrisis == 1 & scrisis == 1)
* consider just crises after 1950 and drop missing values
drop if missing(sysbank_c) | year < 1950
sort cnames year
* generate groups when crisis status changes
bys cnames : g aux = 1 if sysbank_c[_n] != sysbank_c[_n-1]
bys cnames : replace aux = sum(aux)
* this is equal to one if there is no systemic crisis
bys cnames : egen nocrisis = max(aux)
* time window of the ongoing systemic crisis
bys cnames aux : egen startyear = min(year)
bys cnames aux : egen endyear   = max(year)
* a simultaneous currency crisis strikes during the systemic crisis
bys cnames aux : egen hascurr   = max(ccrisis)
* a simultaneous inflation crisis strikes during the systemic crisis
bys cnames aux : egen hasinfl   = max(icrisis)
* switch to spell dataset
collapse (mean) startyear endyear nocrisis sysbank_c hascurr hasinfl, ///
    by(cnames aux)
* drop duplicates
drop if sysbank_c == 0 & (nocrisis != 1)
* generate counter of systemic crises
bys cnames : g fsysbank = _n
* set frequency to zero when no crises
replace fsysbank = 0 if nocrisis == 1
foreach var of varlist *year hascurr {
    * clean variables if the are no crises
    replace `var' = . if nocrisis == 1
}

keep cnames fsysbank *year hascurr hasinfl
* create the ISO 3166 Numeric Country Codes
kountry cnames, from(other) st
* rename the kountry generated variable and the variables we want to compare
rename (_ISO3N_ cnames endyear fsysbank hascurr) ///
    (isocodes cnames2 endyear_rr fsysbank_rr hascurr_rr)

tempfile rryears
save `rryears'

********************************************************************************
* Merge BFFS Project Banking Crises Data with Laeven and Valencia.             *
*   Keep endyear from Laeven and Valencia if available (less shaky).           *
*   Cut duration if more than 5 years to just 5, to harmonize with LV Dataset. *
*   Add Source Dummy, no crisis cleaning, and create labels.                   *
********************************************************************************

* start with Laeven and Valencia first
u `aggregate', clear
* generate source indicator
g lvsource = 1
* merge with BFFS project
merge 1:1 isocodes startyear using `rryears'
* generate source indicator
replace lvsource = 0 if missing(lvsource)
g rrsource = (_m != 1)
drop _m

* replace the last year of crisis from the BFFS Data if missing in LV
replace endyear = endyear_rr    if missing(endyear)
* truncate crisis duration if in the BFFS Data it is longer than 5 years
replace endyear = startyear + 5 if (endyear - startyear) > 5

* replace simultaneous currency crisis if it comes from BFFS Data
replace hascurr = hascurr_rr ///
    if hascurr != hascurr_rr & !missing(startyear) & !missing(hascurr_rr)
* replace multiple simultaneous currency crises because 
replace hascurr = 1 if hascurr > 1 & !missing(hascurr)
foreach var of varlist has* {
    replace `var' = . if missing(startyear)
}

drop fsysbank fsysbank_rr
sort isocodes startyear
bys isocodes : g fsysbank = _n
replace fsysbank = 0 if missing(startyear)

* merge back names from Laeven and Valencia
merge m:1 isocodes using `names', nogen
g cnames = cnames1
replace cnames = cnames2 if cnames == ""
* create labmask for isocodes
labmask isocodes, values(cnames)
drop cnames* *_rr

* drop if more events mechanically filed
bys isocodes : egen aux = total(fsysbank)
drop if aux > 0 & fsysbank == 0
drop aux

* fix overlaps in crises  with LV > BFFS
bys isocodes : g aux1 = 1 if startyear[_n] < endyear[_n-1]
replace aux1 = . if fsysbank == 1
bys isocodes : g aux2 = 1 if aux1[_n+1] == 1
egen aux3 = rowtotal(aux1 aux2)
drop if aux3 == 1 & rrsource == 1
drop aux? fsysbank
sort isocodes startyear
bys isocodes : g fsysbank = _n
replace fsysbank = 0 if missing(startyear)

********************************************************************************
* Labelling, saving, and cleaning temporary files.                             *
********************************************************************************

label variable fsysbank      "Number of Systemic Banking Crises"
label variable startyear     "Crisis' Starting Year"
label variable endyear       "Crisis' Ending Year (missing if ongoing)"
label variable yloss         "Output Loss (% of GDP)"
label variable fcost_v1      "Fiscal Cost (% of GDP)"
label variable fcost_v2      "Fiscal Cost (% of GDP), net"
label variable fcost_v3      "Fiscal Cost (% of Financial Sector Assets)"
label variable maxnpl        "Peak NPLs (% of Total Loans)"
label variable gsdebt        "Increase in Public Debt (% of GDP)"
label variable hascurr       "1 = Simultaneous Currency Crisis (LV)"
label variable hassovdebt    "1 = Simultaneous Sovereign Debt Crisis (LV)"
label variable hassovdebtres "1 = Simultaneous Sovereign Debt Restructuring (LV)"

label variable hasinfl       "1 = Simultaneous Inflation Crisis (BFFS)"
label variable lvsource      "Laeven and Valencia (LV, 2018) Source"
label variable rrsource      "(BFFS) Project Source"

sort isocodes startyear
unab all : *
local not = "isocodes fsysbank startyear endyear has* ??source"
local all : list all - not
order isocodes fsysbank startyear endyear has* `all' ??source
label data "Laeven and Valencia (2018) Systemic Banking Crises + BFFS Project"
compress
save "${OUT_PATH}/LaevenValencia2018_sysBankingCrisesDB.dta", replace

* cleanup temp
local files: dir "${DATA_PATH}" files "*"
foreach file of local files {
    rm "${DATA_PATH}/`file'"
}

rmdir "${DATA_PATH}"

********************************************************************************
* Closing Commands                                                             *
********************************************************************************

capture log close
exit
