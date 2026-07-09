# fstek_audit Agent Notes

Keep this directory structural until the check migration is explicitly requested.

- Do not change check logic while moving files.
- Keep `../lib_fstek.sh` as the compatibility loader for root-level scripts.
- Keep checks read-only and dependency-free.
- Preserve `./check_all.sh --class K1/K2/K3` and `./run.sh --measure <CODE>` behavior.
