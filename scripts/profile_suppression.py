import pandas as pd

file_path = "data/Medicare_Monthly_Enrollment_May_2026.csv"

suppressed_counts = None

for chunk in pd.read_csv(
    file_path,
    dtype=str,
    keep_default_na=False,
    chunksize=50_000
):
    counts = chunk.eq("*").sum()

    if suppressed_counts is None:
        suppressed_counts = counts
    else:
        suppressed_counts = suppressed_counts.add(counts)

result = (
    suppressed_counts[suppressed_counts > 0]
    .sort_values(ascending=False)
)

print(result)