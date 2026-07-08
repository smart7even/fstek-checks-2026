---
name: fstek-methodology
description: Use when working in this repository on FSTEK 2026 Linux compliance checks, check_*.sh scripts, lib_fstek.sh, measure mappings, PASS/FAIL/SKIP semantics, or any request mentioning the FSTEK methodology/document. Always consult the bundled methodology PDF before changing or judging a requirement.
---

# FSTEK Methodology

This repository bundles the source methodology document at:

`docs/fstek-methodology-2026.pdf`

Use it as the primary source of truth for every non-trivial change to checks. Do not rely on memory when deciding whether a measure, enhancement, threshold, or class mapping is required.

## Workflow

1. Locate the relevant measure text in `docs/fstek-methodology-2026.pdf` before editing.
2. Extract searchable text to a temporary file when needed:

```bash
PDF=docs/fstek-methodology-2026.pdf
TXT=/private/tmp/fstek-methodology-2026.txt
if command -v pdftotext >/dev/null 2>&1; then
  pdftotext -layout "$PDF" "$TXT"
else
  /Users/olegmagomedov/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/poppler/bin/pdftotext -layout "$PDF" "$TXT"
fi
```

3. Search by measure code and key terms, for example:

```bash
rg -n "ИАФ\\.3|УПД\\.4|РСБ\\.1|АВЗ\\.1|СОВ\\.1|МСЭ\\.1|ЗОО\\.5|ЗЭП\\.6" "$TXT"
```

4. Double-check class applicability and enhancement numbers in the `Реализация в информационной системе` table for the measure.
5. Make the script behavior match the document:
   - `PASS`: the technical requirement is directly confirmed.
   - `FAIL`: the technical requirement is checkable but not confirmed.
   - `SKIP`: the requirement depends on documentation, organizational procedure, network diagrams, IdP/MDM/SIEM/SZI consoles, source code, contracts, or other external evidence.
6. Preserve the repository style: Bash, read-only checks, no system configuration changes, concise Russian output.

## Local Conventions

- Keep check modules named `check_<code>.sh`; common reusable checks live in `lib_fstek.sh`.
- Prefer strict checks over broad keyword matches. A generic `content_filter`, `milter`, `deny`, or service presence is not enough for `PASS` unless the configuration proves the specific methodology requirement.
- When a requirement cannot be reliably automated, add an explicit `SKIP` line rather than silently omitting it.
- For PDFs, use bundled Poppler first when system `pdftotext` is missing. Avoid rediscovering the PDF location outside the repository.

## Common Methodology Anchors

- `ИАФ.3`: password length 12, alphabet 70, 5 failed attempts, 15 minute lockout, password change within 90 days, password reuse prohibition, MFA/OTP for relevant privileged remote access.
- `УПД.2`: least privilege, separation of privileged and non-privileged access, no shared/default accounts, documentation for roles and main administrator.
- `УПД.3`: account lifecycle, access rule review, account management logging, centralized management enhancements.
- `УПД.4`: failed and non-scheduled access attempts, temporary/unused account handling, privileged unlock procedure.
- `РСБ.1`: minimum event categories include logins, media, program/process start and stop, object access attempts, remote access attempts, and SZI events.
- `АВЗ.1`: installed AV, updates, scheduled scans, near-real-time checks for external-source files, response/documentation.
- `СОВ.1/СОВ.2`: IDS/IPS deployment, traffic source, response, rule/indicator updates; deeper application-level, retrospective, sandbox, and reputation capabilities may be enhancement/manual evidence depending on the class table.
- `МСЭ.1`: segmentation, boundary filtering, logging, documentation and annual validation; microsegmentation only where required by class/enhancement.
- `ЗОО.5/ЗОО.6`: connection/request/DNS rate limits and monitoring; twofold reserve is methodology/operator evidence, not inferable from a Linux host alone.
- `ЗЭП.3/ЗЭП.6`: prove mail AV/attachment controls and metadata hiding by concrete rules, not just presence of a filter hook.
