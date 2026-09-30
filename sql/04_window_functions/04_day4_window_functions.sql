-- Day 4: Date Logic, Window Functions, and Ranking
-- CMS Medicare Monthly Enrollment
--
-- This script documents the polished Day 4 work. It derives a typed monthly
-- date, validates the monthly grain, compares GROUP BY with window functions,
-- calculates prior-period values, month-over-month changes, rolling averages,
-- and monthly ranks, and finishes with separate analytical and QA outputs.


-- Question 1A: Build and validate the 2024 named-county monthly base.
WITH monthly_base AS (
    SELECT
        year,
        month,
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        tot_benes_suppressed,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
)
SELECT
    COUNT(*) AS base_row_count,
    COUNT(DISTINCT bene_fips_cd) AS county_count,
    COUNT(DISTINCT month_start) AS month_count,
    MIN(month_start) AS first_month_start,
    MAX(month_start) AS last_month_start,
    COUNT(*) FILTER (
        WHERE month_start IS NULL
    ) AS null_month_start_count,
    COUNT(*) FILTER (
        WHERE tot_benes_suppressed
    ) AS suppressed_row_count
FROM monthly_base;


-- Question 1B: Does every named county have exactly 12 distinct monthly dates
-- covering January through December 2024?
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
)
SELECT
    bene_fips_cd,
    bene_county_desc,
    COUNT(*) AS monthly_row_count,
    COUNT(DISTINCT month_start) AS distinct_month_count,
    MIN(month_start) AS first_month_start,
    MAX(month_start) AS last_month_start
FROM monthly_base
GROUP BY
    bene_fips_cd,
    bene_county_desc
HAVING COUNT(*) <> 12
    OR COUNT(DISTINCT month_start) <> 12
    OR MIN(month_start) <> DATE '2024-01-01'
    OR MAX(month_start) <> DATE '2024-12-01'
ORDER BY bene_fips_cd;


-- Question 2: Preserve Berkshire County's 12 detail rows while adding a
-- county-level month count and chronological sequence.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
)
SELECT
    bene_fips_cd,
    bene_county_desc,
    month_start,
    tot_benes,
    COUNT(*) OVER (
        PARTITION BY bene_fips_cd
    ) AS county_month_count,
    ROW_NUMBER() OVER (
        PARTITION BY bene_fips_cd
        ORDER BY month_start
    ) AS month_sequence
FROM monthly_base
WHERE bene_fips_cd = '25003'
ORDER BY month_start;


-- Question 3A: Return Berkshire County's prior monthly enrollment with LAG.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
lagged_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes
    FROM monthly_base
)
SELECT
    bene_fips_cd,
    bene_county_desc,
    month_start,
    tot_benes,
    previous_tot_benes
FROM lagged_months
WHERE bene_fips_cd = '25003'
ORDER BY month_start;


-- Question 3B: Validate LAG coverage and partition boundaries across all
-- 14 named counties.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
lagged_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        LAG(bene_fips_cd) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_fips,
        LAG(month_start) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_month_start,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes
    FROM monthly_base
)
SELECT
    COUNT(*) AS output_row_count,
    COUNT(DISTINCT bene_fips_cd) AS county_partition_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NULL
    ) AS first_period_row_count,
    COUNT(*) FILTER (
        WHERE previous_fips IS NOT NULL
          AND previous_fips <> bene_fips_cd
    ) AS cross_county_lag_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NULL
          AND month_start <> DATE '2024-01-01'
    ) AS unexpected_first_period_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NOT NULL
          AND previous_tot_benes IS NULL
    ) AS unavailable_previous_value_count
FROM lagged_months;


-- Question 4A: Calculate Berkshire County month-over-month changes.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
lagged_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes
    FROM monthly_base
)
SELECT
    bene_fips_cd,
    bene_county_desc,
    month_start,
    tot_benes,
    previous_tot_benes,
    tot_benes - previous_tot_benes AS absolute_change,
    ROUND(
        100.0
            * (tot_benes - previous_tot_benes)
            / NULLIF(previous_tot_benes, 0),
        4
    ) AS percent_change
