# MATLAB experiments for the equilibrium paper

Version: `EP-2026-10-22-v1.1.1`. The package follows the revised manuscript's nine-method protocol. MATLAB R2026a is the target release. Base MATLAB and its standard JVM are sufficient for serial runs. Optimization Toolbox, CVX and MOSEK are not required; Parallel Computing Toolbox is needed only for optional parallel execution.

The source has been reviewed and its numerical kernels independently checked in Python. MATLAB was not available in the review environment. `VALIDATION.md` records exactly what was checked; `AUDIT_REPORT_VI.txt` gives the review findings and instructions in Vietnamese. No experiment results or timings are prefilled.

## 1. Run the publication experiment

Extract this version into a fresh folder, set MATLAB's Current Folder to `IP_EP`, and run:

```matlab
RUN_ALL
```

`RUN_ALL.m` sets up the path, runs `EP_RUN_CHECKS`, and then starts or resumes the full publication run. It needs no arguments and can also be opened in the MATLAB Editor and run with the Run button. `START_HERE_VI.txt` gives the complete first-run instructions in Vietnamese.

The equivalent separate commands are:

```matlab
EP_SETUP
EP_RUN_CHECKS
EP_RUN_PUBLICATION
```

`EP_RUN_CHECKS` exercises mathematical identities, numerical certificates, EG centering, operation counts, data preprocessing and export regression fixtures. Its temporary fixtures never enter publication results.

The full publication driver imports the bundled observed charging data automatically if the prepared MAT file is absent. No download, account or API token is needed for the default experiment. It then runs:

- Seven deterministic cases: nonlinear EP at dimensions 100 and 1000 with conditioning parameters 1 and 100, plus electricity, quadratic equilibrium and river-basin models.
- Thirty paired initial points per deterministic case and nine methods: **1,890 deterministic runs**.
- The 31 retained charging days, one paired initial point per day and nine methods: **279 EV runs**.
- **2,169 runs in total**, with a checkpoint after each completed run.

All outputs go to `results_publication`. Rerunning `EP_RUN_PUBLICATION` resumes from compatible checkpoints. An interrupted individual run restarts from its prescribed initial point. Inspect progress with:

```matlab
EP_STATUS
```

Checkpoints are tied to actual numerical inputs, method settings, tolerances, iteration caps, MATLAB version, execution mode and the SHA-256 fingerprint of the MATLAB source. Changing source code intentionally invalidates old checkpoints. Keep earlier results in a separate directory when changing protocols.

To run only deterministic cases:

```matlab
cfg = EP_CONFIG('publication');
cfg.scopes = {'deterministic'};
EP_RUN_PUBLICATION(cfg);
```

A later full run can reuse compatible deterministic checkpoints and add the charging cases. Missing or empty requested real-EV input causes an error; the publication runner cannot silently omit that experiment.

### Short software check

```matlab
EP_RUN_SMOKE
```

This command first runs `EP_RUN_CHECKS`, then uses two initial points, nonlinear dimensions 10 and 100, a cap of 200 updates, and one explicitly synthetic charging instance. Some smoke runs may reach the cap. This is a short software exercise, not evidence of publication performance. Its separate `results_smoke` output cannot be copied to the manuscript by the publication copy command.

## 2. Methods and mathematical maps

| Method | Inertia | Iteration step divided by gamma |
|---|---:|---:|
| NM | 0 | 0.5 |
| I-0.10 | 0.10 | 0.5 |
| I-0.20 | 0.20 | 0.5 |
| I-0.25 | 0.25 | 0.5 |
| NM-fast | 0 | 1.8 |
| EG | 0 | 0.9 |
| IS-0.10 | 0.10 | 1.5555555556 |
| IS-0.20 | 0.20 | 1.125 |
| IS-0.25 | 0.25 | 0.8 |

The IS step equals 90% of `2*gamma*(1-3*alpha)/(1-alpha)^2`. Inertial parameters must satisfy the strict proved bound; steps must be finite and positive. EG uses two regularized subproblems, with the original point as the quadratic center of its second subproblem. The first six methods are the main comparisons; all nine enter the parameter study and charging result tables.

| Model | Implemented subproblem |
|---|---|
| Weighted nonlinear EP | `h_i(t)=sqrt(1+a_i*t^2)`, with weights logarithmically spaced from `1/kappa` to 1. For first argument `u` and center `v`, each coordinate solves `z-v+lambda*a_i*h_i(u_i)*z/h_i(z)=0` by safeguarded Newton iteration. |
| Quadratic EP | Strictly convex QP with Hessian `I+2*lambda*Q` and right-hand side `v-lambda*((P-Q)*u+r)`. This preserves the original nonlinear dependence on the second argument. |
| Electricity | Projected forward step for the affine VI, using a clipped box projection. |
| River basin | Projected forward step for the shared-constraint VI, using a three-dimensional polytope projection. |
| EV charging | Projected forward step with the replicated aggregate-load operator and row-wise capped-simplex projection. |

For the one-subproblem method, `u=v=y_k`. For EG, the first map has `u=v=x_k`; its second has `u=w_k` and `v=x_k`. Small QPs use finite active-set enumeration with certificates in the original primal/dual variables. The mathematical subproblems are solved numerically to the configured inner tolerance.

## 3. Residuals, timing and comparisons

Every method uses the same current-point diagnostic, with `eta=gamma`:

```text
R_eta(x) = norm(x - U_eta(x)) / (eta * max(1,norm(G(x))))
```

Here `U_eta` is the actual model's noninertial equilibrium map. For the weighted nonlinear EP, `G(x)=a.*x`; for the quadratic EP, `G(x)=(P+Q)*x+r`; for VI models, `G=F`. EV matrix norms are Frobenius norms. The residual is evaluated at initialization and after each update, independently of the method's iteration step.

