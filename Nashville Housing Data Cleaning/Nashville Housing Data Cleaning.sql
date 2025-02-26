-- Nashville Housing Data Cleaning Script
-- This script cleans the Nashville housing data from 2013-2016

-- 1. Create a clean version of the table
DROP TABLE IF EXISTS nashville_housing_cleaned;
CREATE TABLE nashville_housing_cleaned AS 
SELECT 
    "Parcel ID",
    
    -- Standardize property address by removing extra spaces
    TRIM(REGEXP_REPLACE("Property Address", '\s+', ' ')) AS "Property Address",
    
    -- Convert suite/condo to text and handle NULLs
    CAST("Suite/ Condo   #" AS TEXT) AS "Suite/Condo #",
    
    -- Standardize property city and handle inconsistencies
    CASE 
        WHEN "Property City" = 'UNKNOWN' THEN NULL 
        ELSE UPPER(TRIM("Property City")) 
    END AS "Property City",
    
    -- Standardize sale date format
    TO_DATE("Sale Date", 'YYYY-MM-DD') AS "Sale Date",
    EXTRACT(YEAR FROM TO_DATE("Sale Date", 'YYYY-MM-DD')) AS "Sale Year",
    EXTRACT(MONTH FROM TO_DATE("Sale Date", 'YYYY-MM-DD')) AS "Sale Month",
    
    -- Clean up sale price and filter out suspiciously low values
    CASE 
        WHEN CAST("Sale Price" AS INTEGER) < 100 THEN NULL
        ELSE CAST("Sale Price" AS INTEGER)
    END AS "Sale Price",
    "Legal Reference",
    
    -- Convert 'Sold As Vacant' to boolean
    CASE 
        WHEN "Sold As Vacant" = 'Yes' THEN TRUE
        WHEN "Sold As Vacant" = 'No' THEN FALSE
        ELSE NULL
    END AS "Sold As Vacant",
    
    -- Convert multiple parcels to boolean
    CASE 
        WHEN "Multiple Parcels Involved in Sale" = 'Yes' THEN TRUE
        WHEN "Multiple Parcels Involved in Sale" = 'No' THEN FALSE
        ELSE NULL
    END AS "Multiple Parcels",
    "Owner Name",
    
    -- Clean owner address
    TRIM(REGEXP_REPLACE("Address", '\s+', ' ')) AS "Owner Address",
    
    -- Standardize city and state
    UPPER(TRIM("City")) AS "Owner City",
    UPPER(TRIM("State")) AS "Owner State",
    
    -- Fix land use with typos
    CASE 
        WHEN "Land Use" = 'GREENBELT/RES
GRRENBELT/RES' THEN 'GREENBELT/RESIDENTIAL'
        WHEN "Land Use" = 'VACANT RESIENTIAL LAND' THEN 'VACANT RESIDENTIAL LAND'
        ELSE "Land Use"
    END AS "Land Use",
    
    -- Filter out invalid year values
    CASE 
        WHEN CAST("Year Built" AS INTEGER) > 2016 THEN NULL
        WHEN CAST("Year Built" AS INTEGER) < 1700 THEN NULL
        ELSE CAST("Year Built" AS INTEGER)
    END AS "Year Built",
    
    -- Clean up remaining numeric fields
    CAST("Acreage" AS DECIMAL(10,2)) AS "Acreage",
    CAST("Land Value" AS DECIMAL(14,2)) AS "Land Value",
    CAST("Building Value" AS DECIMAL(14,2)) AS "Building Value",
    CAST("Total Value" AS DECIMAL(14,2)) AS "Total Value",
    CAST("Finished Area" AS DECIMAL(10,2)) AS "Finished Area",
    
    -- Clean up foundation type
    TRIM("Foundation Type") AS "Foundation Type",
    
    -- Clean up exterior wall
    TRIM("Exterior Wall") AS "Exterior Wall",
    
    -- Clean up grade (trim spaces)
    TRIM("Grade") AS "Grade",
    
    -- Clean up bedroom and bathroom counts
    CASE 
        WHEN CAST("Bedrooms" AS INTEGER) > 10 THEN NULL -- Flag suspicious values
        ELSE CAST("Bedrooms" AS INTEGER)
    END AS "Bedrooms",
    CAST("Full Bath" AS INTEGER) AS "Full Bath",
    CAST("Half Bath" AS INTEGER) AS "Half Bath",
    
    -- Calculate total bathrooms
    CAST("Full Bath" AS DECIMAL(4,1)) + (CAST("Half Bath" AS DECIMAL(4,1)) / 2) AS "Total Bathrooms",
    
    -- Add data quality flags
    CASE WHEN "Property Address" IS NULL THEN TRUE ELSE FALSE END AS "Missing Address Flag",
    CASE WHEN CAST("Sale Price" AS INTEGER) < 1000 THEN TRUE ELSE FALSE END AS "Low Price Flag",
    CASE 
        WHEN CAST("Year Built" AS INTEGER) > 2016 OR CAST("Year Built" AS INTEGER) < 1700 
        THEN TRUE ELSE FALSE 
    END AS "Invalid Year Flag"
