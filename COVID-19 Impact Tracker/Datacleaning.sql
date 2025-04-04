-- COVID-19 Data Cleaning SQL Scripts

-- 1. Initial data import and schema creation
CREATE TABLE raw_covid_data (
    iso_code VARCHAR(10),
    continent VARCHAR(50),
    location VARCHAR(100),
    date DATE,
    total_cases FLOAT,
    new_cases FLOAT,
    new_cases_smoothed FLOAT,
    total_deaths FLOAT,
    new_deaths FLOAT,
    new_deaths_smoothed FLOAT,
    total_cases_per_million FLOAT,
    new_cases_per_million FLOAT,
    new_cases_smoothed_per_million FLOAT,
    total_deaths_per_million FLOAT,
    new_deaths_per_million FLOAT,
    new_deaths_smoothed_per_million FLOAT,
    reproduction_rate FLOAT,
    icu_patients FLOAT,
    icu_patients_per_million FLOAT,
    hosp_patients FLOAT,
    hosp_patients_per_million FLOAT,
    weekly_icu_admissions FLOAT,
    weekly_icu_admissions_per_million FLOAT,
    weekly_hosp_admissions FLOAT,
    weekly_hosp_admissions_per_million FLOAT,
    total_tests FLOAT,
    new_tests FLOAT,
    total_tests_per_thousand FLOAT,
    new_tests_per_thousand FLOAT,
    new_tests_smoothed FLOAT,
    new_tests_smoothed_per_thousand FLOAT,
    positive_rate FLOAT,
    tests_per_case FLOAT,
    tests_units VARCHAR(100),
    total_vaccinations FLOAT,
    people_vaccinated FLOAT,
    people_fully_vaccinated FLOAT,
    total_boosters FLOAT,
    new_vaccinations FLOAT,
    new_vaccinations_smoothed FLOAT,
    total_vaccinations_per_hundred FLOAT,
    people_vaccinated_per_hundred FLOAT,
    people_fully_vaccinated_per_hundred FLOAT,
    total_boosters_per_hundred FLOAT,
    new_vaccinations_smoothed_per_million FLOAT,
    new_people_vaccinated_smoothed FLOAT,
    new_people_vaccinated_smoothed_per_hundred FLOAT,
    stringency_index FLOAT,
    population FLOAT,
    population_density FLOAT,
    median_age FLOAT,
    aged_65_older FLOAT,
    aged_70_older FLOAT,
    gdp_per_capita FLOAT,
    extreme_poverty FLOAT,
    cardiovasc_death_rate FLOAT,
    diabetes_prevalence FLOAT,
    female_smokers FLOAT,
    male_smokers FLOAT,
    handwashing_facilities FLOAT,
    hospital_beds_per_thousand FLOAT,
    life_expectancy FLOAT,
    human_development_index FLOAT,
    excess_mortality_cumulative_absolute FLOAT,
    excess_mortality_cumulative FLOAT,
    excess_mortality FLOAT,
    excess_mortality_cumulative_per_million FLOAT
);

-- 2. Handling missing values and data consistency issues

-- Create a clean working table
CREATE TABLE clean_covid_data AS
SELECT 
    iso_code,
    continent,
    location,
    date,
    COALESCE(total_cases, 0) AS total_cases,
    COALESCE(new_cases, 0) AS new_cases,
    COALESCE(total_deaths, 0) AS total_deaths,
    COALESCE(new_deaths, 0) AS new_deaths,
    COALESCE(reproduction_rate, 0) AS reproduction_rate,
    COALESCE(icu_patients, 0) AS icu_patients,
    COALESCE(hosp_patients, 0) AS hosp_patients,
    COALESCE(total_tests, 0) AS total_tests,
    COALESCE(new_tests, 0) AS new_tests,
    COALESCE(positive_rate, 0) AS positive_rate,
    COALESCE(total_vaccinations, 0) AS total_vaccinations,
    COALESCE(people_vaccinated, 0) AS people_vaccinated,
    COALESCE(people_fully_vaccinated, 0) AS people_fully_vaccinated,
    COALESCE(total_boosters, 0) AS total_boosters,
    COALESCE(new_vaccinations, 0) AS new_vaccinations,
    COALESCE(stringency_index, 0) AS stringency_index,
    population
