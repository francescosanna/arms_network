# Data decisions

Francesco Sanna, 15 Nov 2026

## Source
- SIPRI Arms Transfers Database, March 2026 release (data 1950-2025).
  https://www.sipri.org/databases/armstransfers
- 8 CSV files, generated 10 Nov 2026, years 2000-2025, values in TIV:
  - 4 "Supplier" files (China, Russia, Iran, North Korea as supplier, all recipients):
    `Supplier_<Country>_import-export-values_2000-2025.csv`.
    These give the edges: every flow from one of the four to anyone.
  - 4 "Recipient" files (each of the four as recipient, all suppliers):
    `Recipient_<Country>_import-export-values_2000-2025.csv`.
    Only the total row is used: each state's total imports, the denominator for dependence.
- TIV measures the volume of transfers (based on production costs), not their sales price.

## Cleaning decisions
- **Empty cells vs zeros.** Empty = no deliveries, so the row is dropped. `0` = a real transfer
  under 0.5 TIV, so it is kept. (5,382 rows after pivoting; 1,299 after dropping empty cells.)
- **SIPRI total rows dropped; own totals calculated.** SIPRI rounds its totals separately, so
  they don't always equal the sum of the rows (Russia's exports in 2005: 5,202 from the rows,
  5,199 in SIPRI's total). 93 rows removed, 1,206 left.
- **Unknown recipients dropped.** 4 rows, 12 TIV, 0.007% of all TIV: these edges have no real
  end point. 1,202 rows left. (They are 0.8% of Iran's exports, so Iran's totals are very
  slightly low.)
- **Non-state actors and international organisations kept and labelled** in `actor_type`
  (SIPRI marks them with `*` and `**`): state 1,169, non_state 28, int_org 5. When counting
  export partners, only states are counted; non-state recipients are reported separately.
- **Spellings:** `China`, `Russia`, `Iran`, `North Korea` (the file names use `NorthKorea`).
- **Reading the data:** all columns are read as text, then converted to numbers in one
  explicit step (`parse_number`, which also handles cells like `"0 "` with a trailing space).
- **Total imports:** years with no imports are set to 0 (not NA), so period sums work.

## Analysis decisions
- **Ego network, not global.** SIPRI only gives supplier-recipient pairs for the suppliers
  you select, so the data cover flows *from* the four. Flows *among* the four are complete.
  No global centrality (the four would be central by construction).
- **Periods set from theory before looking at the data:** 2000-2013, 2014-2021 (Crimea),
  2022-2025 (full-scale invasion). Periods have different lengths, so flows are compared
  as TIV per year. The annual series is also reported, and the results are checked with
  different period breaks.
- **Export totals recalculated, import totals taken from SIPRI.** Exports are summed from
  the rows (SIPRI rounds its totals separately). For imports we only have SIPRI's total row,
  because the data don't include rows for other suppliers (e.g. France -> China).
- **Robustness checks (section G of `03_analysis.R`):**
  - G1, breaks at 2012 and 2020: the same edges appear in each period (5 / 4 / 5), so density
    and reciprocity are unchanged; only volumes shift.
  - G2, one break at 2022: 2000-2021 has 6 edges (density 0.5, reciprocity 0.33);
    2022-2025 is unchanged (5 edges, 0.417, 0.8).
  - G3, dropping period edges under 5 TIV per year: 5 / 2 / 4 edges, reciprocity 0 / 0 / 0.5.
    Russia <-> Iran is the only two-way tie left.
- **Plot choices.** Years with no deliveries are filled with 0 (`complete()`), so lines don't
  skip them. In the network plot, edge width uses a square-root scale so small edges stay
  visible; this makes edges hard to compare, so exact values are in the tables.

## Known limits
- SIPRI covers major weapons only: no small arms, no ammunition, no artillery under 100 mm.
  So North Korean artillery shells to Russia are not in the data.
- North Korean and Iranian flows are secret or under-recorded.
- One type of tie (arms transfers) is not "cooperation" as a whole.
- Deliveries lag decisions, so period breaks are approximate.
- Iran -> Russia is probably mostly drones (SIPRI counts one-way attack drones as missiles).
  To check in the item-level data before claiming it.
  - Ego network only: pair-level data cover flows from the four, not the global network.
- Reciprocity ignores weights: part of its rise rests on very small China -> Russia flows (G3).
- Support to armed groups (Hezbollah, Houthis) is badly understated.
- Small volumes: Iran's 297 TIV to Russia in 2022-2025 is less than a tenth of what Russia
  sent India (3,744).
- The data show what was delivered and when, not why or when it was decided.