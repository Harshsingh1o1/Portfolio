Nashville Housing Data Cleaning: Summary Report

Project Overview

This report summarizes the data cleaning process for the Nashville housing dataset (2013-2016) containing information on property sales, attributes, and valuations.

Data Assessment
The dataset consists of 56,636 records with 31 columns. A thorough analysis revealed several data quality issues requiring cleaning.
Key Issues Identified

1. Structural Issues

Redundant index columns: Two unnamed index columns ("" and "Unnamed: 0") provide no value.
Duplicate records: 7,939 duplicate Parcel IDs identified, representing multiple sales of the same property.
High null counts: Many columns have significant missing data (e.g., 32,490 null values in "Half Bath").

2. Data Format Inconsistencies

Extra whitespace: 55,892 property addresses contain double spaces between words.
Grade values: Inconsistent formatting with trailing spaces (e.g., "C   ", "B   ").
Land Use typos: Values with typos such as "GREENBELT/RES\r\nGRRENBELT/RES" and "VACANT RESIENTIAL LAND".

3. Data Validity Issues

Future build years: 13 properties show construction years past 2016 (dataset end year).
Suspiciously low prices: 7 properties with sale prices under $1,000.
Outlier concerns: 1 property with more than 10 bedrooms, 1 property larger than 100 acres.
Inconsistent city names: 14 unique city values, including "UNKNOWN".

4. Field Standardization Needs

Text fields: Need standardization (capitalization, trimming).
Categorical fields: "Sold As Vacant" and "Multiple Parcels Involved in Sale" should be boolean.
Property metrics: Numeric fields need appropriate type casting.

Cleaning Approach

1. Data Standardization

Removed extra whitespace from text fields using REGEXP_REPLACE.
Standardized case for city and state fields.
Corrected typos in "Land Use" field.
Trimmed trailing spaces from categorical fields.

2. Data Type Conversion

Converted "Sale Date" to proper date format.
Added "Sale Year" and "Sale Month" columns for time-based analysis.
Cast numeric fields to appropriate types (INTEGER, DECIMAL).
Converted Yes/No fields to TRUE/FALSE boolean values.

3. Data Validation

Flagged and nullified suspicious values:

Sale prices below $100
Build years before 1700 or after 2016
Properties with more than 10 bedrooms


Added data quality flags for missing addresses, low prices, and invalid years.

4. Structural Improvements

Created indexes on frequently queried fields.
Removed duplicate records (keeping most recent sale per parcel).
Created calculated fields like "Total Bathrooms".
Created analytical views for common business queries.

Considerations for Future Work

Geocoding: Add latitude/longitude coordinates based on addresses.
Neighborhood analysis: Add census tract or neighborhood demographic data.
Market segmentation: Create property tier classifications based on value and features.
Time-based metrics: Calculate year-over-year appreciation rates for properties with multiple sales.
Data completeness: Evaluate whether missing data could be sourced from public records.

Impact of Data Cleaning

Improved data integrity: Corrected 2+ known typos and standardized 14 city values.
Enhanced analytics capability: Created 5 specialized views for common analyses.
Optimized performance: Added 5 indexes on frequently queried columns.
Better decision support: Added flags to identify 3+ categories of potentially problematic records.

This cleaned dataset now provides a more reliable foundation for housing market analysis and property valuation studies in the Nashville area.
