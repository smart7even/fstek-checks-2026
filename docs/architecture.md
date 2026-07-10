# Architecture

The repository uses an audit-engine layout under `fstek_audit/`. Root entrypoints are `check_all.sh` for a single host and `fleet_check.sh` for fleet orchestration.

## Layout

- `check_all.sh` delegates to `fstek_audit/run.sh`.
- `fleet_check.sh` delegates to `fstek_audit/run_fleet.sh`.
- `fstek_audit/core/load.sh` sources shared modules from `fstek_audit/core/`.
- `fstek_audit/core/profile.sh` parses class/enhancement flags and loads local profile expectations.
- `fstek_audit/core/registry.sh` reads measure applicability from `fstek_audit/checks/manifest.tsv` and keeps enhancement mappings.
- `fstek_audit/core/status.sh` renders verdict lines and keeps status counters.
- `fstek_audit/core/os_detector.sh` detects Astra Linux, ALT Linux, RED OS, and generic Linux.
- `fstek_audit/core/common.sh` holds reusable read-only evidence helpers used by measure files.
- `fstek_audit/core/runner.sh` owns per-measure lifecycle helpers.
- `fstek_audit/core/logger.sh` and `fstek_audit/core/csv_engine.sh` are small foundations for reporting output.
- `fstek_audit/core/report.sh` writes per-host log and JSON summary artifacts.
- `fstek_audit/core/fleet.sh` implements ping/SSH availability checks and inventory parsing for fleet runs.
- `fstek_audit/adapters/` contains OS adapter placeholders. Adapter-specific evidence collection has not been migrated yet.
- `fstek_audit/checks/manifest.tsv` is the source of truth for implemented measures. It maps each measure code to its section, measure file, entry function, supported classes, title, and component.
- `fstek_audit/checks/<GROUP>/` directories contain measure-specific logic. Each measure file defines `run_check`.
- `fstek_audit/config/` contains example profile/scope and fleet inventory files.
- `fstek_audit/output/` is reserved for generated reports and kept empty in git.

## Single-Host Reports

`check_all.sh --output-dir <dir> [--batch-id <id>]` writes:

- `<dir>/<batch-id>/<hostname>-<timestamp>.log` — full console output
- `<dir>/<batch-id>/<hostname>-<timestamp>.json` — machine-readable summary (`fstek-audit-summary/v1`)

When `--batch-id` is omitted, artifacts are written directly under `<dir>/`.

## Fleet Orchestration

`fleet_check.sh --inventory <file> [--class K1|K2|K3] [--batch-id <id>] [--output-dir <dir>]`:

1. Loads host list from inventory (`fstek_audit/config/inventory.example.conf`).
2. Checks each host with ping and SSH.
3. Rsyncs the checks bundle from the controller to `FSTEK_REMOTE_REPO` on each host.
4. Runs remote `sudo -n ./check_all.sh --class ... --output-dir ...` over SSH.
5. Collects log/JSON artifacts into `fstek_audit/output/fleet/<batch-id>/<host>/`.
6. Writes `fleet-summary.csv` with reachability and scan status per host.

Host scans run **in parallel** (all at once by default). See `docs/fleet_inventory.md`
for inventory format, SSH auth (key or password), and parallelism limits.

SFTP upload and cross-host CSV aggregation are implemented in stages 3–4.
See `docs/fleet_inventory.md` and `fstek_audit/config/sftp.example.conf`.

## Measure Files

Measure-specific logic lives in `fstek_audit/checks/<SECTION>/<CODE>.sh`. Single-measure runs use `check_all.sh --measure <CODE>`.

## Manifest Registry

`fstek_audit/checks/manifest.tsv` is tab-separated and has these columns:

```text
code	section	file	function	classes	title	component
```

Manifest `file` paths are relative to `fstek_audit/`, for example `checks/IAF/IAF_01.sh`.

A `classes` value of `-` means the measure is implemented and runnable, but appendix 2 marks no `+` for K1/K2/K3. Such measures are included in full `check_all.sh` runs and `--measure`, but skipped by `--class` filters.

`fstek_audit/run.sh` uses the manifest for `--list`, `--measure`, `--section`, and `--class` selection. Root `check_all.sh` delegates to the same runner so class filtering cannot drift into separate Bash `case` statements again.
