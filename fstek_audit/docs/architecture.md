# Architecture

The repository uses an audit-engine layout under `fstek_audit/`. The only root-level entrypoint is `check_all.sh`.

## Layout

- `check_all.sh` delegates to `fstek_audit/run.sh`.
- `fstek_audit/core/load.sh` sources shared modules from `fstek_audit/core/`.
- `fstek_audit/core/profile.sh` parses class/enhancement flags and loads local profile expectations.
- `fstek_audit/core/registry.sh` reads measure applicability from `fstek_audit/checks/manifest.tsv` and keeps enhancement mappings.
- `fstek_audit/core/status.sh` renders verdict lines and keeps status counters.
- `fstek_audit/core/os_detector.sh` detects Astra Linux, ALT Linux, RED OS, and generic Linux.
- `fstek_audit/core/common.sh` holds reusable read-only evidence helpers used by measure files.
- `fstek_audit/core/runner.sh` owns per-measure lifecycle helpers.
- `fstek_audit/core/logger.sh` and `fstek_audit/core/csv_engine.sh` are small foundations for later runner/reporting work.
- `fstek_audit/adapters/` contains OS adapter placeholders. Adapter-specific evidence collection has not been migrated yet.
- `fstek_audit/checks/manifest.tsv` is the source of truth for implemented measures. It maps each measure code to its section, measure file, entry function, supported classes, title, and component.
- `fstek_audit/checks/<GROUP>/` directories contain measure-specific logic. Each measure file defines `run_check`.
- `fstek_audit/config/` contains example profile/scope files.
- `fstek_audit/output/` is reserved for generated reports and kept empty in git.

## Measure Files

Measure-specific logic lives in `fstek_audit/checks/<SECTION>/<CODE>.sh`. Single-measure runs use `check_all.sh --measure <CODE>`.

## Manifest Registry

`fstek_audit/checks/manifest.tsv` is tab-separated and has these columns:

```text
code	section	file	function	classes	title	component
```

Manifest `file` paths are relative to `fstek_audit/`, for example `checks/IAF/IAF_01.sh`.

`fstek_audit/run.sh` uses the manifest for `--list`, `--measure`, `--section`, and `--class` selection. Root `check_all.sh` delegates to the same runner so class filtering cannot drift into separate Bash `case` statements again.
