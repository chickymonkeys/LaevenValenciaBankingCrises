# Systemic Banking Crises Database

This project provides a standalone script in Stata to download the original [Laeven and Valencia (2020)](https://link.springer.com/article/10.1057/s41308-020-00107-3) Systemic Banking Crises Database from the [IMF Working Paper](https://www.imf.org/en/Publications/WP/Issues/2018/09/14/Systemic-Banking-Crises-Revisited-46232) Page. It computes the provided [Excel Spreadsheet](https://www.imf.org/~/media/Files/Publications/WP/2018/datasets/wp18206.ashx) such that it creates a _spell_ dataset (in .dta format) with an entry for each country experiencing a systemic banking crisis, the outcome of the crisis and flags for whether there are multiple crises other than the mentioned one (currency, sovereign debt, and sovereign debt restructuring).

To uniquely identify countries, it consider the ISO-1366-1 Numeric code format, in a way that it allows to link the dataset to other sources. In Stata, this is straightforward through the user-written command `kountry` in [Raciborski (2008)](https://journals.sagepub.com/doi/10.1177/1536867X0800800305).

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See installing and running for notes on how to run the script.

In the final dataset, it is possible to find the following variables:

- _isocodes_: the the country name encoded with ISO 3166-1 Numeric;
- _fsysbank_: the number of systemic banking crisis in spell format (increasing number);
- _startyear_: the starting year of the crisis;
- _endyear_: the ending year of the crisis (missing if still ongoing);
- _yloss_: the output loss due to the crisis measured in percentage of (potential) GDP;
- _fcost_: the fiscal cost of the crisis, as
    + percentage of GDP;
    + net fiscal cost in percentage of GDP;
    + percentage of financial sector assets;
- _maxnpl_: the peak of Non-Performing Loans as percentage of total financial sector assets;
- _gsdebt_: increase of public debt, as percentage of GDP;
- multiple crises flags:
    + _hascurr_ equal to one in the presence of a currency crisis;
    + _hassovdebt_ equal to one in the presence of a sovereign debt crisis;
    + _hassovdebtres_ equal to one in the presence of sovereign debt restructuring.

For additional information about the outcome of the crises and how they were measured by the original authors, see the [working paper](https://www.imf.org/en/Publications/WP/Issues/2018/09/14/Systemic-Banking-Crises-Revisited-46232) and the [published article](https://link.springer.com/article/10.1057/s41308-020-00107-3). Crises other than systemic banking and outcomes related to liquidity have been omitted.

### Prerequisites

The script needs an internet connection to check whether the command `kountry` is installed and to download the dataset from the IMF website. For development purposes, just download the project directory in your computer, or feel free to fork the project.

### Installing and Running

It is possible to just download the [BankingCrisisDB.do](./src/BankingCrisisDB.do) script in the folder [src](src) of the project, copy it in a folder and run it within Stata.

The script creates three different folders:

- **res**: it contains the output dataset after running the script;
- **log**: it contains the _ex-post_ `.log` file with the outcome of the script;
- **temp**: a temporary directory where the `.zip` file of the dataset is downloaded, extracted, and deleted after the script has finished.

## Authors

- **Alessandro Pizzigolotto** - _just the script_ - [Norwegian School of Economics (NHH)](https://github.com/chickymonkeys)

See the list of the original authors in the references.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## References

* Laeven, L., Valencia, F., 2018. Systemic Banking Crises Revisited (Working Paper No. 18/206), IMF Working Papers. International Monetary Fund, Washington, DC. [Link](https://www.imf.org/en/Publications/WP/Issues/2018/09/14/Systemic-Banking-Crises-Revisited-46232).
* Laeven, L., Valencia, F. Systemic Banking Crises Database II. _IMF Economic Review_ (2020). [Link](https://doi.org/10.1057/s41308-020-00107-3).
* Raciborski, R. (2008). kountry: A Stata Utility for Merging Cross-country Data from Multiple Sources. _The Stata Journal_, 8(3), 390–400. [Link](https://doi.org/10.1177/1536867X0800800305).
