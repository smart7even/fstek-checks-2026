# Fleet Inventory

Inventory is a Bash snippet sourced by `fleet_check.sh`. See
`fstek_audit/config/inventory.example.conf`.

## Host Line Format

```text
hostname|ip|user|port|remote_repo|ssh_key|password_env
```

| Field | Required | Default | Notes |
|---|---|---|---|
| hostname | yes | — | Logical name for reports |
| ip | yes | — | Used for ping and SSH |
| user | no | `FSTEK_SSH_USER` | SSH login |
| port | no | `FSTEK_SSH_PORT` | SSH port |
| remote_repo | no | `FSTEK_REMOTE_REPO` | Path to repo on the VM |
| ssh_key | no | global key | Private key path; `-` disables key for this host |
| password_env | no | global env | Name of env var holding the password |

## SSH Authentication

**Decision:** support both key and password, with **documented priority**, not silent
cross-method guessing on misconfiguration.

`FSTEK_SSH_AUTH` controls policy:

| Value | Behavior |
|---|---|
| `auto` (default) | Per host: readable `ssh_key` → key auth; else non-empty `password_env` → password auth |
| `key` | Key only |
| `password` | Password env only |

Priority in `auto` mode matches the stakeholder flow (“check key first, otherwise
login/password”):

1. Host `ssh_key` if set, not `-`, and readable
2. Else host `password_env` if the variable is exported and non-empty
3. Else global `FSTEK_SSH_KEY` if readable
4. Else global `FSTEK_SSH_PASSWORD_ENV` (default `FSTEK_SSH_PASSWORD`) if set
5. Else fail with `no SSH credentials configured` (visible in CSV and host log)

Passwords are **never** stored in inventory files. Export them before the run:

```bash
export FSTEK_SSH_PASSWORD='...'
export FSTEK_PASS_VM3='...'
./fleet_check.sh --inventory my-inventory.conf --class K3
```

Password auth uses OpenSSH `SSH_ASKPASS` (no extra packages).

## Remote Execution

- Before each scan, the controller **rsyncs** the local repo to
  `FSTEK_REMOTE_REPO` (`FSTEK_AUTO_DEPLOY=true` by default)
- Runs `sudo -n ./check_all.sh` on the VM (`FSTEK_REMOTE_SUDO=true`)
- `sudo -n` is non-interactive: the SSH user needs **passwordless sudo** for
  `check_all.sh`, or connect as `root` (sudo is then redundant but harmless)
- Set `FSTEK_REMOTE_SUDO=false` only if the SSH user already has sufficient
  privileges without elevation
- One security class (`FSTEK_FLEET_CLASS`) applies to the whole fleet

## Parallelism

`FSTEK_FLEET_PARALLEL=0` (default) launches **all hosts at once**.

For ~20 VMs this is normally fine on a typical Linux controller. Practical limits
start to appear around **50–100+ concurrent SSH sessions**, depending on:

| Limit | Typical default | Symptom |
|---|---|---|
| `ulimit -n` (open files) | 1024+ | `Too many open files` |
| Controller RAM/CPU | varies | Slow orchestration (rare below 50 hosts) |
| SSH daemon on targets | per-host | Unrelated — each VM serves one session |
| Network | varies | Slow scp collection |

Use `--parallel N` or `FSTEK_FLEET_PARALLEL=N` to cap concurrency if needed.

## Retention

Local batch directories under `fstek_audit/output/fleet/` are **not deleted**
automatically. Cleanup can be added later as a separate task.

## Output Layout

```text
fstek_audit/output/fleet/<batch-id>/
  fleet-summary.csv
  fleet-measures.csv
  fleet-measure-rollups.csv
  vm1.example.com/
    fleet-host.log
    <remote-host>-<timestamp>.log
    <remote-host>-<timestamp>.json
```

## Aggregated CSV (stage 4)

After all hosts finish, the controller builds two fleet-wide CSV files from per-host
scan logs:

| File | Contents |
|---|---|
| `fleet-measures.csv` | One row per host × measure parameter: status, confidence, evidence |
| `fleet-measure-rollups.csv` | Count of hosts per measure parameter and status |

Aggregation runs automatically at the end of every fleet batch. No extra flags.

## SFTP upload (stage 3)

Optional upload of the whole batch directory to a central inbox (tar.gz over SFTP,
extracted on the server).

Inventory / env variables:

| Variable | Default | Notes |
|---|---|---|
| `FSTEK_SFTP_ENABLED` | `false` | Set `true` to upload after aggregation |
| `FSTEK_SFTP_HOST` | — | SFTP server (can differ from scan targets) |
| `FSTEK_SFTP_USER` | `FSTEK_SSH_USER` | Login |
| `FSTEK_SFTP_PORT` | `FSTEK_SSH_PORT` | Port |
| `FSTEK_SFTP_REMOTE_DIR` | — | Base inbox path, e.g. `/home/bob/fstek-fleet-inbox` |
| `FSTEK_SFTP_KEY` | `FSTEK_SSH_KEY` | Key path |
| `FSTEK_SFTP_PASSWORD_ENV` | `FSTEK_SSH_PASSWORD_ENV` | Password env name |
| `FSTEK_SFTP_AUTH` | `FSTEK_SSH_AUTH` | `auto`, `key`, or `password` |
| `FSTEK_KEEP_LOCAL` | `true` | Keep local batch dir after SFTP upload |

Remote layout after upload:

```text
<remote_dir>/<batch-id>/
  fleet-summary.csv
  fleet-measures.csv
  fleet-measure-rollups.csv
  <host-token>/...
```

Disable upload for a run: `./fleet_check.sh --no-sftp ...`

See `fstek_audit/config/sftp.example.conf` for a standalone snippet.

