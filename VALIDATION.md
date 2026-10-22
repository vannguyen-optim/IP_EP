# Validation record — EP-2026-10-22-v1.1.1

## Scope and execution status

The supplied `IP_EP.zip` was reviewed against its mathematical formulas and the latest numerical protocol in the manuscript. Its modular MATLAB structure, checkpoint/resume logic and base-MATLAB solvers were retained. The original five-method, five-case protocol was extended to the current nine-method, seven-case protocol.

**MATLAB and Octave were not available in the review environment.** MATLAB source was parsed with MISS_HIT, and separate Python/SciPy reconstructions checked the numerical kernels. These checks neither execute the MATLAB implementation nor provide MATLAB timings or publication experiment results. The included `EP_RUN_CHECKS` must be run in the target MATLAB installation.

## Defects and changes

| Original issue | Revision |
|---|---|
| Five methods and five deterministic cases did not match the current manuscript. | Added EG, three scaled inertial settings, weighted nonlinear cases with conditioning 1 and 100, and corresponding output tables. |
| Missing/empty actual charging input could be silently omitted. | Bundled the documented observed input, added automatic offline import, and reject missing/empty requested real input. |
| Data summary exports could reread a different prepared input from the one used in saved results. | Freeze audit/provenance at run creation and export only that snapshot. |
| NaN/Inf outcomes were silently removed by statistics. | Preserve nonfinite outcomes and expose affected summaries/failure counts. |
| Parameter admissibility did not explicitly exclude negative inertia or negative steps. | Validate finite positive steps, inertia range, strict theorem bound and diagnostic step. |
| A malformed first duplicate suppressed a later valid session. | Retain the first occurrence with a valid ID, ordered timestamps and positive finite energy; record distinct IDs separately. |
| API downloads did not fully verify the response array and final advertised count. | Require valid items/total, consistent pages and complete pagination before replacing raw output. |
| Five-color plots broke when methods were added. | Allocate colors for the actual main-method count. |
| A successful pair with a zero/nonfinite denominator could be included in a reported time-ratio count. | Separate positive-finite iteration and time eligibility/counts. |
| Tables/figures differed from the manuscript's current inputs. | Produce the current eleven TeX inputs and eight figure basenames with IQR widths, total work and relative gap. |
| Source changes could escape a manually maintained code-version label. | Hash all MATLAB sources and include the fingerprint in run/checkpoint provenance and cache signatures. |

The original nonlinear, small-QP and capped-simplex numerical kernels did not show a formulation defect in the independent comparisons. They were retained, with the distinct first-argument/center interface needed for EG and weighted nonlinear functions.

## Static source checks

MISS_HIT parsed all **44 MATLAB source files**, reporting:

```text
MISS_HIT Lint Summary: 44 file(s) analysed, everything seems fine
```

Primary function/filename agreement and internal `ep.*` dependencies were checked. The original `clock` variable that shadowed a MATLAB builtin was renamed. Static parsing is separate from MATLAB Code Analyzer and runtime testing.

A focused integration review checked EG's second center, weighted derivatives, gamma for the quadratic bifunction, reference operators, warm-up resets, measured operation counts, model seeds, method metadata and checkpoint signatures. Export filenames were compared with the manuscript's required inputs.

## Independent numerical comparisons performed in this review

| Formula/kernel | Independent comparison | Largest observed discrepancy |
|---|---|---|
| Original nonlinear scalar subproblem | 615 roots against bracketed reference root finding | Normalized root error `4.12e-13`; normalized optimality residual `9.70e-13` |
| Weighted nonlinear subproblem with distinct first argument and center | 518 roots against independent reference roots | Normalized root error `9.24e-13`; normalized stationarity residual `9.71e-13` |
| Capped-simplex projection | 400 rows, including ties and boundary targets, against independent bisection | Coordinate difference `2.33e-13`; normalized mass error `1.77e-13` |
| Small strictly convex QP | 100 problems against independent constrained minimization | Relative objective difference `2.60e-11`; normalized KKT residual `9.10e-16` |
| Quadratic EP with distinct first argument and center | 25 QPs against the original bifunction objective | Relative objective difference `2.92e-14`; absolute KKT residual `3.28e-14` |

The comparison QP solver itself is numerical; objective disagreement is reported without attributing all error to either solver. These are finite software checks, not proofs of correctness for arbitrary inputs and not performance claims.

## Data verification

The bundled JSON SHA-256 is:

```text
669a4a118b77afb4626b0da5cfa7132e2de770172ee0d7c8f54ee1b42ccfb01b
```

The recorded SustainGym source revision is `11d9bbdad7ace18d3d182c9a1f98f2f3339dad86`. The fixed input is preserved byte-for-byte with its provenance and pinned license notice. Source details are in `data/README.md`.

An independent Python replay of the revised preprocessing rules returned 964 input records, 51 cross-day exclusions, 913 valid same-day records, 10 empty windows, 33 energy-infeasible records and **870 retained sessions over 31 days**. A three-record invalid-first duplicate fixture returned one invalid record, one retained record and one duplicate. The default bundled records have 964 distinct identifiers.

## Reproducible MATLAB checks supplied

`EP_RUN_CHECKS` includes checks for:

- All nine default parameter choices and rejection of negative inertia, negative steps and a zero diagnostic step.
- Independent reference QP positivity and KKT certificates.
- Original and weighted nonlinear B1/B2 inequalities and the diagonal operator.
- Scalar roots with equal or distinct first argument and center, against independent bisection.
- Original small-QP primal/dual stationarity and complementarity.
- Capped-simplex projections with zero, full and nearly boundary energy targets.
- Stopping at an exact solution before any update.
- EG's original center in the second minimization and its two-subproblem accounting.
- Separate update/diagnostic counts and physical feasibility in a short EV trajectory.
- Known quartiles, propagation of NaN/Inf and separate ratio eligibility.
- SHA-256, UTC/local-date conversion, complete slots, exclusion accounting and duplicate behavior.
- Upstream provenance and the bundled 870-session, 31-day selection.
- Rejection of missing/empty requested actual input and incomplete API pages.
- Rejection of stale checkpoint signatures and obsolete EV output names.
- Frozen export selection counts even when the live prepared input is changed.
- Visibility of failed runs in exported summary statistics.

Fixtures are temporary software checks. Smoke data are explicitly synthetic and are barred from the publication copy workflow. Publication output must be generated from the actual MATLAB run using the provided observed data or another explicitly identified real source.

## Complete-run packaging

The v1.1.1 bundle adds `RUN_ALL.m` as a single entry point and `START_HERE_VI.txt` for first-run instructions. The launcher calls setup, the existing checks and the full publication driver in that order; numerical methods and protocol values are unchanged. All required internal functions and the offline source JSON are included. Prepared MAT data, result directories, tables and figures are generated on the user's machine.
