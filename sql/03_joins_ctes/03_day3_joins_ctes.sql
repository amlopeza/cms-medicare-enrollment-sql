-- Day 3: Joins, Count Effects, and CTEs
-- CMS Medicare Monthly Enrollment
--
-- This script documents the polished Day 3 work. It derives a reusable
-- Massachusetts county dimension, validates join readiness and key uniqueness,
-- compares INNER and LEFT JOIN behavior, diagnoses row multiplication, tests a
-- composite join key, and performs referential-integrity QA with CTEs.


-- Question 1: Profile the planned annual left side before joining.
-- Expected grain: one Massachusetts county-level annual record per FIPS per year.
SELECT
    COUNT(*) AS left_row_count,
    COUNT(DISTINCT bene_fips_cd) AS distinct_fips_count,
    COUNT(DISTINCT year) AS year_count,
    COUNT(*) FILTER (
        WHERE bene_fips_cd = '25999'
    ) AS unknown_row_count
FROM clean.medicare_monthly_enrollment_core
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND month = 'Year'
  AND year BETWEEN 2022 AND 2024;


-- Question 2A: Does each named Massachusetts county FIPS map consistently
-- to one county description and one state description across source history?
SELECT
    bene_fips_cd,
    COUNT(DISTINCT bene_county_desc) AS county_desc_count,
    COUNT(DISTINCT bene_state_desc) AS state_desc_count,
    COUNT(*) AS source_row_count
FROM clean.medicare_monthly_enrollment_core
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND bene_fips_cd IS NOT NULL
  AND bene_fips_cd <> '25999'
GROUP BY bene_fips_cd
HAVING COUNT(DISTINCT bene_county_desc) <> 1
    OR COUNT(DISTINCT bene_state_desc) <> 1
ORDER BY bene_fips_cd;


-- Question 2B: Is the candidate lookup source complete?
SELECT
    COUNT(*) AS candidate_source_rows,
    COUNT(DISTINCT bene_fips_cd) AS distinct_fips_count,
    COUNT(*) FILTER (
        WHERE bene_county_desc IS NULL
           OR BTRIM(bene_county_desc) = ''
    ) AS missing_county_desc_count,
    COUNT(*) FILTER (
        WHERE bene_state_desc IS NULL
           OR BTRIM(bene_state_desc) = ''
    ) AS missing_state_desc_count
FROM clean.medicare_monthly_enrollment_core
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND bene_fips_cd IS NOT NULL
  AND bene_fips_cd <> '25999';


-- Question 2C: Create a reusable named-county dimension.
-- Intended grain: one row per named Massachusetts county FIPS.
CREATE OR REPLACE VIEW clean.dim_ma_county AS
SELECT DISTINCT
    bene_fips_cd,
    bene_state_abrvtn,
    bene_state_desc,
    bene_county_desc
FROM clean.medicare_monthly_enrollment_core
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND bene_fips_cd IS NOT NULL
  AND bene_fips_cd <> '25999';


-- Question 2D: Validate dimension row count, key uniqueness, and completeness.
SELECT
    COUNT(*) AS dimension_row_count,
    COUNT(DISTINCT bene_fips_cd) AS distinct_fips_count,
    COUNT(*) FILTER (
        WHERE bene_fips_cd IS NULL
           OR BTRIM(bene_fips_cd) = ''
    ) AS missing_fips_count,
    COUNT(*) FILTER (
        WHERE bene_county_desc IS NULL
           OR BTRIM(bene_county_desc) = ''
    ) AS missing_county_desc_count,
    COUNT(*) FILTER (
        WHERE bene_state_desc IS NULL
           OR BTRIM(bene_state_desc) = ''
    ) AS missing_state_desc_count
FROM clean.dim_ma_county;


-- Question 2E: Does any dimension FIPS key occur more than once?
SELECT
    bene_fips_cd,
    COUNT(*) AS lookup_rows_per_key
FROM clean.dim_ma_county
GROUP BY bene_fips_cd
HAVING COUNT(*) > 1
ORDER BY bene_fips_cd;


-- Question 3: Reconcile an INNER JOIN to the named-county dimension.
-- Expected effect: 45 annual left rows decrease to 42 matched named-county rows.
SELECT
    COUNT(*) AS joined_row_count,
    COUNT(DISTINCT f.bene_fips_cd) AS matched_fips_count,
    COUNT(DISTINCT f.year) AS year_count,
    COUNT(*) FILTER (
        WHERE f.bene_fips_cd = '25999'
    ) AS unknown_rows_after_join
