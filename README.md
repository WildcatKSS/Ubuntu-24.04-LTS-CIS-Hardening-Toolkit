# Ubuntu 24.04 LTS CIS Hardening Toolkit

![Status](https://img.shields.io/badge/status-beta-blue)
![License](https://img.shields.io/badge/license-MIT-blue)
![Benchmark](https://img.shields.io/badge/CIS%20Benchmark-Ubuntu%2024.04%20v1.0.0-green)
![Backend](https://img.shields.io/badge/backend-Ubuntu%20Security%20Guide%20(USG)-orange)

A thin Bash wrapper around **Ubuntu Security Guide (USG)** for hardening and auditing Ubuntu 24.04 LTS Server against the CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0.

> ⚠️ **Disclaimer:** Hardening makes deep changes to your system configuration. Only use this on fresh installations or in a test environment. Always take a snapshot before running. The author is not responsible for loss of access or functionality.

---

## Requirements

| Requirement | Details |
|---|---|
| OS | Ubuntu Server 24.04 LTS (Noble Numbat), x86_64 |
| Privileges | Root or sudo |
| Ubuntu Pro | Free for up to 5 machines — [ubuntu.com/pro](https://ubuntu.com/pro) |
| USG | Installed automatically when Ubuntu Pro is active |

### Ubuntu Pro (one-time setup)

The script handles Ubuntu Pro setup automatically. During the first run it will:
1. Install `ubuntu-advantage-tools` if missing
2. Prompt you for your Ubuntu Pro token and run `pro attach`
3. Enable the USG service via `pro enable usg`
4. Install the `usg` package

Get your free token at [ubuntu.com/pro](https://ubuntu.com/pro) before running the script.

---

## Usage

### Apply hardening

```bash
git clone https://github.com/WildcatKSS/Ubuntu-24.04-LTS-CIS-Hardening-Toolkit.git
cd Ubuntu-24.04-LTS-CIS-Hardening-Toolkit
sudo ./harden.sh
```

The script will ask which CIS profile to apply:

```
Select CIS profile:
  1) Level 1 Server  — recommended baseline
  2) Level 2 Server  — stricter, may impact functionality
  q) Quit
```

After hardening completes, the script prompts whether to reboot immediately. A reboot is required to apply all changes.

`harden.sh` automatically backs up system configuration to `/var/backups/cis-hardening/` before applying any changes.

### Roll back

```bash
sudo ./rollback.sh
```

Restores the most recent pre-hardening backup and asks for confirmation before making any changes.

### Audit compliance (read-only)

```bash
sudo ./audit.sh
```

The HTML report is saved to `/var/log/cis-audit/` and `/var/lib/usg/usg-report.html`.

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
├── harden.sh                  # Apply hardening via USG fix (backs up before running)
├── audit.sh                   # Compliance audit via USG audit
├── rollback.sh                # Restore the most recent pre-hardening backup
├── change-cis-profile.sh      # Customise a profile via the USG tailoring wizard
├── lib/
│   └── common.sh              # Shared functions (logging, preflight, USG setup, backup)
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
