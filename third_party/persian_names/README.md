# Persian names dataset attribution

This project vendors the normalized `names.json` dataset from [nabidam/persian-names](https://github.com/nabidam/persian-names).

- Upstream commit: `68f5cb39a25c19ecaf6f60f3181aea200f8206f`
- License: MIT; see [LICENSE](./LICENSE).
- Upstream describes the dataset as 8,816 Persian names with gender labels, some unknown.
- The upstream README identifies its input resources as two internet-downloaded XLS/CSV files and documents basic Arabic-character and diacritic cleanup.
- This app imports the name forms and gender labels only. It does not import meanings, etymologies, transliterations, or pronunciations from this dataset. Those fields remain `Unknown` until independently sourced.
