# Repository Guidance

This project implements read-only Bash checks for the FSTEK Russia methodology dated 2026-04-12.

Primary source of truth:

- `docs/fstek-methodology-2026.pdf`

When changing `check_*.sh`, `check_all.sh`, `lib_fstek.sh`, README coverage notes, or class/enhancement mappings:

- Consult the bundled PDF first.
- Double-check the relevant measure text and its `Реализация в информационной системе` table.
- Do not treat broad indicators as proof. A generic service, milter, content filter, `deny` keyword, or agent process is not enough for `PASS` unless it proves the specific requirement.
- Use `PASS` only for directly confirmed technical requirements.
- Use `FAIL` for technical requirements that are checkable but not confirmed.
- Use `SKIP` for documentation, organizational procedures, network diagrams, IdP/MDM/SIEM/SZI consoles, source code, contracts, or other external evidence.
- Keep checks read-only; never change system configuration.

Repo-local Codex skill:

- `.codex/skills/fstek-methodology/SKILL.md`

Use that skill for recurring FSTEK methodology work in this repository.