FROM nashville_housing_data;

-- 2. Create indexes for improved query performance
CREATE INDEX idx_parcel_id ON nashville_housing_cleaned ("Parcel ID");
CREATE INDEX idx_sale_date ON nashville_housing_cleaned ("Sale Date");
CREATE INDEX idx_property_city ON nashville_housing_cleaned ("Property City");
CREATE INDEX idx_land_use ON nashville_housing_cleaned ("Land Use");
CREATE INDEX idx_year_built ON nashville_housing_cleaned ("Year Built");

-- 3. Remove duplicate records (keeping the most recent sale for each parcel)
DELETE FROM nashville_housing_cleaned 
WHERE ctid NOT IN (
    SELECT MAX(ctid) 
    FROM nashville_housing_cleaned 
    GROUP BY "Parcel ID"
);

-- 4. Add views for common analyses

-- View for residential properties
CREATE OR REPLACE VIEW residential_properties AS
SELECT *
FROM nashville_housing_cleaned
WHERE "Land Use" IN ('SINGLE FAMILY', 'RESIDENTIAL CONDO', 'DUPLEX', 'CONDO', 'ZERO LOT LINE', 
                     'RESIDENTIAL COMBO/MISC', 'TRIPLEX', 'QUADPLEX', 'MOBILE HOME');

-- View for vacant land
CREATE OR REPLACE VIEW vacant_land AS
SELECT *
FROM nashville_housing_cleaned
WHERE "Land Use" LIKE 'VACANT%';

-- View for commercial properties
CREATE OR REPLACE VIEW commercial_properties AS
SELECT *
FROM nashville_housing_cleaned
WHERE "Land Use" IN ('STRIP SHOPPING CENTER', 'CONDOMINIUM OFC  OR OTHER COM CONDO', 
                     'OFFICE BLDG (ONE OR TWO STORIES)', 'RESTURANT/CAFETERIA', 
                     'CONVENIENCE MARKET WITHOUT GAS', 'CLUB/UNION HALL/LODGE',
                     'LIGHT MANUFACTURING', 'ONE STORY GENERAL RETAIL STORE', 
                     'DAY CARE CENTER', 'TERMINAL/DISTRIBUTION WAREHOUSE',
                     'NIGHTCLUB/LOUNGE');

-- View for property value analysis
CREATE OR REPLACE VIEW property_value_analysis AS
SELECT 
    "Land Use",
    "Property City",
    AVG("Sale Price") AS "Average Sale Price",
    AVG("Land Value") AS "Average Land Value",
    AVG("Building Value") AS "Average Building Value",
    AVG("Total Value") AS "Average Total Value",
    AVG("Acreage") AS "Average Acreage",
    COUNT(*) AS "Property Count"
FROM nashville_housing_cleaned
GROUP BY "Land Use", "Property City";

-- View for average prices over time
CREATE OR REPLACE VIEW price_trends AS
SELECT 
    "Sale Year",
    "Sale Month",
    AVG("Sale Price") AS "Average Sale Price",
    COUNT(*) AS "Sales Count"
FROM nashville_housing_cleaned
GROUP BY "Sale Year", "Sale Month"
ORDER BY "Sale Year", "Sale Month";
