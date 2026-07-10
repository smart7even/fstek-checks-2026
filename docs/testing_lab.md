# Lab testing (Mac controller → Yandex Cloud VM)

Fleet **automatically deploys** the checks bundle from the Mac to each target
before scanning (`FSTEK_AUTO_DEPLOY=true` by default). Manual rsync/git clone
on the VM is not required.

## One-time setup on the VM (bob@89.169.191.171)

Only SSH access and sudo for `check_all.sh`:

```bash
ssh bob@89.169.191.171

# passwordless sudo for check_all after auto-deploy to /opt/fstek-checks-2026
echo 'bob ALL=(ALL) NOPASSWD: /opt/fstek-checks-2026/check_all.sh' | sudo tee /etc/sudoers.d/fstek-lab
sudo chmod 440 /etc/sudoers.d/fstek-lab

# SFTP inbox for fleet batch uploads (stage 3; same VM is fine for lab)
mkdir -p /home/bob/fstek-fleet-inbox
```

Bob also needs **passwordless sudo for rsync** (used by auto-deploy), or set
`FSTEK_REMOTE_REPO=$HOME/fstek-checks-2026` in inventory to deploy without
sudo rsync.

## One-time setup on Mac (controller)

1. SSH key must work:

```bash
ssh bob@89.169.191.171 'echo ok'
```

2. Local secrets (gitignored):

```bash
cp .env.local.example .env.local
# edit FSTEK_SSH_KEY if not ~/.ssh/id_ed25519
```

3. Lab inventory: `fstek_audit/config/inventory.lab.conf` (gitignored)

## Run fleet from Mac

```bash
chmod +x fleet_lab.sh
./fleet_lab.sh --class K3 --batch-id lab1
```

Each run:

1. `rsync` repo Mac → VM (`FSTEK_REMOTE_REPO`, default `/opt/fstek-checks-2026`)
2. `sudo -n ./check_all.sh` on VM
3. scp log/json back to Mac
4. build `fleet-measures.csv` + `fleet-measure-rollups.csv`
5. SFTP upload batch to VM inbox (if `FSTEK_SFTP_ENABLED=true`)

Artifacts:

```text
fstek_audit/output/fleet/lab1/
  fleet-summary.csv
  fleet-measures.csv
  fleet-measure-rollups.csv
  yc-lab/lab1/*.log
  yc-lab/lab1/*.json
```

On the VM (SFTP inbox):

```text
/home/bob/fstek-fleet-inbox/lab1/
  fleet-summary.csv
  fleet-measures.csv
  fleet-measure-rollups.csv
  yc-lab/...
```

Skip auto-deploy if bundle is managed elsewhere:

```bash
./fleet_lab.sh --no-deploy --class K3 --batch-id lab1
```

Skip SFTP upload:

```bash
./fleet_lab.sh --no-sftp --class K3 --batch-id lab1
```

## Gitignored local files

| File | Purpose |
|---|---|
| `.env.local` | `FSTEK_SSH_KEY`, optional overrides |
| `fstek_audit/config/inventory.lab.conf` | lab host list (IP, user) |

Committed templates: `.env.local.example`, `inventory.lab.example.conf`.