FROM lagged_months
WHERE bene_fips_cd = '25003'
ORDER BY month_start;


-- Question 4B: Reconcile available, positive, zero, and negative changes
-- across all named county-month records.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
lagged_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        LAG(month_start) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_month_start,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes
    FROM monthly_base
),
monthly_changes AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        previous_month_start,
        previous_tot_benes,
        tot_benes - previous_tot_benes AS absolute_change,
        ROUND(
            100.0
                * (tot_benes - previous_tot_benes)
                / NULLIF(previous_tot_benes, 0),
            4
        ) AS percent_change
    FROM lagged_months
)
SELECT
    COUNT(*) AS output_row_count,
    COUNT(DISTINCT bene_fips_cd) AS county_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NULL
    ) AS first_period_row_count,
    COUNT(*) FILTER (
        WHERE absolute_change IS NULL
    ) AS absolute_change_null_count,
    COUNT(*) FILTER (
        WHERE percent_change IS NULL
    ) AS percent_change_null_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NOT NULL
          AND previous_tot_benes = 0
    ) AS zero_previous_value_count,
    COUNT(*) FILTER (
        WHERE absolute_change > 0
    ) AS positive_change_count,
    COUNT(*) FILTER (
        WHERE absolute_change = 0
    ) AS zero_change_count,
    COUNT(*) FILTER (
        WHERE absolute_change < 0
    ) AS negative_change_count
FROM monthly_changes;


-- Question 5A: Calculate Berkshire County's three-month rolling average and
-- expose the physical and available-value frame sizes.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
rolling_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        COUNT(*) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_window_row_count,
        COUNT(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_available_value_count,
        ROUND(
            AVG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3m_avg
    FROM monthly_base
)
SELECT
    bene_fips_cd,
    bene_county_desc,
    month_start,
    tot_benes,
    rolling_window_row_count,
    rolling_available_value_count,
    rolling_3m_avg
FROM rolling_months
WHERE bene_fips_cd = '25003'
ORDER BY month_start;


-- Question 5B: Validate rolling-window frame sizes and numeric availability
-- across all 168 county-month records.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
rolling_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        COUNT(*) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_window_row_count,
        COUNT(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_available_value_count,
        ROUND(
            AVG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3m_avg
    FROM monthly_base
)
SELECT
    COUNT(*) AS output_row_count,
    COUNT(DISTINCT bene_fips_cd) AS county_count,
    COUNT(*) FILTER (
        WHERE rolling_window_row_count = 1
    ) AS one_row_window_count,
    COUNT(*) FILTER (
        WHERE rolling_window_row_count = 2
    ) AS two_row_window_count,
    COUNT(*) FILTER (
        WHERE rolling_window_row_count = 3
    ) AS three_row_window_count,
    COUNT(*) FILTER (
        WHERE rolling_available_value_count
              <> rolling_window_row_count
    ) AS availability_gap_count,
    COUNT(*) FILTER (
        WHERE rolling_3m_avg IS NULL
    ) AS null_rolling_avg_count,
    MAX(rolling_window_row_count) AS max_window_row_count
FROM rolling_months;


-- Question 6A: Rank all named counties within December 2024.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
ranked_counties AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        ROW_NUMBER() OVER (
            PARTITION BY month_start
            ORDER BY
                tot_benes DESC NULLS LAST,
                bene_fips_cd
        ) AS county_row_number,
        RANK() OVER (
            PARTITION BY month_start
            ORDER BY tot_benes DESC NULLS LAST
        ) AS county_rank,
        DENSE_RANK() OVER (
            PARTITION BY month_start
            ORDER BY tot_benes DESC NULLS LAST
        ) AS county_dense_rank
    FROM monthly_base
)
SELECT
    bene_fips_cd,
    bene_county_desc,
    month_start,
    tot_benes,
    county_row_number,
    county_rank,
    county_dense_rank
FROM ranked_counties
WHERE month_start = DATE '2024-12-01'
ORDER BY
    tot_benes DESC NULLS LAST,
    bene_fips_cd;


-- Question 6B: Validate ranking coverage and tie behavior across all months.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
ranked_counties AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        COUNT(*) OVER (
            PARTITION BY month_start
        ) AS counties_in_month,
        COUNT(*) OVER (
            PARTITION BY month_start, tot_benes
        ) AS tie_group_size,
        ROW_NUMBER() OVER (
            PARTITION BY month_start
            ORDER BY
                tot_benes DESC NULLS LAST,
                bene_fips_cd
        ) AS county_row_number,
        RANK() OVER (
            PARTITION BY month_start
            ORDER BY tot_benes DESC NULLS LAST
        ) AS county_rank,
        DENSE_RANK() OVER (
            PARTITION BY month_start
            ORDER BY tot_benes DESC NULLS LAST
        ) AS county_dense_rank
    FROM monthly_base
)
SELECT
    COUNT(*) AS output_row_count,
    COUNT(DISTINCT month_start) AS month_partition_count,
    COUNT(DISTINCT bene_fips_cd) AS county_count,
    MIN(counties_in_month) AS min_counties_per_month,
    MAX(counties_in_month) AS max_counties_per_month,
    COUNT(*) FILTER (
        WHERE county_row_number = 1
    ) AS top_row_count,
    MAX(county_row_number) AS max_row_number,
    COUNT(*) FILTER (
        WHERE tot_benes IS NULL
    ) AS null_tot_benes_count,
    COUNT(*) FILTER (
        WHERE tot_benes IS NOT NULL
          AND tie_group_size > 1
    ) AS tied_available_value_row_count,
    COUNT(DISTINCT month_start) FILTER (
        WHERE tot_benes IS NOT NULL
          AND tie_group_size > 1
    ) AS months_with_ties,
    COUNT(*) FILTER (
        WHERE county_rank = 1
    ) AS rank_top_row_count,
    COUNT(*) FILTER (
        WHERE county_dense_rank = 1
    ) AS dense_rank_top_row_count,
    MAX(county_rank) AS max_rank,
    MAX(county_dense_rank) AS max_dense_rank
