# Methodology Location

The bundled methodology PDF lives at:

`docs/fstek-methodology-2026.pdf`

If searchable text is needed, extract it to a temporary file and search that file:

```bash
PDF=docs/fstek-methodology-2026.pdf
TXT=/private/tmp/fstek-methodology-2026.txt
pdftotext -layout "$PDF" "$TXT"
rg -n "ИАФ\\.3|УПД\\.4|РСБ\\.1|АВЗ\\.1|СОВ\\.1|МСЭ\\.1|ЗОО\\.5|ЗЭП\\.6" "$TXT"
```

If `pdftotext` is not on PATH, use the bundled Poppler binary:

`/Users/olegmagomedov/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/poppler/bin/pdftotext`
