# Ubuntu 24.04 LTS CIS Hardening Toolkit

![Status](https://img.shields.io/badge/status-beta-blue)
![License](https://img.shields.io/badge/license-MIT-blue)
![Benchmark](https://img.shields.io/badge/CIS%20Benchmark-Ubuntu%2024.04%20v1.0.0-green)
![Backend](https://img.shields.io/badge/backend-Ubuntu%20Security%20Guide%20(USG)-orange)

A Bash wrapper around **Ubuntu Security Guide (USG)** for hardening and auditing Ubuntu 24.04 LTS Server against the CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0.

⚠️ **Disclaimer:** Hardening makes deep changes to your system configuration. Only use this on fresh installations or in a test environment. Always take a snapshot before running. The author is not responsible for loss of access or functionality.

---

## Requirements

| Requirement | Details |
|---|---|
| OS | Ubuntu Server 24.04 LTS (Noble Numbat), x86_64 |
| Privileges | Root or sudo |
| Ubuntu Pro | Free for up to 5 machines — [ubuntu.com/pro](https://ubuntu.com/pro) |

Get your free token at [ubuntu.com/pro](https://ubuntu.com/pro) before running the script.

---

## Usage

### Apply hardening

```bash
git clone https://github.com/WildcatKSS/Ubuntu-24.04-LTS-CIS-Hardening-Toolkit.git
cd Ubuntu-24.04-LTS-CIS-Hardening-Toolkit
sudo ./harden.sh
```

The script asks every question **up front** so the rest of the run is fully unattended:

1. CIS profile to apply (Level 1 or Level 2 Server)
2. Ubuntu Pro token — only prompted if the machine is not yet attached
3. Whether to automatically reboot when hardening finishes

After you answer these, the script runs end-to-end without further input: it updates Ubuntu, sets up Ubuntu Pro + USG, applies the CIS profile, and reboots (or exits) based on your earlier answer.

### Audit compliance (read-only)

```bash
sudo ./audit.sh
```

The HTML report is saved to `/var/log/cis-audit/` and `/var/lib/usg/usg-report.html`.

---

## Workflow — what each script does

### `harden.sh` (fully unattended after upfront questions)

1. Initialise logging to `/var/log/cis-hardening.log` + syslog (tag `cis-hardening`)
2. Preflight: require root, verify Ubuntu 24.04
3. **Upfront questions**: CIS profile (L1/L2), Ubuntu Pro token (if needed), auto-reboot yes/no
4. **Full Ubuntu update**: `apt-get update` → `apt-get dist-upgrade -y` → `apt-get autoremove -y` (with `DEBIAN_FRONTEND=noninteractive` and `--force-confold` to avoid dpkg prompts)
5. Ubuntu Pro setup: install `ubuntu-advantage-tools` if missing, `pro attach` using the collected token, `pro enable usg`
6. Install the `usg` package if it is not already present
7. Build USG arguments (adds `--tailoring-file` if `tailoring/<profile>.xml` exists)
8. Run `usg fix <profile>` to apply the benchmark
9. Reboot automatically (if you chose yes) or log a reminder to run `sudo reboot`

### `audit.sh` (read-only)

1. Initialise logging
2. Preflight + ensure USG is available
3. Ask which profile to audit
4. Run `usg audit <profile>` (never modifies the system; exit code 1 on non-compliance is expected)
5. Copy the HTML report to `/var/log/cis-audit/report-<timestamp>.html`

### `change-cis-profile.sh`

1. Initialise logging
2. Preflight + ensure USG is available
3. Ask which profile to customise; confirm overwrite if a tailoring file already exists
4. Launch the USG browser wizard (`usg generate-tailoring`) — save selections there
5. Tailoring file is stored in `tailoring/<profile>.xml` and picked up automatically by `harden.sh` / `audit.sh`

---

## Logging

All scripts log via a shared 8-level logger modelled on syslog severity:

| Level | Name    | Colour                |
|-------|---------|-----------------------|
| 0     | emerg   | white on red          |
| 1     | alert   | bold red              |
| 2     | crit    | magenta               |
| 3     | err     | red                   |
| 4     | warning | yellow                |
| 5     | notice  | cyan                  |
| 6     | info    | blue                  |
| 7     | debug   | grey                  |

Every message is written to three places:

- Terminal, with colour per level (warnings and above go to stderr)
- `/var/log/cis-hardening.log`, without ANSI codes — `grep`-friendly with `[YYYY-MM-DD HH:MM:SS] [LEVEL  ]` prefix
- Syslog via `logger -t cis-hardening -p user.<level>` — view with `journalctl -t cis-hardening`

Environment variables:

| Variable          | Default | Meaning                                              |
|-------------------|---------|------------------------------------------------------|
| `LOG_LEVEL`       | `7`     | Suppress levels above this number (e.g. `4` = warning+) |
| `SYSLOG_ENABLED`  | `1`     | Set to `0` to disable syslog forwarding              |

---

## Customise profiles (tailoring)

By default profiles are applied without modification. For environment-specific adjustments, use tailoring files.

### Via the toolkit (recommended)

```bash
sudo ./change-cis-profile.sh
```

Select the profile (L1 or L2). USG opens a browser wizard where you can enable or disable individual CIS controls. After saving, the tailoring file is stored in `tailoring/` and loaded automatically by `harden.sh` and `audit.sh`.

### Edit manually

Edit `tailoring/level1-server.xml` or `tailoring/level2-server.xml` directly.
Add `<xccdf-1.2:select>` elements inside the `Profile` block:

```xml
<!-- Disable a control -->
<xccdf-1.2:select idref="xccdf_org.ssgproject.content_rule_sshd_set_loglevel_verbose" selected="false"/>
```

Tailoring files are loaded automatically when present — no extra configuration needed.

---

## Project structure

```
.
├── harden.sh                  # Full Ubuntu update + CIS hardening via USG fix (unattended)
├── audit.sh                   # Compliance audit via USG audit (read-only)
├── change-cis-profile.sh      # Customise a profile via the USG tailoring wizard
├── lib/
│   └── common.sh              # Shared helpers: 8-level logger (file + syslog),
│                              #   init_logging, collect_answers (upfront questions),
│                              #   system_update, preflight, USG/Pro setup
└── tailoring/
    ├── level1-server.xml      # Optional customisations for the L1 profile
    └── level2-server.xml      # Optional customisations for the L2 profile
```

---

## Scope

| Item | Value |
|---|---|
| Target OS | Ubuntu Server 24.04 LTS |
| Architecture | x86_64 |
| Benchmark | CIS Ubuntu Linux 24.04 LTS v1.0.0 |
| Profiles | Level 1 Server, Level 2 Server |
| Out of scope | Workstation profiles, container images |

---

## How USG applies controls

USG reads the SCAP benchmark files in `/usr/share/ubuntu-scap-security-guides/current/benchmarks/` and applies controls via the underlying OpenSCAP framework. `usg fix` modifies system settings; `usg audit` only reports.

Useful commands:

```bash
# List rules available in a profile
usg audit cis_level1_server 2>&1 | grep "Rule"

# Browse benchmark files
ls /usr/share/ubuntu-scap-security-guides/current/benchmarks/
```

---

## Credits & References

- [Ubuntu Security Guide (USG)](https://ubuntu.com/security/certifications/docs/usg) — Canonical
- [CIS Ubuntu Linux 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux) — Center for Internet Security

---

## License

MIT — see `LICENSE`. CIS Benchmarks are the property of the Center for Internet Security; this repository contains no benchmark text.
