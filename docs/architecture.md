# Architecture

This repository is being refactored toward an audit-engine layout under `fstek_audit/` while preserving the current command-line surface.

## Current compatibility model

The root-level `check_all`, `check_all.sh`, and `lib_fstek.sh` remain supported. Measure logic lives under `fstek_audit/checks/` and is invoked through the manifest-driven runner.

No check logic or verdict semantics are changed by this layout step.

## Layout

- `fstek_audit/run.sh` and `fstek_audit/check_all.sh` wrap the current root aggregate runner.
- `fstek_audit/core/profile.sh` parses class/enhancement flags and loads local profile expectations.
- `fstek_audit/core/registry.sh` reads measure applicability from `checks/manifest.tsv`, keeps enhancement mappings, and provides legacy script code derivation.
- `fstek_audit/core/status.sh` renders verdict lines and keeps status counters.
- `fstek_audit/core/os_detector.sh` detects Astra Linux, ALT Linux, RED OS, and generic Linux.
- `fstek_audit/core/common.sh` holds reusable read-only evidence helpers used by measure files.
- `fstek_audit/core/runner.sh` owns per-measure lifecycle helpers.
- `fstek_audit/core/logger.sh` and `fstek_audit/core/csv_engine.sh` are small foundations for later runner/reporting work.
- `fstek_audit/adapters/` contains OS adapter placeholders. Adapter-specific evidence collection has not been migrated yet.
- `fstek_audit/checks/manifest.tsv` is the source of truth for implemented measures. It maps each measure code to its section, measure file, entry function, supported classes, title, and component.
- `fstek_audit/checks/<GROUP>/` directories contain the migrated measure-specific logic. Each measure file defines `run_check`.
- `fstek_audit/config/` contains example profile/scope files.
- `fstek_audit/output/` is reserved for generated reports and kept empty in git.

## Migration rule

Move behavior in small steps. During migration, `./run.sh --class K1/K2/K3` and `./check_all.sh --class K1/K2/K3` must continue to work.
## Measure Files

Measure-specific logic lives in `fstek_audit/checks/<SECTION>/<CODE>.sh`, exposed at the repository root as `checks/<SECTION>/<CODE>.sh`. Single-measure runs use `run.sh --measure <CODE>`.

## Manifest Registry

`checks/manifest.tsv` is also exposed at the repository root through the `checks` compatibility link. The manifest is tab-separated and has these columns:

```text
code	section	file	function	classes	title	component
```

`fstek_audit/run.sh` uses the manifest for `--list`, `--measure`, `--section`, and `--class` selection. Legacy aggregate entrypoints delegate to the same runner so class filtering cannot drift into separate Bash `case` statements again.
