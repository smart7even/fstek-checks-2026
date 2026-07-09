# Statuses

The refactor preserves the existing verdict meanings. A check must not change status only because code moved between files.

- `PASS (HIGH)` means strong direct local evidence was found in configuration, service state, policy, rules, timers, package metadata, or another technical source.
- `PASS (MEDIUM)` means mature heuristic evidence was found. It is useful for automated classification, but not a complete proof.
- `FAIL` means expected local evidence is missing, disabled, unsafe, contradictory, or incorrectly configured.
- `SKIP` means the measure cannot be classified from local Linux evidence with acceptable confidence and needs external evidence such as documentation, IdP/MDM/SIEM consoles, network diagrams, source code, contracts, or physical inspection.
- `INFO` means useful context or weak evidence that must not affect pass/fail classification.

The current codebase also has legacy `NA` handling for absent optional stacks. This structural step keeps that behavior unchanged and does not introduce any new final status category.
