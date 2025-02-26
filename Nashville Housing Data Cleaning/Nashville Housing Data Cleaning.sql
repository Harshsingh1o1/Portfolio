-- Nashville Housing Data Cleaning Project

-- First, creating a table to import the CSV data
CREATE TABLE IF NOT EXISTS NashvilleHousing (
    ID INT,
    UnnamedCol INT,
    ParcelID VARCHAR(50),
    LandUse VARCHAR(100),
    PropertyAddress VARCHAR(200),
    SuiteOrCondo VARCHAR(50),
    PropertyCity VARCHAR(100),
    SaleDate DATE,
    SalePrice DECIMAL(15,2),
    LegalReference VARCHAR(50),
    SoldAsVacant VARCHAR(5),
    MultipleParcelsSale VARCHAR(5),
    OwnerName VARCHAR(200),
    OwnerAddress VARCHAR(200),
    OwnerCity VARCHAR(100),
    OwnerState VARCHAR(50),
    Acreage DECIMAL(10,2),
    TaxDistrict VARCHAR(100),
    Neighborhood DECIMAL(10,0),
    ImagePath VARCHAR(200),
    LandValue DECIMAL(15,2),
    BuildingValue DECIMAL(15,2),
    TotalValue DECIMAL(15,2),
    FinishedArea DECIMAL(15,2),
    FoundationType VARCHAR(50),
    YearBuilt INT,
    ExteriorWall VARCHAR(50),
    Grade VARCHAR(50),
    Bedrooms INT,
    FullBath INT,
    HalfBath INT
);

-- After importing the CSV, let's start cleaning the data
-------------------------------------------------------------------------------------------------
-- 1. STANDARDIZE PROPERTY ADDRESSES: Remove multiple spaces
-- Create a view for standardized property addresses
CREATE VIEW StandardizedPropertyAddress AS
SELECT
    ID,
    ParcelID,
    TRIM(REGEXP_REPLACE(PropertyAddress, '\s+', ' ')) AS PropertyAddress,
    PropertyCity
FROM NashvilleHousing;

-- 2. POPULATE MISSING PROPERTY ADDRESSES
-- For properties with missing addresses, use the address from other entries with the same ParcelID
CREATE VIEW PopulatedPropertyAddress AS
SELECT 
    a.ParcelID,
    a.PropertyAddress,
    b.PropertyAddress AS ReferencePropertyAddress,
    COALESCE(a.PropertyAddress, b.PropertyAddress) AS UpdatedPropertyAddress
FROM NashvilleHousing a
JOIN NashvilleHousing b
    ON a.ParcelID = b.ParcelID
    AND a.ID <> b.ID
WHERE a.PropertyAddress IS NULL;

-- Update the missing property addresses
UPDATE NashvilleHousing
SET PropertyAddress = b.PropertyAddress
FROM NashvilleHousing a
JOIN NashvilleHousing b
    ON a.ParcelID = b.ParcelID
    AND a.ID <> b.ID
WHERE a.PropertyAddress IS NULL AND b.PropertyAddress IS NOT NULL;

-- 3. BREAKING OUT PROPERTY ADDRESS INTO INDIVIDUAL COLUMNS (Address, City, State)
-- Create a view with separated property address components
CREATE VIEW SeparatedPropertyAddress AS
SELECT
    ParcelID,
    PropertyAddress,
    SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS Address,
    SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)) AS City
FROM NashvilleHousing
WHERE PropertyAddress IS NOT NULL;

-- 4. STANDARDIZE SALE DATE FORMAT
-- Ensure all SaleDate values are in a consistent format
CREATE VIEW StandardizedSaleDate AS
SELECT
    ParcelID,
    SaleDate,
    CONVERT(Date, SaleDate) AS ConvertedSaleDate
FROM NashvilleHousing;

-- 5. STANDARDIZE "SOLD AS VACANT" FIELD (Change Y and N to Yes and No)
SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant)
FROM NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2;

UPDATE NashvilleHousing
SET SoldAsVacant = CASE 
                      WHEN SoldAsVacant = 'Y' THEN 'Yes'
                      WHEN SoldAsVacant = 'N' THEN 'No'
                      ELSE SoldAsVacant
                   END;

