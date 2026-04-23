# Ubuntu 24.04 LTS CIS Hardening Toolkit

![Status](https://img.shields.io/badge/status-pre--alpha-orange)
![Licentie](https://img.shields.io/badge/licentie-MIT-blue)
![Benchmark](https://img.shields.io/badge/CIS%20Benchmark-Ubuntu%2024.04%20v1.0.0-green)

Een geplande toolkit van Bash-scripts voor het hardenen van een schone Ubuntu 24.04 LTS Server installatie op basis van de **CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0**. Het hoofdscript zal tijdens het uitvoeren vragen welk CIS-profiel (Level 1 of Level 2 Server) je wilt toepassen.

> ⚠️ **Disclaimer:** Deze toolkit zal diepgaand systeemconfiguratie wijzigen. Gebruik uitsluitend op verse installaties of in een testomgeving voordat je hem op productie loslaat. Maak altijd een snapshot/backup. De auteur is niet verantwoordelijk voor verlies van toegang of functionaliteit.
>
> **Let op:** Er bestaat momenteel nog geen uitvoerbare code. Dit document beschrijft de beoogde werking en dient als architectuurspecificatie.

-----

## 📊 Project Status

> Dit project bevindt zich in de conceptfase. Er bestaat momenteel geen uitvoerbare code. Dit README-bestand dient als architectuurontwerp en startpunt voor de implementatie.

| Fase | Status |
|---|---|
| Architectuurontwerp | Gereed |
| Eerste implementatie (v0.1) | Niet gestart |
| Beoogde eerste release | Onbekend |

Bijdragen aan de architectuur en planning zijn in deze fase het meest waardevol. Zie de sectie [Bijdragen](#-bijdragen) voor meer informatie.

-----

## 📋 Projectdoel

Een schone installatie van Ubuntu Server 24.04 LTS in lijn brengen met de aanbevelingen van de CIS Benchmark, zonder afhankelijk te zijn van commerciële tooling (zoals Ubuntu Pro / USG). De toolkit wordt modulair, idempotent en leesbaar, zodat iedere wijziging traceerbaar en omkeerbaar is.

### Waarom bash en niet Ansible?

- Nul externe afhankelijkheden buiten een standaard Ubuntu installatie
- Direct op een verse host uitvoerbaar door het script lokaal te klonen en te inspecteren vóór uitvoering
- Laagdrempelig voor beginnende sysadmins om de CIS-controls te leren begrijpen
- Geen control node of SSH-infrastructuur nodig

-----

## 🎯 Scope

|Item         |Waarde                                                    |
|-------------|----------------------------------------------------------|
|Doel-OS      |Ubuntu Server 24.04 LTS (Noble Numbat)                    |
|Architectuur |x86_64                                                    |
|Benchmark    |CIS Ubuntu Linux 24.04 LTS v1.0.0                         |
|Profielen    |Level 1 Server en Level 2 Server (runtime keuze)          |
|Niet in scope|Workstation-profielen, desktop-varianten, container-images|

-----

## ✨ Geplande features

| Feature | Status |
|---|---|
| Interactieve profielkeuze (L1 Server / L2 Server) bij het starten | Gepland |
| Modulaire opbouw per CIS-sectie (1 t/m 7) | Gepland |
| Pre-flight check: OS-versie, root-rechten, netwerktoegang, schijfruimte | Gepland |
| Automatische back-up van gewijzigde configs naar `/var/backups/cis-hardening/<timestamp>/` | Gepland |
| Dry-run modus (`--dry-run`) die alleen rapporteert wat er gewijzigd zou worden | Gepland |
| Logging van elke actie naar `/var/log/cis-hardening.log` | Gepland |
| Rollback-script dat de laatste back-up terugzet | Gepland |
| Audit-only modus die compliance rapporteert zonder te wijzigen | Gepland |
| Kleurgecodeerde output (PASS / FAIL / SKIP / CHANGED) | Gepland |

-----

## 📁 Geplande repo-structuur

> De onderstaande structuur beschrijft de beoogde mappenindeling. Op dit moment bevat de repository alleen dit README-bestand.

```
.
├── README.md
├── LICENSE
├── harden.sh                  # Hoofd-entrypoint (interactief menu)
├── rollback.sh                # Zet laatste back-up terug
├── lib/
│   ├── common.sh              # Helpers: logging, back-up, checks
│   ├── preflight.sh           # OS/versie/rechten verificatie
│   └── colors.sh              # Output-opmaak
├── modules/
│   ├── 01-initial-setup/      # Filesystems, updates, bootloader, AppArmor
│   ├── 02-services/           # Onnodige services uitschakelen
│   ├── 03-network/            # Kernel params, firewall (ufw/nftables)
│   ├── 04-logging-auditing/   # auditd, rsyslog, journald
│   ├── 05-access/             # SSH, PAM, sudo, password policies
│   ├── 06-system-maintenance/ # Bestandsrechten, user/group integriteit
│   └── 07-misc/               # Overige controls
├── config/
│   ├── profile-l1-server.conf # Welke controls draaien voor L1
│   └── profile-l2-server.conf # Welke controls draaien voor L2
├── docs/
│   ├── CONTROLS.md            # Overzicht geïmplementeerde controls + CIS-ID
│   ├── EXCEPTIONS.md          # Bewust overgeslagen items met motivatie
│   └── TESTING.md             # Testaanpak en test-VM setup
└── tests/
    └── vagrant/               # Vagrantfile voor test-VM
```

-----

## 🚀 Beoogd gebruik

> De scripts bestaan nog niet. De onderstaande instructies beschrijven de beoogde interface zodra v0.1 beschikbaar is.

### Vereisten

- Verse installatie van Ubuntu Server 24.04 LTS
- Root-rechten of een sudo-user
- Ten minste 500 MB vrije schijfruimte in `/var`

### Installeren en uitvoeren

```bash
git clone https://github.com/WildcatKSS/Ubuntu-24.04-LTS-CIS-Hardening-Toolkit.git
cd Ubuntu-24.04-LTS-CIS-Hardening-Toolkit
sudo ./harden.sh
```

> **Veiligheid:** Inspecteer het script altijd vóór uitvoering. Voer nooit ongecontroleerde scripts als root uit.

Je krijgt een menu:

```
Selecteer CIS profiel:
  1) Level 1 Server  (aanbevolen baseline)
  2) Level 2 Server  (strenger, mogelijk impact op functionaliteit)
  3) Audit only      (geen wijzigingen)
  q) Afsluiten
```

### Dry-run

De `--dry-run` vlag werkt op elke modus en rapporteert alleen wat er gewijzigd zou worden:

```bash
sudo ./harden.sh --dry-run
```

### Rollback

```bash
sudo ./rollback.sh
```

-----

## 🗺️ Roadmap

> We bevinden ons momenteel vóór v0.1 — er bestaat nog geen projectstructuur of uitvoerbare code.

- [ ] v0.1 – Projectstructuur, preflight-checks, logging-framework ← *huidige fase*
- [ ] v0.2 – Sectie 1 (Initial Setup)
- [ ] v0.3 – Sectie 2 (Services) + Sectie 3 (Network)
- [ ] v0.4 – Sectie 4 (Logging & Auditing)
- [ ] v0.5 – Sectie 5 (Access, Authentication, Authorization)
- [ ] v0.6 – Sectie 6 + 7 (System Maintenance, Misc)
- [ ] v0.7 – Audit-only modus + rapportage (JSON/HTML)
- [ ] v0.8 – Rollback-mechanisme
- [ ] v1.0 – Volledige dekking L1 & L2 Server, geautomatiseerde tests in CI
- [ ] v1.1 – Ondersteuning voor Ubuntu 26.04 LTS zodra CIS-benchmark is gepubliceerd

-----

## 🧪 Testen

Elke release wordt getest tegen een verse Ubuntu 24.04 LTS VM (Vagrant/VirtualBox), gevolgd door een externe audit met een onafhankelijk tool zoals **Lynis** of het open-source **ansible-lockdown UBUNTU24-CIS-Audit** project, om de compliance-score te valideren.

`docs/TESTING.md` wordt aangemaakt zodra de eerste implementatie beschikbaar is.

-----

## 🙏 Credits & Referenties

- [CIS Ubuntu Linux 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux) – Center for Internet Security
- [Ubuntu Security Guide (USG)](https://ubuntu.com/security/certifications/docs/usg) – Canonical
- [ansible-lockdown/UBUNTU24-CIS](https://github.com/ansible-lockdown/UBUNTU24-CIS) – inspiratie voor modulaire opzet

-----

## 📜 Licentie

MIT License — het `LICENSE`-bestand wordt toegevoegd bij de eerste commit met uitvoerbare code. CIS Benchmarks zijn eigendom van het Center for Internet Security; deze repo bevat geen CIS-benchmarkteksten, alleen implementaties van publiekelijk beschreven controls.

-----

## 🤝 Bijdragen

Pull requests zijn welkom. Open eerst een issue voor grotere wijzigingen.

**In de huidige conceptfase** zijn bijdragen aan de architectuur en planning het meest waardevol:
- Feedback op de geplande structuur of module-indeling
- Ontbrekende CIS-controls aanwijzen
- Use cases of edge cases beschrijven

**Zodra er code is:** Zorg dat nieuwe controls de CIS-ID vermelden en een unit-test bevatten.
