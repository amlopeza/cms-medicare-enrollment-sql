-- Day 1: Query Foundations
-- CMS Medicare Monthly Enrollment
-- All source columns are stored as TEXT in the raw layer.

-- Question 1:
-- Show ten Massachusetts county-level annual records for 2024,
-- ordered alphabetically by county name.
SELECT
    bene_state_abrvtn,
    bene_county_desc,
    bene_fips_cd,
    year,
    month,
    tot_benes
FROM raw.medicare_monthly_enrollment
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND month = 'Year'
  AND year = '2024'
ORDER BY bene_county_desc
LIMIT 10;


-- Question 2:
-- Show 12 Massachusetts county-level records from January or February 2024.
SELECT
    bene_county_desc,
    bene_fips_cd,
    year,
    month,
    tot_benes
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA'
  AND (
      month = 'January'
      OR month = 'February'
  )
  AND year = '2024'
ORDER BY
    bene_county_desc,
    month
LIMIT 12;


-- Question 3:
-- Count Massachusetts county-level records across January, February,
-- and March 2024.
SELECT
    COUNT(*) AS record_count
FROM raw.medicare_monthly_enrollment
WHERE month IN ('January', 'February', 'March')
  AND bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA'
  AND year = '2024';


-- Question 4:
-- Count Massachusetts county-level records separately for January,
-- February, and March 2024.
SELECT
    month,
    COUNT(*) AS record_count
FROM raw.medicare_monthly_enrollment
WHERE month IN ('January', 'February', 'March')
  AND bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA'
  AND year = '2024'
GROUP BY month
ORDER BY month;


-- Question 5:
-- For Massachusetts county-level records in January 2024, compare
-- the raw row count with the number of distinct county FIPS values.
SELECT
    COUNT(*) AS record_count,
    COUNT(DISTINCT bene_fips_cd) AS distinct_fips_count
FROM raw.medicare_monthly_enrollment
WHERE month = 'January'
  AND year = '2024'
  AND bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA';


-- Question 6:
-- List each distinct county-description/FIPS combination represented
-- in Massachusetts county-level records for January 2024.
SELECT DISTINCT
    bene_county_desc,
    bene_fips_cd
FROM raw.medicare_monthly_enrollment
WHERE month = 'January'
  AND year = '2024'
  AND bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA'
ORDER BY bene_fips_cd;


-- Question 7:
-- Count distinct named county FIPS values after excluding the CMS
-- Unknown category (FIPS 25999).
SELECT
    COUNT(DISTINCT bene_fips_cd) AS named_county_fips_count
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA'
  AND month = 'January'
  AND year = '2024'
  AND bene_fips_cd <> '25999';


-- Question 8:
-- Classify each Massachusetts county-level January 2024 record as
-- either the CMS Unknown category or a named county.
SELECT
    bene_county_desc,
    bene_fips_cd,
    CASE
        WHEN bene_fips_cd = '25999' THEN 'Unknown'
        ELSE 'Named county'
    END AS county_status
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA'
  AND month = 'January'
  AND year = '2024'
ORDER BY bene_fips_cd;


-- Question 9:
-- Show Barnstable County's total beneficiary values for January,
-- February, and March 2024 in chronological order.
SELECT
    month,
    tot_benes
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'County'
  AND bene_state_abrvtn = 'MA'
  AND bene_fips_cd = '25001'
  AND year = '2024'
  AND month IN ('January', 'February', 'March')
ORDER BY
    CASE
        WHEN month = 'January' THEN 1
        WHEN month = 'February' THEN 2
        WHEN month = 'March' THEN 3
    END;


-- Question 10:
-- Identify state abbreviations with more than 100 county-level records
-- for January 2024.
SELECT
    bene_state_abrvtn,
    COUNT(*) AS record_count
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'County'
  AND month = 'January'
  AND year = '2024'
GROUP BY bene_state_abrvtn
HAVING COUNT(*) > 100
ORDER BY
    record_count DESC,
    bene_state_abrvtn ASC;


-- Question 11:
-- For all Massachusetts county-level annual records in 2024, return
-- the raw row count and the sum of available total-beneficiary values.
SELECT
    COUNT(*) AS record_count,
    SUM(
        CASE
            WHEN tot_benes = '*' THEN NULL
            ELSE CAST(tot_benes AS BIGINT)
        END
    ) AS available_tot_benes_sum
FROM raw.medicare_monthly_enrollment
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND month = 'Year'
  AND year = '2024';


-- Question 12 — Final Day 1 challenge:
-- For January, February, and March 2024, summarize Massachusetts
-- county-level record coverage, distinct FIPS coverage, suppression,
-- and the sum of available total-beneficiary values by month.
SELECT
    month,
    COUNT(*) AS record_count,
    COUNT(DISTINCT bene_fips_cd) AS distinct_fips_count,
    SUM(
        CASE
            WHEN tot_benes = '*' THEN 1
            ELSE 0
        END
    ) AS suppressed_tot_benes_count,
    SUM(
        CASE
            WHEN tot_benes = '*' THEN NULL
            ELSE CAST(tot_benes AS BIGINT)
        END
    ) AS available_tot_benes_sum
FROM raw.medicare_monthly_enrollment
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND year = '2024'
  AND month IN ('January', 'February', 'March')
GROUP BY month
ORDER BY
    CASE
        WHEN month = 'January' THEN 1
        WHEN month = 'February' THEN 2
        WHEN month = 'March' THEN 3
    END;