FROM ranked_counties;


-- Question 7: Unified window-function QA. This query keeps each window
-- calculation in one pipeline and reconciles the 168-row monthly base.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        tot_benes_suppressed,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
windowed_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        tot_benes_suppressed,
        LAG(bene_fips_cd) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_fips,
        LAG(month_start) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_month_start,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes,
        COUNT(*) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_window_row_count,
        COUNT(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_available_value_count,
        ROUND(
            AVG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3m_avg,
        COUNT(*) OVER (
            PARTITION BY month_start, tot_benes
        ) AS tie_group_size,
        ROW_NUMBER() OVER (
            PARTITION BY month_start
            ORDER BY
                tot_benes DESC NULLS LAST,
                bene_fips_cd
        ) AS county_row_number,
        RANK() OVER (
            PARTITION BY month_start
            ORDER BY tot_benes DESC NULLS LAST
        ) AS county_rank,
        DENSE_RANK() OVER (
            PARTITION BY month_start
            ORDER BY tot_benes DESC NULLS LAST
        ) AS county_dense_rank
    FROM monthly_base
)
SELECT
    (SELECT COUNT(*) FROM monthly_base) AS base_row_count,
    COUNT(*) AS output_row_count,
    COUNT(*) - (SELECT COUNT(*) FROM monthly_base)
        AS row_count_difference,
    COUNT(DISTINCT bene_fips_cd) AS county_count,
    COUNT(DISTINCT month_start) AS month_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NULL
    ) AS first_period_row_count,
    COUNT(*) FILTER (
        WHERE previous_fips IS NOT NULL
          AND previous_fips <> bene_fips_cd
    ) AS cross_county_lag_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NOT NULL
          AND previous_tot_benes IS NULL
    ) AS unavailable_previous_value_count,
    COUNT(*) FILTER (
        WHERE rolling_available_value_count
              <> rolling_window_row_count
    ) AS rolling_availability_gap_count,
    COUNT(*) FILTER (
        WHERE rolling_3m_avg IS NULL
    ) AS null_rolling_avg_count,
    COUNT(*) FILTER (
        WHERE county_row_number = 1
    ) AS top_row_count,
    COUNT(*) FILTER (
        WHERE county_rank = 1
    ) AS rank_top_row_count,
    COUNT(*) FILTER (
        WHERE county_dense_rank = 1
    ) AS dense_rank_top_row_count,
    MAX(county_row_number) AS max_row_number,
    MAX(county_rank) AS max_rank,
    MAX(county_dense_rank) AS max_dense_rank,
    COUNT(*) FILTER (
        WHERE tot_benes IS NOT NULL
          AND tie_group_size > 1
    ) AS tied_available_value_row_count,
    COUNT(*) FILTER (
        WHERE tot_benes_suppressed
    ) AS suppressed_row_count
