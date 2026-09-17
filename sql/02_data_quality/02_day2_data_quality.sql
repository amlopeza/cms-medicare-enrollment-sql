-- Day 2: Data Quality and Source Structure
-- Project: CMS Medicare Monthly Enrollment
-- PostgreSQL
--
-- This script contains the polished Day 2 queries and the cleaned core view.
-- It preserves the raw layer and applies normalization only in query results
-- or in the clean.medicare_monthly_enrollment_core view.


-- Question 1: Which distinct state descriptions contain the substring
-- "island", regardless of letter case?

SELECT DISTINCT
    bene_state_desc
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'State'
  AND bene_state_desc ILIKE '%island%'
ORDER BY bene_state_desc;


-- Question 2: Which distinct state abbreviations contain exactly two
-- characters and end with the letter A?

SELECT DISTINCT
    bene_state_abrvtn
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'State'
  AND bene_state_abrvtn LIKE '_A'
ORDER BY bene_state_abrvtn;


-- Pattern behavior check: _ matches exactly one character.

SELECT
    'USA' LIKE '__A' AS three_char_match,
    'USA' LIKE '_A' AS two_char_match;


-- Question 3: How many Massachusetts county-level annual records are
-- present in each year from 2022 through 2024, inclusive?

SELECT
    year,
    COUNT(*) AS record_count
FROM raw.medicare_monthly_enrollment
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND month = 'Year'
  AND year BETWEEN '2022' AND '2024'
GROUP BY year
ORDER BY year;


-- Question 4A: How many raw records have a SQL NULL in bene_fips_cd?

SELECT
    COUNT(*) AS null_fips_count
FROM raw.medicare_monthly_enrollment
WHERE bene_fips_cd IS NULL;


-- Question 4B: How many raw records have a non-NULL bene_fips_cd value?

SELECT
    COUNT(*) AS non_null_fips_count
FROM raw.medicare_monthly_enrollment
WHERE bene_fips_cd IS NOT NULL;


-- Question 5: Among non-NULL FIPS values, how many blank or
-- whitespace-only values occur at each geographic level?

SELECT
    bene_geo_lvl,
    COUNT(*) AS blank_fips_count
FROM raw.medicare_monthly_enrollment
WHERE bene_fips_cd IS NOT NULL
  AND BTRIM(bene_fips_cd) = ''
GROUP BY bene_geo_lvl
ORDER BY bene_geo_lvl;


-- Question 6: How many raw records have no usable FIPS after converting
-- empty and whitespace-only values to SQL NULL?

SELECT
    COUNT(*) AS normalized_null_fips_count
FROM raw.medicare_monthly_enrollment
WHERE NULLIF(BTRIM(bene_fips_cd), '') IS NULL;


-- Question 7: For national annual records from 2022 through 2024,
-- show the raw FIPS and a readable normalized display value.

SELECT
    year,
    bene_fips_cd AS raw_fips,
    COALESCE(
        NULLIF(BTRIM(bene_fips_cd), ''),
        'No usable FIPS'
    ) AS fips_display
FROM raw.medicare_monthly_enrollment
WHERE bene_geo_lvl = 'National'
  AND month = 'Year'
  AND year BETWEEN '2022' AND '2024'
ORDER BY year;


-- Question 8: For each geographic level, profile total rows, raw SQL-NULL
-- FIPS values, blank/whitespace-only FIPS values, and usable normalized FIPS.

SELECT
    bene_geo_lvl,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE bene_fips_cd IS NULL
    ) AS raw_null_fips_count,
    COUNT(*) FILTER (
        WHERE bene_fips_cd IS NOT NULL
          AND BTRIM(bene_fips_cd) = ''
    ) AS blank_fips_count,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(bene_fips_cd), '') IS NOT NULL
    ) AS usable_fips_count
FROM raw.medicare_monthly_enrollment
GROUP BY bene_geo_lvl
ORDER BY bene_geo_lvl;


-- Question 9: Are any candidate source-grain combinations represented by
-- more than one raw record?
-- Candidate grain: year x month x geography level x state abbreviation
-- x normalized FIPS.

SELECT
    year,
    month,
    bene_geo_lvl,
    bene_state_abrvtn,
    NULLIF(BTRIM(bene_fips_cd), '') AS normalized_fips,
    COUNT(*) AS rows_at_grain
FROM raw.medicare_monthly_enrollment
GROUP BY
    year,
    month,
    bene_geo_lvl,
    bene_state_abrvtn,
    NULLIF(BTRIM(bene_fips_cd), '')
HAVING COUNT(*) > 1
ORDER BY
    rows_at_grain DESC,
    year,
    month,
    bene_geo_lvl;


-- Question 10: Preview the cleaned representation for Massachusetts
-- county-level annual records in 2024.

SELECT
    CAST(year AS INTEGER) AS year,
    month,
    bene_geo_lvl,
    bene_state_abrvtn,
    bene_county_desc,
    bene_fips_cd AS bene_fips_cd_raw,
    NULLIF(BTRIM(bene_fips_cd), '') AS bene_fips_cd,
    tot_benes AS tot_benes_raw,
    CASE
        WHEN tot_benes = '*' THEN NULL
        ELSE CAST(tot_benes AS BIGINT)
    END AS tot_benes,
    (tot_benes = '*') AS tot_benes_suppressed