-- 6. REMOVE DUPLICATES
-- Create a CTE to identify duplicate records
WITH RowNumCTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY ParcelID,
                         PropertyAddress,
                         SalePrice,
                         SaleDate,
                         LegalReference
            ORDER BY ID
        ) row_num
    FROM NashvilleHousing
)
-- Delete duplicate records
DELETE FROM NashvilleHousing
WHERE ID IN (
    SELECT ID
    FROM RowNumCTE
    WHERE row_num > 1
);

-- 7. STANDARDIZE LAND USE CATEGORIES
-- Create a standardized land use field
CREATE VIEW StandardizedLandUse AS
SELECT
    ParcelID,
    LandUse,
    CASE 
        WHEN LandUse = 'VACANT RES LAND' THEN 'VACANT RESIDENTIAL LAND'
        WHEN LandUse = 'CONDO' THEN 'RESIDENTIAL CONDO'
        ELSE LandUse 
    END AS StandardizedLandUse
FROM NashvilleHousing;

-- 8. HANDLE ANOMALOUS SALE PRICES
-- Identify extremely low or high sale prices for review
CREATE VIEW AnomalousSalePrices AS
SELECT
    ParcelID,
    PropertyAddress,
    SalePrice,
    LandValue,
    BuildingValue,
    TotalValue,
    CASE 
        WHEN SalePrice < 1000 THEN 'Very Low'
        WHEN SalePrice > 10000000 THEN 'Very High'
        ELSE 'Normal' 
    END AS PriceCategory
FROM NashvilleHousing
WHERE SalePrice < 1000 OR SalePrice > 10000000;

-- 9. CREATE LOGIC TO FLAG INCOMPLETE RECORDS
-- Flag records with missing important information
CREATE VIEW IncompleteRecords AS
SELECT
    ID,
    ParcelID,
    CASE 
        WHEN PropertyAddress IS NULL THEN 1 ELSE 0 
    END AS MissingAddress,
    CASE 
        WHEN YearBuilt IS NULL THEN 1 ELSE 0 
    END AS MissingYearBuilt,
    CASE 
        WHEN Bedrooms IS NULL THEN 1 ELSE 0 
    END AS MissingBedrooms,
    CASE 
        WHEN FullBath IS NULL THEN 1 ELSE 0 
    END AS MissingFullBath,
    CASE 
        WHEN TotalValue IS NULL THEN 1 ELSE 0 
    END AS MissingTotalValue
FROM NashvilleHousing;

-- 10. IDENTIFY UNUSUAL YEAR BUILT VALUES
CREATE VIEW UnusualYearBuilt AS
SELECT
    ParcelID,
    PropertyAddress,
    YearBuilt,
    CASE 
        WHEN YearBuilt < 1800 THEN 'Very Old'
        WHEN YearBuilt > 2016 THEN 'Future Date'
        ELSE 'Normal' 
    END AS YearBuiltCategory
FROM NashvilleHousing
WHERE YearBuilt < 1800 OR YearBuilt > 2016;

-- 11. CALCULATE PROPERTY AGE AT SALE TIME
ALTER TABLE NashvilleHousing
ADD PropertyAge INT;

UPDATE NashvilleHousing
SET PropertyAge = YEAR(SaleDate) - YearBuilt
WHERE YearBuilt IS NOT NULL;

-- 12. CREATE A PRICE PER SQUARE FOOT FIELD
ALTER TABLE NashvilleHousing
ADD PricePerSqFt DECIMAL(10,2);

UPDATE NashvilleHousing
SET PricePerSqFt = SalePrice / FinishedArea
WHERE FinishedArea > 0;

-- 13. STANDARDIZE OWNER NAMES (Remove inconsistent formatting)
CREATE VIEW StandardizedOwnerNames AS
SELECT
    ParcelID,
    OwnerName,
    TRIM(REGEXP_REPLACE(OwnerName, '\s+', ' ')) AS StandardizedOwnerName
FROM NashvilleHousing
WHERE OwnerName IS NOT NULL;

