# `data_csv` Layout

This directory only keeps CSV files that are still loaded directly at runtime.

Current layout:

- root: shared runtime CSVs such as `waves.csv`, `stages.csv`, `hero_roster.csv`
- `outgame/`: outgame and archive UI CSVs
- `by_feature/`: feature-grouped runtime CSVs

Rule of thumb:

- if a table is still read through `CsvLoader`, keep it in `data_csv/`
- keep feature-specific CSVs grouped under their feature folder when that layout is already in use
