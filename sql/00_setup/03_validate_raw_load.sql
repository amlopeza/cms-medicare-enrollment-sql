-- Post-load validation of raw.medicare_monthly_enrollment.
-- Run after 02_load_raw_data.psql and inspect each result before moving on.

-- Check 1: Confirm the load happened at all by counting the rows that landed
-- in the raw table.
SELECT COUNT(*) AS loaded_rows
FROM raw.medicare_monthly_enrollment;

-- Check 2: Spot-check a known county (FIPS 01001 = Autauga County, AL) to
-- confirm the columns landed in the right fields and that the leading zero of
-- the FIPS code survived, which is the main reason it is stored as TEXT.
SELECT bene_state_abrvtn,
       bene_county_desc,
       bene_fips_cd
FROM raw.medicare_monthly_enrollment
WHERE bene_fips_cd = '01001'
LIMIT 5;

-- Check 3: Count the rows whose tot_benes carries the privacy-suppression
-- marker '*', confirming the TEXT columns preserved it instead of rejecting it.
SELECT COUNT(*) AS suppressed_tot_benes
FROM raw.medicare_monthly_enrollment
WHERE tot_benes = '*';

-- Check 4: List the geography levels present. Expected: County, National and
-- State, since each row is reported at one of those three levels.
SELECT DISTINCT bene_geo_lvl
FROM raw.medicare_monthly_enrollment
ORDER BY bene_geo_lvl;

-- Check 5: List the reporting periods present. Expected: the twelve month
-- names plus 'Year', which marks the annual aggregate rows. Note the values are
-- names rather than numbers, so this ordering is alphabetical, not chronological.
SELECT DISTINCT month
FROM raw.medicare_monthly_enrollment
ORDER BY month;

-- Check 6: Separate the two kinds of missing data in tot_benes. Check 3 counts
-- the suppressed rows on their own; this contrasts them with true NULLs, which
-- mean an absent value rather than a withheld one and are handled differently
-- downstream.
SELECT
    COUNT(*) FILTER (WHERE tot_benes = '*') AS suppressed_tot_benes,
    COUNT(*) FILTER (WHERE tot_benes IS NULL) AS null_tot_benes
FROM raw.medicare_monthly_enrollment;

-- Check 7: Break down missing FIPS codes by geography level. National and State
-- rows are expected to have no county FIPS; County rows having one is what this
-- check is really testing. Blanks are counted apart from NULLs because an empty
-- string and a NULL both read as "missing" but must be cleaned differently.
SELECT
    bene_geo_lvl,
    COUNT(*) FILTER (WHERE bene_fips_cd IS NULL) AS null_fips,
    COUNT(*) FILTER (
        WHERE bene_fips_cd IS NOT NULL
          AND BTRIM(bene_fips_cd) = ''
    ) AS blank_fips
FROM raw.medicare_monthly_enrollment
GROUP BY bene_geo_lvl
ORDER BY bene_geo_lvl;