-- 14. STANDARDIZE STATE ABBREVIATIONS
CREATE VIEW StandardizedStates AS
SELECT
    ParcelID,
    OwnerState,
    CASE 
        WHEN OwnerState = 'Tennessee' THEN 'TN'
        WHEN OwnerState = 'TENNESSEE' THEN 'TN'
        ELSE OwnerState 
    END AS StandardizedState
FROM NashvilleHousing
WHERE OwnerState IS NOT NULL;

-- 15. CREATE PROPERTY TYPE CATEGORIES
ALTER TABLE NashvilleHousing
ADD PropertyType VARCHAR(50);

UPDATE NashvilleHousing
SET PropertyType = 
    CASE 
        WHEN LandUse LIKE '%VACANT%' THEN 'Vacant Land'
        WHEN LandUse LIKE '%CONDO%' THEN 'Condominium'
        WHEN LandUse LIKE '%SINGLE FAMILY%' THEN 'Single Family'
        WHEN LandUse LIKE '%DUPLEX%' THEN 'Multi-Family'
        WHEN LandUse LIKE '%TRIPLEX%' THEN 'Multi-Family'
        WHEN LandUse LIKE '%QUADPLEX%' THEN 'Multi-Family'
        WHEN LandUse LIKE '%ZERO LOT%' THEN 'Zero Lot Line'
        ELSE 'Other'
    END;

-- 16. CREATE SALES QUARTER AND YEAR FIELDS FOR TREND ANALYSIS
ALTER TABLE NashvilleHousing
ADD SaleYear INT,
    SaleQuarter INT,
    SaleYearQuarter VARCHAR(10);

UPDATE NashvilleHousing
SET SaleYear = YEAR(SaleDate),
    SaleQuarter = DATEPART(QUARTER, SaleDate),
    SaleYearQuarter = CONCAT(YEAR(SaleDate), 'Q', DATEPART(QUARTER, SaleDate));

-- 17. CREATE FINAL CLEANED VIEW
CREATE VIEW NashvilleHousingCleaned AS
SELECT
    ParcelID,
    TRIM(REGEXP_REPLACE(PropertyAddress, '\s+', ' ')) AS PropertyAddress,
    PropertyCity,
    CONVERT(Date, SaleDate) AS SaleDate,
    SalePrice,
    CASE 
        WHEN LandUse LIKE '%VACANT%' THEN 'Vacant Land'
        WHEN LandUse LIKE '%CONDO%' THEN 'Condominium'
        WHEN LandUse LIKE '%SINGLE FAMILY%' THEN 'Single Family'
        WHEN LandUse LIKE '%DUPLEX%' THEN 'Multi-Family'
        WHEN LandUse LIKE '%TRIPLEX%' THEN 'Multi-Family'
        WHEN LandUse LIKE '%QUADPLEX%' THEN 'Multi-Family'
        WHEN LandUse LIKE '%ZERO LOT%' THEN 'Zero Lot Line'
        ELSE 'Other'
    END AS PropertyType,
    LegalReference,
    SoldAsVacant,
    COALESCE(Acreage, 0) AS Acreage,
    COALESCE(LandValue, 0) AS LandValue,
    COALESCE(BuildingValue, 0) AS BuildingValue,
    COALESCE(TotalValue, 0) AS TotalValue,
    COALESCE(FinishedArea, 0) AS FinishedArea,
    FoundationType,
    YearBuilt,
    ExteriorWall,
    COALESCE(Bedrooms, 0) AS Bedrooms,
    COALESCE(FullBath, 0) AS FullBath,
    COALESCE(HalfBath, 0) AS HalfBath,
    YEAR(SaleDate) - YearBuilt AS PropertyAge,
    CASE 
        WHEN FinishedArea > 0 THEN SalePrice / FinishedArea 
        ELSE NULL 
    END AS PricePerSqFt,
    YEAR(SaleDate) AS SaleYear,
    DATEPART(QUARTER, SaleDate) AS SaleQuarter,
    CONCAT(YEAR(SaleDate), 'Q', DATEPART(QUARTER, SaleDate)) AS SaleYearQuarter
FROM NashvilleHousing
WHERE ParcelID IS NOT NULL;
