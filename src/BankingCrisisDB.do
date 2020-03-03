********************************************************************************
*                                                                              *
* Title:       Laeven and Valencia (2018) Banking Crises Database Acquisition  *
* Author:      Alessandro Pizzigolotto (NHH)                                   *
* Language:    Stata (sigh, sorry)                                             *
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
* Rule-of-Thumb: PATHNAME do not finish with "slash"                           *
********************************************************************************

* change here the absolute PATHNAME of your workspace
* this script is supposed to be located into ~/src, but does not really matter
gl BASE_PATH = "~/Documents/Projects/LaevenValenciaBankingCrises"

* directories and pointers definition
local stubs  = "temp res log"
local gnames = "DATA OUT LOG"
local n: word count `gnames'
tokenize "`gnames'"
forvalues i = 1/`n' {
    gl ``i''_PATH = "${BASE_PATH}/`: word `i' of `stubs''"
    * check if directory already exists
    capture confirm file "${``i''_PATH}"
    if _rc {
        * make directory
        mkdir "${``i''_PATH}", pub
    }
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

* download from IMF Working Papers Website
copy ///
    "https://www.imf.org/~/media/Files/Publications/WP/2018/datasets/wp18206.ashx" ///
    "${DATA_PATH}/source.zip"

* change to temp directory to unzip
cd "${DATA_PATH}"
unzipfile source.zip
local files : dir "${DATA_PATH}" files "*.xlsx"
if "`c(os)'" == "Windows" {
    !ren `files' "source.xlsx"
}
else {
    !mv -f `files' "source.xlsx"
}

* just because I feel safe in the workspace
cd "${BASE_PATH}"

********************************************************************************
* Data Importing from Excel Dataset (a bit redundant but it works).            *
********************************************************************************

* Crisis Years Sheet, saved in a tempfile
import excel using "${DATA_PATH}/source.xlsx", ///
    sh("Crisis Years") cellra("A3:E167") clear

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

labmask isocodes, values(cnames)
drop cnames
order isocodes

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
replace cnames = "Serbia"                if strpos(cnames, "Serbia")
replace cnames = "Hong Kong"             if strpos(cnames, "Hong Kong")
replace cnames = "China"                 if strpos(cnames, "China")
replace cnames = "Ivory Coast"           if strpos(cnames, "Ivoire")
replace cnames = "Sao Tome and Principe" if ustrpos(cnames, "Príncipe")
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

labmask isocodes, values(cnames)
drop cnames
order isocodes

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
drop if missing(sysbank)
rename sysbank startyear
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
* Labelling, saving, and cleaning temporary files.                             *
********************************************************************************

u `aggregate', clear

label variable fsysbank      "Number of Systemic Banking Crises"
label variable startyear     "Crisis' Starting Year"
label variable endyear       "Crisis' Ending Year (missing if ongoing)"
label variable yloss         "Output Loss (% of GDP)"
label variable fcost_v1      "Fiscal Cost (% of GDP)"
label variable fcost_v2      "Fiscal Cost (% of GDP), net"
label variable fcost_v3      "Fiscal Cost (% of Financial Sector Assets)"
label variable maxnpl        "Peak NPLs (% of Total Loans)"
label variable gsdebt        "Increase in Public Debt (% of GDP)"
label variable hascurr       "1 = Simultaneous Currency Crisis"
label variable hassovdebt    "1 = Simultaneous Sovereign Debt Crisis"
label variable hassovdebtres "1 = Simultaneous Sovereign Debt Restructuring"

sort isocodes startyear
order isocodes fsysbank startyear endyear has*
label data "Laeven and Valencia (2018) Systemic Banking Crises Database"
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
