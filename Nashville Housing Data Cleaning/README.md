## Based on my analysis of the Nashville housing dataset, here are the key data-cleaning issues that need to be addressed:

1. Duplicate Parcel IDs: There are 7,245 duplicate Parcel IDs, suggesting multiple sales of the same property.

2. Formatting issues in Property Addresses: Almost all addresses have multiple spaces that need standardization.
4. Missing Values: Several columns have significant missing data, especially in property details.
5. Inconsistent Sale Prices: There are some very low prices (< $1,000) and very high prices (> $10,000,000) that may need investigation.
6. Year Built Range: Properties date from 1799 to 2017, requiring validation of very old properties.
7. Inconsistencies in categorical data: Land Use has multiple similar categories that could be standardized.