FROM clean.medicare_monthly_enrollment_core AS f
INNER JOIN clean.dim_ma_county AS d
    ON f.bene_fips_cd = d.bene_fips_cd
WHERE f.bene_state_abrvtn = 'MA'
  AND f.bene_geo_lvl = 'County'
  AND f.month = 'Year'
  AND f.year BETWEEN 2022 AND 2024;


-- Question 4: Reconcile a LEFT JOIN and classify matched and unmatched rows.
SELECT
    COUNT(*) AS left_join_row_count,
    COUNT(*) FILTER (
        WHERE d.bene_fips_cd IS NOT NULL
    ) AS matched_row_count,
    COUNT(*) FILTER (
        WHERE d.bene_fips_cd IS NULL
    ) AS unmatched_row_count,
    COUNT(DISTINCT f.bene_fips_cd) AS distinct_left_fips_count,
    COUNT(DISTINCT d.bene_fips_cd) AS distinct_matched_fips_count,
    COUNT(*) FILTER (
        WHERE f.bene_fips_cd = '25999'
          AND d.bene_fips_cd IS NULL
    ) AS unknown_unmatched_count
FROM clean.medicare_monthly_enrollment_core AS f
LEFT JOIN clean.dim_ma_county AS d
    ON f.bene_fips_cd = d.bene_fips_cd
WHERE f.bene_state_abrvtn = 'MA'
  AND f.bene_geo_lvl = 'County'
  AND f.month = 'Year'
  AND f.year BETWEEN 2022 AND 2024;


-- Question 5A: Profile the monthly right side before a self-join.
SELECT
    COUNT(*) AS right_row_count,
    COUNT(DISTINCT bene_fips_cd) AS distinct_fips_count,
    COUNT(DISTINCT month) AS month_count
FROM clean.medicare_monthly_enrollment_core
WHERE bene_state_abrvtn = 'MA'
  AND bene_geo_lvl = 'County'
  AND year = 2024
  AND month IN ('January', 'February', 'March')
  AND bene_fips_cd IS NOT NULL
  AND bene_fips_cd <> '25999';


-- Question 5B: Diagnose many-to-many row multiplication when joining only on FIPS.
-- Annual rows repeat by year; monthly rows repeat by month.
SELECT
    COUNT(*) AS joined_row_count,
    COUNT(*) FILTER (
        WHERE a.year = m.year
    ) AS same_year_match_count,
    COUNT(*) FILTER (
        WHERE a.year <> m.year
    ) AS cross_year_match_count,
    COUNT(DISTINCT a.bene_fips_cd) AS matched_fips_count
FROM clean.medicare_monthly_enrollment_core AS a
INNER JOIN clean.medicare_monthly_enrollment_core AS m
    ON a.bene_fips_cd = m.bene_fips_cd
WHERE a.bene_state_abrvtn = 'MA'
  AND a.bene_geo_lvl = 'County'
  AND a.month = 'Year'
  AND a.year BETWEEN 2022 AND 2024
  AND a.bene_fips_cd IS NOT NULL
  AND a.bene_fips_cd <> '25999'
  AND m.bene_state_abrvtn = 'MA'
  AND m.bene_geo_lvl = 'County'
  AND m.year = 2024
  AND m.month IN ('January', 'February', 'March')
  AND m.bene_fips_cd IS NOT NULL
  AND m.bene_fips_cd <> '25999';


-- Question 6: Add year to form a composite join key and eliminate
-- analytically invalid cross-year matches.
SELECT
    COUNT(*) AS joined_row_count,
    COUNT(DISTINCT a.bene_fips_cd) AS matched_fips_count,
    COUNT(DISTINCT a.year) AS matched_annual_year_count,
    COUNT(DISTINCT m.month) AS matched_month_count,
    COUNT(*) FILTER (
        WHERE a.year <> m.year
    ) AS cross_year_match_count
FROM clean.medicare_monthly_enrollment_core AS a
INNER JOIN clean.medicare_monthly_enrollment_core AS m
    ON a.bene_fips_cd = m.bene_fips_cd
   AND a.year = m.year
