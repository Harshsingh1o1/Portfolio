/*
Nashville Housing Data Cleaning in SQL
*/

-- Create a table for our Nashville Housing data
CREATE TABLE NashvilleHousing (
    UniqueID INT,
    ParcelID VARCHAR(50),
    LandUse VARCHAR(50),
    PropertyAddress VARCHAR(100),
    SaleDate DATETIME,
    SalePrice DECIMAL(18, 2),
    LegalReference VARCHAR(50),
    SoldAsVacant VARCHAR(10),
    OwnerName VARCHAR(100),
    OwnerAddress VARCHAR(100),
    Acreage DECIMAL(18, 2),
    TaxDistrict VARCHAR(50),
    LandValue DECIMAL(18, 2),
    BuildingValue DECIMAL(18, 2),
    TotalValue DECIMAL(18, 2),
    YearBuilt INT,
    Bedrooms INT,
    FullBath INT,
    HalfBath INT
);

-- After importing data into the table, perform the following cleaning operations:

----------------------------------------------------------------------------------------------
-- 1. Standardize Date Format (convert from datetime to date)
-- Remove timestamp from SaleDate
ALTER TABLE NashvilleHousing
ADD SaleDateConverted DATE;

UPDATE NashvilleHousing
SET SaleDateConverted = CONVERT(DATE, SaleDate);

----------------------------------------------------------------------------------------------
-- 2. Populate NULL Property Addresses
-- For the same ParcelID, if one record has a PropertyAddress and another doesn't,
-- use the existing address to fill in the NULL values
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM NashvilleHousing a
JOIN NashvilleHousing b
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL;

----------------------------------------------------------------------------------------------
-- 3. Breaking out PropertyAddress into Individual Columns (Address, City)
ALTER TABLE NashvilleHousing
ADD PropertySplitAddress NVARCHAR(255),
    PropertySplitCity NVARCHAR(255);

UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1),
    PropertySplitCity = LTRIM(SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)));

----------------------------------------------------------------------------------------------
-- 4. Breaking out OwnerAddress into Individual Columns (Address, City, State)
ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress NVARCHAR(255),
    OwnerSplitCity NVARCHAR(255),
    OwnerSplitState NVARCHAR(255);

UPDATE NashvilleHousing
SET OwnerSplitAddress = 
        CASE 
            WHEN OwnerAddress IS NULL THEN NULL
            ELSE PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)
        END,
    OwnerSplitCity = 
        CASE 
            WHEN OwnerAddress IS NULL THEN NULL
            ELSE PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)
        END,
    OwnerSplitState = 
        CASE 
            WHEN OwnerAddress IS NULL THEN NULL
            ELSE PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
        END;

----------------------------------------------------------------------------------------------
-- 5. Change Y and N to Yes and No in "SoldAsVacant" field
UPDATE NashvilleHousing
SET SoldAsVacant = 
    CASE 
        WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
        ELSE SoldAsVacant
    END;

----------------------------------------------------------------------------------------------
-- 6. Remove Duplicates
-- First, identify duplicates based on key fields
WITH RowNumCTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY ParcelID,
                        PropertyAddress,
                        SalePrice,
                        SaleDate,
                        LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM NashvilleHousing
)
-- Then delete the duplicates (row_num > 1)
DELETE FROM RowNumCTE
WHERE row_num > 1;

----------------------------------------------------------------------------------------------
-- 7. Standardize ParcelID format (if needed based on inconsistencies)
-- Note: This step might need customization based on specific requirements
-- This example normalizes spacing in ParcelID

UPDATE NashvilleHousing
SET ParcelID = REPLACE(REPLACE(REPLACE(ParcelID, '  ', ' '), '  ', ' '), '  ', ' ');

----------------------------------------------------------------------------------------------
-- 8. Handle outlier SalePrice values (Optional)
-- Flag extremely low prices (possibly errors)
ALTER TABLE NashvilleHousing
ADD PriceFlag VARCHAR(20);

UPDATE NashvilleHousing
SET PriceFlag = 
    CASE 
        WHEN SalePrice < 100 THEN 'Very Low - Verify'
        WHEN SalePrice > 2000000 THEN 'Very High - Verify'
        ELSE 'Normal Range'
    END;

----------------------------------------------------------------------------------------------
-- 9. Check and correct improbable YearBuilt values
UPDATE NashvilleHousing
SET YearBuilt = NULL
WHERE YearBuilt > YEAR(GETDATE()) OR YearBuilt < 1700;

----------------------------------------------------------------------------------------------
-- 10. Remove unused columns (Optional)
-- After confirming that the new columns work as expected
ALTER TABLE NashvilleHousing
DROP COLUMN SaleDate,  -- Using SaleDateConverted instead
             PropertyAddress,  -- Using PropertySplitAddress and PropertySplitCity instead
             OwnerAddress;  -- Using OwnerSplitAddress, OwnerSplitCity, and OwnerSplitState instead

----------------------------------------------------------------------------------------------
-- 11. Create a clean view for analysis (Optional)
CREATE VIEW vw_CleanNashvilleHousing AS
SELECT 
    UniqueID,
    ParcelID,
    LandUse,
    PropertySplitAddress AS Address,
    PropertySplitCity AS City,
    SaleDateConverted AS SaleDate,
    SalePrice,
    LegalReference,
    SoldAsVacant,
    OwnerName,
    OwnerSplitAddress AS OwnerAddress,
    OwnerSplitCity AS OwnerCity,
    OwnerSplitState AS OwnerState,
    Acreage,
    TaxDistrict,
    LandValue,
    BuildingValue,
    TotalValue,
    YearBuilt,
    Bedrooms,
    FullBath,
    HalfBath,
    PriceFlag
FROM NashvilleHousing
WHERE (PriceFlag = 'Normal Range' OR PriceFlag IS NULL);  -- Optionally filter out flagged prices
