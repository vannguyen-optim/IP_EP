# Caltech charging sessions, May 2019

`caltech_may2019.json` contains 964 observed ACN-Data charging sessions from
Caltech, selected by local connection date from 1 through 31 May 2019. It is
a fixed, documented subset of the SustainGym authors' ACN-Data cache. The
MATLAB experiments read this bundled file without network access.

## Sources and attribution

The primary dataset is [ACN-Data](https://ev.caltech.edu/dataset.html):

Z. J. Lee, T. Li, and S. H. Low, “ACN-Data: Analysis and Applications of an
Open EV Charging Dataset,” Proceedings of the Tenth ACM International
Conference on Future Energy Systems, pp. 139–149, 2019.
[DOI: 10.1145/3307772.3328313](https://doi.org/10.1145/3307772.3328313).

The fixed intermediate source is the Caltech session cache in
[SustainGym](https://github.com/chrisyeh96/sustaingym), revision
`11d9bbdad7ace18d3d182c9a1f98f2f3339dad86` (5 December 2022):

- [Immutable compressed CSV](https://raw.githubusercontent.com/chrisyeh96/sustaingym/11d9bbdad7ace18d3d182c9a1f98f2f3339dad86/sustaingym/data/evcharging/acn_data/caltech/2019-05-01%202019-08-31.csv.gz).
- [Immutable export code](https://github.com/chrisyeh96/sustaingym/blob/11d9bbdad7ace18d3d182c9a1f98f2f3339dad86/sustaingym/envs/evcharging/utils.py).
- [License at that revision](https://github.com/chrisyeh96/sustaingym/blob/11d9bbdad7ace18d3d182c9a1f98f2f3339dad86/LICENSE): MIT, Copyright (c) 2022 Christopher Yeh. Its complete notice is supplied in `SUSTAINGYM_LICENSE.txt`. The current repository uses a different license; the attribution here describes the pinned revision.

SustainGym's associated full paper is C. Yeh, V. Li, R. Datta, J. Arroyo,
N. Christianson, C. Zhang, Y. Chen, M. M. Hosseini, A. Golmohammadi,
Y. Shi, Y. Yue, and A. Wierman, “SustainGym: Reinforcement Learning
Environments for Sustainable Energy Systems,” Advances in Neural
Information Processing Systems 36, pp. 59464–59476, 2023.
[Official proceedings](https://proceedings.neurips.cc/paper_files/paper/2023/hash/ba74855789913e5ed36f87288af79e5b-Abstract-Datasets_and_Benchmarks.html).

The public ACN API did not return a usable response during preparation,
so the fixed author cache is identified explicitly as the retrieval
source. This export includes every May record in that cache; it does not
claim to certify the completeness of the live ACN API database.

## Exact transformation

The source compressed CSV has 3,527 records for May–August 2019. The
bundled JSON contains the 964 records whose connection timestamps lie in
the half-open UTC interval
`[2019-05-01T07:00:00Z, 2019-06-01T07:00:00Z)`, corresponding to May in
`America/Los_Angeles`.

Only four source columns are retained:

| JSON field | Source CSV column |
|---|---|
| `sessionID` | `session_id` |
| `connectionTime` | `arrival` |
| `disconnectTime` | `departure` |
| `kWhDelivered` | `delivered_energy (kWh)` |

The pinned SustainGym export code maps these columns directly from the
corresponding original ACN fields. Times were converted from the recorded
UTC offsets to ISO 8601 UTC strings without rounding. Energy values were
preserved. The JSON export itself does not deduplicate records or filter
by same-day status, energy, interval availability, or capacity. Those
operations are performed transparently by `EP_IMPORT_ACN.m` when the
prepared MAT input is created. The default publication driver imports the
bundled JSON automatically when the prepared input is missing.
No synthetic sessions, requested-energy estimates, user identifiers, or
station metadata are included.

SHA256 checksums:

```text
Source compressed CSV:
d23a07e3b5175dca0da107610557f604fa177f71bfc696687c70a0470964047b

Bundled caltech_may2019.json:
669a4a118b77afb4626b0da5cfa7132e2de770172ee0d7c8f54ee1b42ccfb01b

Pinned SUSTAINGYM_LICENSE.txt:
886ff31b8211ac93c4052b87b099703eabf1c39d6d6f7c6acdaf8c534b9f3bbe
```

## Preprocessing and reproducibility check

The loader keeps the first occurrence of each nonempty session ID with
valid ordered timestamps and finite positive energy. A malformed first
copy does not suppress a later valid copy. It requires connection within
the stated interval,
disconnection after connection on the same Los Angeles calendar day,
and finite positive delivered energy. It then keeps only the complete
15-minute intervals within each session. A session is retained if it has
at least one complete interval and its recorded energy does not exceed
`7.2 kW * 0.25 h * number_of_available_intervals`. Energy is never clipped
to make a session feasible.

The independent Python check of the bundled data gives:

| Quantity | Count |
|---|---:|
| Original May–August cache rows | 3,527 |
| Bundled May input records | 964 |
| Distinct session IDs | 964 |
| Excluded for different local connection/disconnection dates | 51 |
| Valid same-day sessions with positive delivered energy | 913 |
| Excluded for no complete 15-minute interval | 10 |
| Excluded for exceeding the available 7.2 kW capacity | 33 |
| Retained sessions | 870 |
| Daily instances | 31 |

All other exclusion counts are zero for this fixed file. Daily retained
session counts range from 4 to 44; the earliest day with 44 is 7 May 2019.
The MATLAB loader returns the full counts and the actual input-file hash
for storage with each experiment. A new live API export may legitimately
differ from this fixed cache and must be reported as a different input.

## Importing and replacing the input

The default source is `data/caltech_may2019.json`. The publication driver
imports it into `data/acn_caltech_may2019.mat` if the prepared input does
not exist. To import explicitly, run `EP_IMPORT_ACN` from the package root.
Selection-count and session-level audit CSV files are saved next to the
MAT file. The original JSON `provenance` object is preserved under
`provenance.upstream`, alongside the local input-file SHA256 and the
preprocessing settings.

The bundled data need no account or token. To create a separate export
from the live official API, set the `ACN_API_TOKEN` environment variable
and run `EP_DOWNLOAD_ACN`. This optional command checks the API session
array, advertised record total and pagination before replacing its raw
JSON output and importing it. Incomplete downloads are rejected. API
credentials are not saved in the raw data or provenance. A new API export
may differ from the pinned cache; its own source identity is preserved.

For another actual export, call `EP_IMPORT_ACN('/path/to/export.json')`,
or supply a CSV containing `sessionID`, `connectionTime`, `disconnectTime`
and `kWhDelivered`. The publication driver does not substitute synthetic
sessions when input data are missing or empty. The in-memory
`ep.synthetic_ev` fixture is restricted to software smoke checks.