FROM raw.medicare_monthly_enrollment
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND month = 'Year'
  AND year = '2024'
ORDER BY NULLIF(BTRIM(bene_fips_cd), '');


-- Question 11: Create a cleaned and typed core view without filtering out
-- any raw source rows.

CREATE SCHEMA IF NOT EXISTS clean;

CREATE OR REPLACE VIEW clean.medicare_monthly_enrollment_core AS
SELECT
    CAST(year AS INTEGER) AS year,
    month,
    bene_geo_lvl,
    bene_state_abrvtn,
    bene_state_desc,
    bene_county_desc,
    bene_fips_cd AS bene_fips_cd_raw,
    NULLIF(BTRIM(bene_fips_cd), '') AS bene_fips_cd,
    tot_benes AS tot_benes_raw,
    CASE
        WHEN tot_benes = '*' THEN NULL
        ELSE CAST(tot_benes AS BIGINT)
    END AS tot_benes,
    (tot_benes = '*') AS tot_benes_suppressed
FROM raw.medicare_monthly_enrollment;


-- Question 12: Inspect the cleaned view's column names and data types using
-- PostgreSQL metadata.

SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'medicare_monthly_enrollment_core'
ORDER BY ordinal_position;


-- Question 13: Does the cleaned view preserve complete raw row coverage?

SELECT
    (SELECT COUNT(*)
     FROM raw.medicare_monthly_enrollment) AS raw_row_count,
    (SELECT COUNT(*)
     FROM clean.medicare_monthly_enrollment_core) AS clean_view_row_count;


-- Question 14: Are the raw suppression token, Boolean flag, and cleaned
-- numeric NULL representation consistent?

SELECT
    COUNT(*) FILTER (
        WHERE tot_benes_raw = '*'
    ) AS raw_suppressed_count,
    COUNT(*) FILTER (
        WHERE tot_benes_suppressed
    ) AS suppressed_flag_count,
    COUNT(*) FILTER (
        WHERE tot_benes IS NULL
    ) AS null_numeric_tot_benes_count,
    COUNT(*) FILTER (
        WHERE tot_benes_suppressed
          AND tot_benes IS NOT NULL
    ) AS suppressed_with_numeric_count,
    COUNT(*) FILTER (
        WHERE NOT tot_benes_suppressed
          AND tot_benes IS NULL
    ) AS unsuppressed_null_numeric_count
FROM clean.medicare_monthly_enrollment_core;


-- Question 15: Did the cleaned transformations preserve candidate-grain
-- uniqueness?

SELECT
    year,
    month,
    bene_geo_lvl,
    bene_state_abrvtn,
    bene_fips_cd,
    COUNT(*) AS rows_at_grain
FROM clean.medicare_monthly_enrollment_core
GROUP BY
    year,
    month,
    bene_geo_lvl,
    bene_state_abrvtn,
    bene_fips_cd
HAVING COUNT(*) > 1
ORDER BY
    rows_at_grain DESC,
    year,
    month,
    bene_geo_lvl;


-- Final Challenge, Part A: For annual records from 2022 through 2024,
-- summarize row coverage, FIPS quality, suppression, and available
-- beneficiary totals by geographic level.

SELECT
    bene_geo_lvl,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE bene_fips_cd_raw IS NULL
    ) AS raw_null_fips_count,
    COUNT(*) FILTER (
        WHERE bene_fips_cd_raw IS NOT NULL
          AND BTRIM(bene_fips_cd_raw) = ''
    ) AS blank_fips_count,
    COUNT(*) FILTER (
        WHERE bene_fips_cd IS NOT NULL
    ) AS usable_fips_count,
    COUNT(*) FILTER (
        WHERE tot_benes_suppressed
    ) AS suppressed_tot_benes_count,
    COUNT(*) FILTER (
        WHERE tot_benes IS NOT NULL
    ) AS available_tot_benes_count,
    SUM(tot_benes) AS available_tot_benes_sum
FROM clean.medicare_monthly_enrollment_core
WHERE month = 'Year'
  AND year BETWEEN 2022 AND 2024
GROUP BY bene_geo_lvl
ORDER BY bene_geo_lvl;


-- Final Challenge, Part B: For annual state-level records from 2022 through
-- 2024 whose state description contains "island", show raw and cleaned
-- FIPS and beneficiary representations side by side.

SELECT
    year,
    bene_state_desc,
    bene_fips_cd_raw,
    COALESCE(bene_fips_cd, 'No usable FIPS') AS fips_display,
    tot_benes_raw,
    tot_benes,
    tot_benes_suppressed
FROM clean.medicare_monthly_enrollment_core
WHERE bene_geo_lvl = 'State'
  AND month = 'Year'
  AND year BETWEEN 2022 AND 2024
  AND bene_state_desc ILIKE '%island%'
ORDER BY
    bene_state_desc,
    year;