FROM raw_covid_data
WHERE location NOT IN ('World', 'International', 'European Union') -- Remove aggregate entries
AND population IS NOT NULL; -- Ensure population data exists for per-capita calculations

-- 3. Fix data anomalies

-- Identify and correct negative new cases (data reporting errors)
UPDATE clean_covid_data
SET new_cases = 0
WHERE new_cases < 0;

-- Correct cases where total is less than previous day (data corrections)
WITH anomalies AS (
    SELECT 
        location,
        date,
        total_cases,
        LAG(total_cases) OVER (PARTITION BY location ORDER BY date) AS prev_total_cases
    FROM clean_covid_data
)
UPDATE clean_covid_data c
SET total_cases = a.prev_total_cases
FROM anomalies a
WHERE c.location = a.location 
AND c.date = a.date
AND a.total_cases < a.prev_total_cases;

-- Recalculate new cases based on corrected totals
WITH recalculated AS (
    SELECT 
        location,
        date,
        total_cases,
        total_cases - LAG(total_cases, 1, 0) OVER (PARTITION BY location ORDER BY date) AS calculated_new_cases
    FROM clean_covid_data
)
UPDATE clean_covid_data c
SET new_cases = CASE WHEN r.calculated_new_cases < 0 THEN 0 ELSE r.calculated_new_cases END
FROM recalculated r
WHERE c.location = r.location
AND c.date = r.date;

-- Similar corrections for death data
UPDATE clean_covid_data
SET new_deaths = 0
WHERE new_deaths < 0;

-- 4. Create derived metrics for analysis

-- Calculate per-million metrics consistently
ALTER TABLE clean_covid_data
ADD cases_per_million FLOAT,
ADD deaths_per_million FLOAT,
ADD tests_per_million FLOAT,
ADD vaccination_rate FLOAT,
ADD case_fatality_rate FLOAT;

-- Update derived metrics
UPDATE clean_covid_data
SET 
    cases_per_million = (total_cases * 1000000.0) / NULLIF(population, 0),
    deaths_per_million = (total_deaths * 1000000.0) / NULLIF(population, 0),
    tests_per_million = (total_tests * 1000000.0) / NULLIF(population, 0),
    vaccination_rate = (people_fully_vaccinated * 100.0) / NULLIF(population, 0),
    case_fatality_rate = (total_deaths * 100.0) / NULLIF(total_cases, 0)
WHERE population > 0;

-- 5. Create timeframe categorization for wave analysis
ALTER TABLE clean_covid_data
ADD wave VARCHAR(20);

-- Define pandemic waves based on global patterns
UPDATE clean_covid_data
SET wave = 
    CASE
        WHEN date BETWEEN '2020-01-01' AND '2020-06-30' THEN 'First Wave'
        WHEN date BETWEEN '2020-07-01' AND '2020-12-31' THEN 'Second Wave'
        WHEN date BETWEEN '2021-01-01' AND '2021-06-30' THEN 'Third Wave' 
        WHEN date BETWEEN '2021-07-01' AND '2022-02-28' THEN 'Fourth Wave'
        WHEN date BETWEEN '2022-03-01' AND '2022-12-31' THEN 'Fifth Wave'
        WHEN date >= '2023-01-01' THEN 'Sixth Wave'
    END;

-- 6. Create vaccination status groups for analysis
ALTER TABLE clean_covid_data
ADD vaccination_group VARCHAR(30);

UPDATE clean_covid_data
SET vaccination_group = 
    CASE
        WHEN vaccination_rate < 10 THEN 'Very Low (<10%)'
        WHEN vaccination_rate BETWEEN 10 AND 39.99 THEN 'Low (10-40%)'
        WHEN vaccination_rate BETWEEN 40 AND 69.99 THEN 'Medium (40-70%)'
        WHEN vaccination_rate >= 70 THEN 'High (>70%)'
        ELSE 'Unknown'
    END;