WHERE a.bene_state_abrvtn = 'MA'
  AND a.bene_geo_lvl = 'County'
  AND a.month = 'Year'
  AND a.year BETWEEN 2022 AND 2024
  AND a.bene_fips_cd IS NOT NULL
  AND a.bene_fips_cd <> '25999'
  AND m.bene_state_abrvtn = 'MA'
  AND m.bene_geo_lvl = 'County'
  AND m.year = 2024
  AND m.month IN ('January', 'February', 'March')
  AND m.bene_fips_cd IS NOT NULL
  AND m.bene_fips_cd <> '25999';


-- Question 7: Use CTEs to organize a LEFT JOIN and classify expected and
-- unexpected unmatched records.
WITH annual_records AS (
    SELECT
        year,
        bene_fips_cd,
        bene_county_desc,
        tot_benes
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND month = 'Year'
      AND year BETWEEN 2022 AND 2024
),
joined_records AS (
    SELECT
        a.year,
        a.bene_fips_cd AS left_fips,
        a.bene_county_desc AS left_county_desc,
        a.tot_benes,
        d.bene_fips_cd AS lookup_fips,
        d.bene_county_desc AS lookup_county_desc
    FROM annual_records AS a
    LEFT JOIN clean.dim_ma_county AS d
        ON a.bene_fips_cd = d.bene_fips_cd
)
SELECT
    COUNT(*) AS joined_row_count,
    COUNT(*) FILTER (
        WHERE lookup_fips IS NOT NULL
    ) AS matched_row_count,
    COUNT(*) FILTER (
        WHERE lookup_fips IS NULL
    ) AS unmatched_row_count,
    COUNT(DISTINCT left_fips) FILTER (
        WHERE lookup_fips IS NULL
    ) AS distinct_unmatched_fips_count,
    COUNT(*) FILTER (
        WHERE lookup_fips IS NULL
          AND left_fips <> '25999'
    ) AS unexpected_unmatched_row_count
FROM joined_records;


-- Final Challenge: Reconcile pre-join coverage, dimension-key quality,
-- post-join coverage, expected orphans, and available-beneficiary sums.
WITH annual_records AS (
    SELECT
        year,
        bene_fips_cd,
        bene_county_desc,
        tot_benes
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND month = 'Year'
      AND year BETWEEN 2022 AND 2024
),
dimension_key_counts AS (
    SELECT
        bene_fips_cd,
        COUNT(*) AS rows_per_key
    FROM clean.dim_ma_county
    GROUP BY bene_fips_cd
),
joined_records AS (
    SELECT
        a.year,
        a.bene_fips_cd AS left_fips,
        a.bene_county_desc AS left_county_desc,
        a.tot_benes,
        d.bene_fips_cd AS lookup_fips,
        d.bene_county_desc AS lookup_county_desc
    FROM annual_records AS a
    LEFT JOIN clean.dim_ma_county AS d
        ON a.bene_fips_cd = d.bene_fips_cd
)
SELECT
    (SELECT COUNT(*) FROM annual_records) AS left_row_count,
    (SELECT COUNT(*) FROM clean.dim_ma_county) AS dimension_row_count,
    (
        SELECT COUNT(DISTINCT bene_fips_cd)
        FROM clean.dim_ma_county
    ) AS dimension_distinct_fips_count,
    (
        SELECT COUNT(*) FILTER (WHERE rows_per_key > 1)
        FROM dimension_key_counts
    ) AS duplicate_dimension_key_count,
    COUNT(*) AS joined_row_count,
    COUNT(*) - (SELECT COUNT(*) FROM annual_records) AS row_count_difference,
    COUNT(*) FILTER (
        WHERE lookup_fips IS NOT NULL
    ) AS matched_row_count,
    COUNT(*) FILTER (
        WHERE lookup_fips IS NULL
    ) AS unmatched_row_count,
    COUNT(DISTINCT left_fips) FILTER (
        WHERE lookup_fips IS NULL
    ) AS distinct_unmatched_fips_count,
    COUNT(*) FILTER (
        WHERE lookup_fips IS NULL
          AND left_fips = '25999'
    ) AS expected_unknown_unmatched_count,
    COUNT(*) FILTER (
        WHERE lookup_fips IS NULL
          AND left_fips <> '25999'
    ) AS unexpected_unmatched_row_count,
    (SELECT SUM(tot_benes) FROM annual_records) AS left_available_tot_benes_sum,
    SUM(tot_benes) AS joined_available_tot_benes_sum,
    SUM(tot_benes)
        - (SELECT SUM(tot_benes) FROM annual_records)
        AS available_tot_benes_sum_difference
FROM joined_records;
