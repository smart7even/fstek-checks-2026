# fstek_audit Agent Notes

- Keep checks read-only and dependency-free.
- Put reusable helper functions in `core/`, not in individual measure files.
- Preserve `./check_all.sh --class K1/K2/K3` and `./check_all.sh --measure <CODE>` behavior.
