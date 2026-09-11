## Data Source

This project uses the public **CMS Medicare Monthly Enrollment** dataset.

- **Source:** Centers for Medicare & Medicaid Services (CMS)
- **Dataset:** Medicare Monthly Enrollment
- **Source file:** `Medicare_Monthly_Enrollment_May_2026.csv`
- **Format:** CSV
- **Accessed:** September 2026
- **Expected data rows:** 580,443
- **SHA-256:** `0a6b02702c082895df2afb33a9a6797dd3691d6f7a08e3ccd92ef7b81ac8c5c9`
- **CMS source page:** https://data.cms.gov/summary-statistics-on-beneficiary-enrollment/medicare-and-medicaid-reports/medicare-monthly-enrollment/data

The raw CSV is excluded from version control.

The PostgreSQL raw layer stores all 60 source columns as `TEXT` to preserve the original source representation, including privacy-suppressed beneficiary values represented by `*`. Data types and analytical transformations are applied in later layers rather than during ingestion.