# Repository Guidance

This repository contains read-only Bash checks for practical automated technical
classification of FSTEK/FSTEC 2026 information security measures on Linux hosts.
The product should answer the operational question: "Based on local Linux
evidence, does this look configured correctly or not?"

The goal is useful production-grade technical classification, not legal
attestation and not a full FSTEC compliance conclusion.

Primary source of truth:

- `docs/fstek-methodology-2026.pdf`

Repo-local Codex skill:

- `.codex/skills/fstek-methodology/SKILL.md`

Use that skill for recurring FSTEK methodology work in this repository.

## Scope And Platforms

- Keep all checks read-only. Never change system configuration, service state,
  permissions, packages, policy files, firewall rules, audit rules, or kernel
  settings.
- Target OS families are Astra Linux SE 1.7/1.8, ALT Linux, RED OS, and a
  generic Linux fallback.
- Keep Bash as the implementation language.
- Use POSIX-friendly Bash where practical. Bash-specific syntax is acceptable
  because existing scripts use Bash.
- Do not introduce Python, Go, Node.js, or external package dependencies.

## Methodology Rules

When changing measure files under `fstek_audit/checks/`, `check_all.sh`, `fstek_audit/core/`, README coverage
notes, class/enhancement mappings, or anything that interprets a measure:

- Consult the bundled PDF first.
- Double-check the relevant measure text and its `Реализация в информационной
  системе` table.
- Prefer useful local technical classification over excessive caution.
- Do not weaken a useful `PASS` or `FAIL` into `SKIP` merely because an exotic
  external configuration could exist.
- It is acceptable that high-confidence automated checks may be misleading in
  rare corner cases. The verdict is an automated technical verdict, not an
  attestation conclusion.
- Do not treat broad indicators as high-confidence proof. A generic service,
  milter, content filter, `deny` keyword, package, or agent process is not
  enough for `PASS (HIGH)` unless it proves the specific requirement.
- Weak heuristics must produce `INFO` or `SKIP`; do not emit low-confidence
  binary verdicts.
- Avoid hardcoded thresholds unless the FSTEK method explicitly defines them or
  the threshold is configurable through a local profile file.
- If a value should be operator-defined, read it from a local profile file when
  present. Otherwise report `SKIP` or `INFO`, not an arbitrary `FAIL`.

## Verdicts And Confidence

For controls that can reasonably be checked from a local Linux host, scripts
should try to return a clear binary technical verdict:

- `PASS`: local technical evidence indicates the expected control is
  implemented.
- `FAIL`: local technical evidence indicates the expected control is missing,
  disabled, unsafe, or not configured.
- `SKIP`: the control cannot be classified locally with acceptable
  confidence, or depends on documentation, organizational procedures, network
  diagrams, IdP/MDM/SIEM/SZI consoles, source code, contracts, physical
  inspection, radio inspection, or other external evidence.
- `NA`: the component or stack is not present and the measure only applies when
  that component exists.
- `INFO`: useful context that should not affect pass/fail.

Add confidence only to successful automated verdicts:

- `HIGH`: strong direct evidence from configuration, service state, policy,
  rules, timers, package metadata, or another local technical source.
- `MEDIUM`: mature heuristic evidence that covers most real-world cases.

Decision rules:

- If direct local evidence exists, return `PASS (HIGH)` or `FAIL`.
- If a mature heuristic covers most real-world cases, return `PASS (MEDIUM)` or
  `FAIL`.
- If evidence is weak or low-confidence, return `INFO`.
- If the component is absent and the measure only applies when that component
  exists, return `NA`.
- If the measure genuinely cannot be classified from local Linux evidence with
  acceptable confidence, return `SKIP`.
- Do not use `SKIP` just to avoid responsibility when a useful local classifier
  can be built.

Every check must print the exact evidence found or missing, such as file path,
service name, command availability, config key, timer, rule, policy, package, or
profile value. Keep output stable enough for CI parsing.

Preferred output format:

- `[CODE] PASS (HIGH) - evidence...`
- `[CODE] PASS (MEDIUM) - heuristic evidence...`
- `[CODE] FAIL - missing/unsafe...`
- `[CODE] SKIP - cannot be classified locally because...`
- `[CODE] INFO - low-confidence/contextual observation...`
- `[CODE] NA - component/stack not present`

## Implementation Style

- Put reusable helper functions in `fstek_audit/core/`.
- Keep thin wrapper scripts as wrappers that call `init_measure`,
  `check_<measure>`, and `finish_measure`.
- Avoid duplicated `check_pass`, `check_fail`, `check_skip`, or `check_info`
  definitions in individual scripts where possible.
- Use helper functions for common checks: service active, config grep, package
  installed, PAM parsing, auditd rules, systemd timers, firewall rules, TLS
  config, AV agents, SIEM forwarding, FIM, container runtime, and virtualization
  stack.
- Make checks safe when files, directories, commands, services, package
  databases, or init systems do not exist.
- Avoid unquoted variables and unsafe glob behavior.
- Do not remove existing checks unless replacing them with a more accurate
  implementation.

## Command-Line Compatibility

- Keep `check_all.sh --class K1/K2/K3` behavior consistent with `fstek_audit/run.sh`.
- Preserve backwards compatibility with existing flags:
  - `--class`
  - `--security-class`
  - `--with-enhancements`
  - `-e`
  - `--k1`
  - `--k2`
  - `--k3`

## Tests And Smoke Checks

Add or update smoke tests when changing checks or shared helpers. A smoke test
such as `tests/smoke.sh` should:

- Run `bash -n` on every `.sh` file.
- Run every manifest measure via `check_all.sh --measure <CODE> --class K3` in a safe mode, or at least verify it starts and exits without syntax/runtime errors on a generic Linux host.
- Verify that every measure file defines `run_check`.
- Verify that every implemented measure is either included in
  `fstek_measure_classes` or explicitly marked as intentionally excluded.