Defaults are residual tolerance `1e-5`, deterministic cap 50,000 updates, EV cap 10,000, inner tolerance `1e-12`, and accepted subproblem certificate threshold `1e-9`.

All methods in a paired instance start with the same `x0=x1`. Seeds depend on the model identifier and trial, and method order is reproducibly shuffled. Five untimed updates warm each numerical path; the measured run restarts from the original point with reset solver states and counters.

Elapsed time includes updates, all residual diagnostics, history recording and final feasibility/gap evaluation. Import, model construction, references, precomputed factorizations, warm-up, plotting and checkpoint I/O are outside the timer. Update and diagnostic work are counted separately. With `K` completed updates:

- One-subproblem methods use `K` update and `K+1` diagnostic subproblems: `2*K+1` total.
- EG uses `2*K` update and `K+1` diagnostic subproblems: `3*K+1` total.

Matched-step ratios compare I methods with NM. Scaled-step ratios compare IS methods with NM-fast. Iteration and time ratios each require a successful pair and their own positive finite denominator. A ratio greater than one favors the method being compared to the baseline. Counts of eligible pairs are exported separately.

Median `[IQR]` cells report the median and **IQR width, Q3-Q1**. Quantiles use linear interpolation at rank `1+(n-1)*p`. Capped runs remain in descriptive summaries. Nonfinite failures are retained instead of being silently discarded; NaN makes the affected statistic unavailable, and infinite outcomes propagate.

The default run is serial. To evaluate parallel throughput, use a separate output directory:

```matlab
cfg = EP_CONFIG('publication');
cfg.parallel = true;
cfg.n_workers = 12;
cfg.output_dir = fullfile(pwd,'results_publication_parallel');
EP_RUN_PUBLICATION(cfg);
```

The actual worker count is recorded. Concurrent elapsed times must be interpreted for that execution mode.

## 4. Charging data and certificates

`data/caltech_may2019.json` is the fixed 964-record ACN-Data subset obtained from the documented SustainGym archive. Its source, transformation, pinned revision, checksums and license notice are in `data/README.md` and `data/SUSTAINGYM_LICENSE.txt`.

The importer converts timestamps to Los Angeles local time and retains complete 15-minute slots within same-day sessions. It uses the recorded delivered energy and a modeled 7.2 kW cap; it never clips energy to make a session feasible. The default input retains **870 sessions across 31 days** after excluding 51 cross-day records, 10 empty windows and 33 energy-infeasible records. The importer preserves the first valid duplicate occurrence and records mutually exclusive exclusions.

The prepared MAT file includes input SHA-256, upstream provenance, parameters, retained identifiers and audit counts. The run freezes this evidence in its manifest. Exports use that frozen snapshot, even if the prepared input file is later changed.

To import the bundled source explicitly, use `EP_IMPORT_ACN`. To use a different complete export, supply its actual path to that function. `EP_DOWNLOAD_ACN` is an optional live-API route that reads `ACN_API_TOKEN` from the environment and verifies complete pagination and the advertised total before importing; credentials are not saved. The default protocol needs none of these network steps.

EV quality includes the convex objective, the Frank-Wolfe upper bound on objective error, normalized gap, maximum energy-equality error in kWh and maximum bound violation in kW. The linear oracle fills available slots in increasing aggregate-load order. No schedule-coordinate reference error is used because different schedules can attain the same minimum.

## 5. Export tables and figures

Exports are generated at the end of a run. Rebuild them from compatible checkpoints with:

```matlab
EP_EXPORT
```

The full default protocol produces eleven LaTeX inputs:

| File under `tables/` | Contents |
|---|---|
| `nonlinear_results.tex` | Nonlinear cases, six main methods |
| `deterministic_results.tex` | Three other deterministic cases, six main methods |
| `reference_solutions.tex` | Small-model reference vectors and KKT certificates |
| `paired_speedups.tex` | Matched-step ratios against NM |
| `parameter_sensitivity.tex` | Scaled inertial results and ratios against NM-fast |
| `ev_data_summary.tex` | Frozen actual-data selection counts |
| `ev_results.tex` | Nine-method EV performance and total work |
| `ev_quality.tex` | Objective, gap and physical feasibility |
| `environment.tex` | Actual recorded MATLAB/host/execution details |
| `deterministic_discussion.tex` | Brief description derived from recorded deterministic results |
| `ev_discussion.tex` | Brief description derived from recorded EV results |

The eight figure basenames are `nonlinear_100_convergence`, `nonlinear_1000_convergence`, `electricity_convergence`, `quadratic_convergence`, `river_convergence`, `ev_convergence`, `ev_daily_comparison` and `ev_load_profile`. Each is saved as PNG and vector PDF. Nonlinear figures include both default conditioning values. Curves use medians and interquartile bands; final residuals are held constant for curve alignment. The EV load illustration selects the largest retained day, with earliest-date tie breaking, independently of solver performance.

CSV outputs include `all_runs.csv`, `summary.csv`, paired details and summaries, daily EV results and frozen data selection counts. JSON outputs contain the recorded protocol and input provenance. Checkpoints retain individual histories and final iterates.

For the default sibling `manuscript` folder:

```matlab
EP_COPY_TO_MANUSCRIPT
```

For another folder, call `EP_COPY_TO_MANUSCRIPT(results_dir, manuscript_dir)` with the actual two paths. This verifies that all scheduled runs are recorded, rejects solver/certificate failures, and copies only the current tables and figures. Iteration-cap outcomes remain visible and are not reclassified as success. Captions and labels stay in the manuscript. Copying also removes obsolete artifacts previously managed by this command. Publication conclusions should be written from the actual MATLAB results.