-- 7. Create continent aggregation views for regional analysis
CREATE VIEW continent_summary AS
SELECT
    continent,
    date,
    SUM(new_cases) AS new_cases,
    SUM(total_cases) AS total_cases, 
    SUM(new_deaths) AS new_deaths,
    SUM(total_deaths) AS total_deaths,
    SUM(new_vaccinations) AS new_vaccinations,
    SUM(people_fully_vaccinated) AS people_fully_vaccinated,
    SUM(population) AS population,
    (SUM(people_fully_vaccinated) * 100.0) / NULLIF(SUM(population), 0) AS vaccination_rate,
    (SUM(total_deaths) * 100.0) / NULLIF(SUM(total_cases), 0) AS case_fatality_rate,
    wave
FROM clean_covid_data
WHERE continent IS NOT NULL
GROUP BY continent, date, wave;

-- 8. Create weekly aggregation view to smooth daily reporting fluctuations
CREATE VIEW weekly_trends AS
SELECT
    location,
    DATE_TRUNC('week', date) AS week_start,
    AVG(new_cases) AS avg_daily_cases,
    AVG(new_deaths) AS avg_daily_deaths,
    SUM(new_cases) AS weekly_cases,
    SUM(new_deaths) AS weekly_deaths,
    MAX(vaccination_rate) AS vaccination_rate,
    wave
FROM clean_covid_data
GROUP BY location, DATE_TRUNC('week', date), wave;

-- 9. Create index for performance optimization
CREATE INDEX idx_location_date ON clean_covid_data (location, date);
CREATE INDEX idx_date ON clean_covid_data (date);
CREATE INDEX idx_continent ON clean_covid_data (continent);
CREATE INDEX idx_wave ON clean_covid_data (wave);

-- 10. Create Pre/Post vaccination analysis view
CREATE VIEW vaccination_impact AS
WITH pre_vaccination AS (
    SELECT
        location,
        AVG(case_fatality_rate) AS pre_vax_cfr,
        SUM(new_deaths) AS pre_vax_deaths,
        SUM(new_cases) AS pre_vax_cases
    FROM clean_covid_data
    WHERE date < '2021-01-01' -- Before widespread vaccination
    GROUP BY location
),
post_vaccination AS (
    SELECT
        location,
        MAX(vaccination_rate) AS max_vax_rate,
        AVG(CASE WHEN vaccination_rate > 40 THEN case_fatality_rate ELSE NULL END) AS post_vax_cfr,
        SUM(CASE WHEN vaccination_rate > 40 THEN new_deaths ELSE 0 END) AS post_vax_deaths,
        SUM(CASE WHEN vaccination_rate > 40 THEN new_cases ELSE 0 END) AS post_vax_cases
    FROM clean_covid_data
    WHERE date >= '2021-06-01' -- After vaccines became widely available
    GROUP BY location
)
SELECT
    pre.location,
    pre.pre_vax_cfr,
    post.post_vax_cfr,
    pre.pre_vax_deaths,
    pre.pre_vax_cases,
    post.post_vax_deaths,
    post.post_vax_cases,
    post.max_vax_rate,
    ((pre.pre_vax_cfr - post.post_vax_cfr) / NULLIF(pre.pre_vax_cfr, 0)) * 100 AS cfr_reduction_percent
FROM pre_vaccination pre
JOIN post_vaccination post ON pre.location = post.location
WHERE pre.pre_vax_cases > 1000 -- Minimum cases for statistical relevance
AND post.post_vax_cases > 1000;

-- 11. Final data quality check - verify no remaining inconsistencies
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT location) AS total_locations,
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date,
    SUM(CASE WHEN new_cases < 0 THEN 1 ELSE 0 END) AS negative_cases_count,
    SUM(CASE WHEN new_deaths < 0 THEN 1 ELSE 0 END) AS negative_deaths_count,
    SUM(CASE WHEN total_cases < 0 THEN 1 ELSE 0 END) AS negative_total_cases,
    SUM(CASE WHEN case_fatality_rate > 100 THEN 1 ELSE 0 END) AS invalid_cfr_count
FROM clean_covid_data;