FROM windowed_months;


-- Independent reconstruction: Bristol County April-June output. The complete
-- 12-month history is retained until after LAG and rolling calculations.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
monthly_metrics AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes,
        tot_benes
            - LAG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
            ) AS absolute_change,
        ROUND(
            AVG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3m_avg
    FROM monthly_base
)
SELECT
    month_start,
    tot_benes,
    previous_tot_benes,
    absolute_change,
    rolling_3m_avg
FROM monthly_metrics
WHERE bene_fips_cd = '25005'
  AND month_start BETWEEN DATE '2024-04-01'
                      AND DATE '2024-06-01'
ORDER BY month_start;


-- Final Challenge, Part A: For each Q4 month, return exactly the five named
-- Massachusetts counties with the highest available enrollment, enriched with
-- prior-month change and a three-month rolling average.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        tot_benes_suppressed,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
monthly_metrics AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        tot_benes_suppressed,
        LAG(month_start) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_month_start,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes,
        ROUND(
            AVG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3m_avg,
        COUNT(*) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_window_count,
        COUNT(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_available_value_count
    FROM monthly_base
),
ranked_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        tot_benes_suppressed,
        previous_month_start,
        previous_tot_benes,
        tot_benes - previous_tot_benes AS absolute_change,
        ROUND(
            100.0
                * (tot_benes - previous_tot_benes)
                / NULLIF(previous_tot_benes, 0),
            4
        ) AS percent_change,
        rolling_window_count,
        rolling_available_value_count,
        rolling_3m_avg,
        ROW_NUMBER() OVER (
            PARTITION BY month_start
            ORDER BY
                tot_benes DESC NULLS LAST,
                bene_fips_cd
        ) AS monthly_position
    FROM monthly_metrics
)
SELECT
    month_start,
    monthly_position,
    bene_fips_cd,
    bene_county_desc,
    tot_benes,
    previous_tot_benes,
    absolute_change,
    percent_change,
    rolling_3m_avg
FROM ranked_months
WHERE month_start IN (
          DATE '2024-10-01',
          DATE '2024-11-01',
          DATE '2024-12-01'
      )
  AND monthly_position <= 5
ORDER BY
    month_start,
    monthly_position,
    bene_fips_cd;


-- Final Challenge, QA Query 1: Validate row preservation, first periods,
-- suppression, unavailable changes, and rolling-frame availability before
-- applying Q4 or top-five filters.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        tot_benes_suppressed,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
monthly_metrics AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        tot_benes_suppressed,
        LAG(month_start) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_month_start,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes,
        ROUND(
            AVG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3m_avg,
        COUNT(*) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_window_count,
        COUNT(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_available_value_count
    FROM monthly_base
),
ranked_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        tot_benes_suppressed,
        previous_month_start,
        previous_tot_benes,
        tot_benes - previous_tot_benes AS absolute_change,
        ROUND(
            100.0
                * (tot_benes - previous_tot_benes)
                / NULLIF(previous_tot_benes, 0),
            4
        ) AS percent_change,
        rolling_window_count,
        rolling_available_value_count,
        rolling_3m_avg,
        ROW_NUMBER() OVER (
            PARTITION BY month_start
            ORDER BY
                tot_benes DESC NULLS LAST,
                bene_fips_cd
        ) AS monthly_position
    FROM monthly_metrics
)
SELECT
    (SELECT COUNT(*) FROM monthly_base) AS base_row_count,
    (SELECT COUNT(*) FROM monthly_metrics) AS monthly_metrics_row_count,
    COUNT(*) AS output_row_count,
    COUNT(*) - (SELECT COUNT(*) FROM monthly_base)
        AS row_count_difference,
    COUNT(DISTINCT bene_fips_cd) AS county_count,
    COUNT(*) FILTER (
        WHERE previous_month_start IS NULL
    ) AS first_period_row_count,
    (SELECT COUNT(*) FILTER (WHERE tot_benes_suppressed)
     FROM monthly_base) AS suppressed_row_count,
    COUNT(*) FILTER (
        WHERE absolute_change IS NULL
    ) AS unavailable_absolute_change_count,
    COUNT(*) FILTER (
        WHERE rolling_available_value_count
              <> rolling_window_count
    ) AS rolling_availability_gap_count
