# fstek_audit

This directory contains the new audit-engine layout. Root-level scripts remain the compatibility entrypoints during migration.

Use from repository root:

```bash
./check_all.sh --class K3
```

Or through the new wrapper:

```bash
./fstek_audit/run.sh --class K3
```

See `docs/architecture.md` for the migration model and `docs/statuses.md` for verdict semantics.