FROM ranked_months;


-- Final Challenge, QA Query 2: Confirm exactly five valid top-ranked counties
-- in each Q4 monthly partition.
WITH monthly_base AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        tot_benes_suppressed,
        TO_DATE(
            year::TEXT || '-' || month || '-01',
            'YYYY-Month-DD'
        ) AS month_start
    FROM clean.medicare_monthly_enrollment_core
    WHERE bene_state_abrvtn = 'MA'
      AND bene_geo_lvl = 'County'
      AND year = 2024
      AND month <> 'Year'
      AND bene_fips_cd IS NOT NULL
      AND bene_fips_cd <> '25999'
),
monthly_metrics AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        tot_benes_suppressed,
        LAG(month_start) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_month_start,
        LAG(tot_benes) OVER (
            PARTITION BY bene_fips_cd
            ORDER BY month_start
        ) AS previous_tot_benes,
        ROUND(
            AVG(tot_benes) OVER (
                PARTITION BY bene_fips_cd
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3m_avg
    FROM monthly_base
),
ranked_months AS (
    SELECT
        bene_fips_cd,
        bene_county_desc,
        month_start,
        tot_benes,
        tot_benes_suppressed,
        previous_month_start,
        previous_tot_benes,
        tot_benes - previous_tot_benes AS absolute_change,
        ROUND(
            100.0
                * (tot_benes - previous_tot_benes)
                / NULLIF(previous_tot_benes, 0),
            4
        ) AS percent_change,
        rolling_3m_avg,
        ROW_NUMBER() OVER (
            PARTITION BY month_start
            ORDER BY
                tot_benes DESC NULLS LAST,
                bene_fips_cd
        ) AS monthly_position
    FROM monthly_metrics
),
final_q4_top5 AS (
    SELECT
        month_start,
        monthly_position,
        bene_fips_cd,
        bene_county_desc,
        tot_benes,
        tot_benes_suppressed,
        previous_tot_benes,
        absolute_change,
        percent_change,
        rolling_3m_avg
    FROM ranked_months
    WHERE month_start IN (
              DATE '2024-10-01',
              DATE '2024-11-01',
              DATE '2024-12-01'
          )
      AND monthly_position <= 5
)
SELECT
    month_start,
    COUNT(*) AS final_row_count,
    COUNT(DISTINCT bene_fips_cd) AS distinct_county_count,
    MIN(monthly_position) AS min_monthly_position,
    MAX(monthly_position) AS max_monthly_position,
    COUNT(*) FILTER (
        WHERE previous_tot_benes IS NULL
    ) AS unavailable_previous_value_count,
    COUNT(*) FILTER (
        WHERE absolute_change IS NULL
    ) AS unavailable_absolute_change_count,
    COUNT(*) FILTER (
        WHERE percent_change IS NULL
    ) AS unavailable_percent_change_count,
    COUNT(*) FILTER (
        WHERE rolling_3m_avg IS NULL
    ) AS unavailable_rolling_avg_count,
    COUNT(*) FILTER (
        WHERE tot_benes_suppressed
    ) AS suppressed_row_count
FROM final_q4_top5
GROUP BY month_start
ORDER BY month_start;
